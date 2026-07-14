// src/controllers/payments.controller.js
//
// Phase 1: credit_packages CRUD (admin) + read-only payment history
// (student's own + admin's full list). No checkout/webhook logic yet —
// that's Phase 2, once a provider is confirmed. amount fields are stored
// in cents (integer) to avoid floating-point currency bugs.

const pool = require("../db/pool");

// ── Notifications (bell icon feed) ──────────────────────────────────────────
// Same fire-and-forget convention as announcements.controller.js's
// notifyEligibleUsers(): never awaited from inside the caller's main
// try/catch, so a notification failure can never fail the actual payment
// action. Uses payment_id (added alongside announcement_id on the shared
// notifications table) so a tap can deep-link back to the payment.

async function notifyUser(userId, type, title, body, paymentId) {
  try {
    await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, payment_id)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, type, title, body, paymentId],
    );
  } catch (err) {
    console.error("notifyUser failed:", err);
  }
}

async function notifyAdmins(type, title, body, paymentId) {
  try {
    const { rows: admins } = await pool.query(
      `SELECT id FROM users WHERE role = 'admin'`,
    );
    if (!admins.length) return;

    const params = [];
    const values = admins.map((a, i) => {
      params.push(a.id, type, title, body, paymentId);
      const base = i * 5;
      return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`;
    });

    await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, payment_id)
       VALUES ${values.join(", ")}`,
      params,
    );
  } catch (err) {
    console.error("notifyAdmins failed:", err);
  }
}

// ── Credit Packages: public read (any authenticated role) ─────────────────
// GET /credit-packages — only active tiers, for the student "Buy Credits" screen.
exports.listPackages = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, credits_amount, price_cents, currency, display_order
       FROM credit_packages
       WHERE is_active = true
       ORDER BY display_order, price_cents`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch credit packages." });
  }
};

// ── Credit Packages: admin CRUD ─────────────────────────────────────────────
exports.listPackagesAdmin = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM credit_packages ORDER BY display_order, price_cents`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch credit packages." });
  }
};

exports.createPackage = async (req, res) => {
  const { name, creditsAmount, priceCents, currency, displayOrder } = req.body;

  if (!name?.trim() || !Number.isInteger(creditsAmount) || creditsAmount <= 0) {
    return res.status(400).json({
      error: "name and a positive integer creditsAmount are required.",
    });
  }
  if (!Number.isInteger(priceCents) || priceCents <= 0) {
    return res
      .status(400)
      .json({ error: "priceCents must be a positive integer." });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO credit_packages (name, credits_amount, price_cents, currency, display_order)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        name.trim(),
        creditsAmount,
        priceCents,
        currency?.trim() || "PHP",
        Number.isInteger(displayOrder) ? displayOrder : 0,
      ],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create credit package." });
  }
};

exports.updatePackage = async (req, res) => {
  const { id } = req.params;
  const { name, creditsAmount, priceCents, currency, displayOrder, isActive } =
    req.body;

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM credit_packages WHERE id = $1`,
      [id],
    );
    if (!existingRows.length) {
      return res.status(404).json({ error: "Credit package not found." });
    }
    const existing = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE credit_packages
       SET name = $1, credits_amount = $2, price_cents = $3,
           currency = $4, display_order = $5, is_active = $6
       WHERE id = $7
       RETURNING *`,
      [
        name?.trim() ?? existing.name,
        Number.isInteger(creditsAmount)
          ? creditsAmount
          : existing.credits_amount,
        Number.isInteger(priceCents) ? priceCents : existing.price_cents,
        currency?.trim() ?? existing.currency,
        Number.isInteger(displayOrder) ? displayOrder : existing.display_order,
        isActive !== undefined
          ? isActive === true || isActive === "true"
          : existing.is_active,
        id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update credit package." });
  }
};

exports.deletePackage = async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await pool.query(
      `DELETE FROM credit_packages WHERE id = $1 RETURNING id`,
      [id],
    );
    if (!rows.length) {
      return res.status(404).json({ error: "Credit package not found." });
    }
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    // Likely FK violation if payments reference this package — surface clearly
    // rather than a raw 500 with a Postgres error string.
    res.status(409).json({
      error:
        "Cannot delete a package that has existing payments. Deactivate it instead.",
    });
  }
};

// ── Payments: student requests a top-up ─────────────────────────────────────
// POST /credits/payments — creates a `pending` payment row. No payment
// gateway yet (provider keys are a blocking dependency — see feature spec),
// so this is the manual-confirmation flow: student picks a package + method,
// an admin later confirms/rejects from the Payments tab. Package price and
// credits are looked up server-side from creditPackageId — never trusted
// from the client.
const VALID_PAYMENT_METHODS = ["gcash", "maya", "card", "alipay", "wechat"];

exports.requestPayment = async (req, res) => {
  const userId = req.user.sub;
  const { creditPackageId, paymentMethod } = req.body;

  if (!creditPackageId || !VALID_PAYMENT_METHODS.includes(paymentMethod)) {
    return res.status(400).json({
      error: `creditPackageId and a paymentMethod in ${VALID_PAYMENT_METHODS.join(", ")} are required.`,
    });
  }

  try {
    const { rows: pkgRows } = await pool.query(
      `SELECT id, price_cents, currency FROM credit_packages
       WHERE id = $1 AND is_active = true`,
      [creditPackageId],
    );
    if (!pkgRows.length) {
      return res
        .status(404)
        .json({ error: "Credit package not found or no longer available." });
    }
    const pkg = pkgRows[0];

    const { rows } = await pool.query(
      `INSERT INTO payments
         (user_id, credit_package_id, amount_cents, currency, payment_method, status)
       VALUES ($1, $2, $3, $4, $5, 'pending')
       RETURNING id, amount_cents, currency, payment_method, status, created_at, paid_at`,
      [userId, pkg.id, pkg.price_cents, pkg.currency, paymentMethod],
    );

    const { rows: pkgInfo } = await pool.query(
      `SELECT name AS package_name, credits_amount FROM credit_packages WHERE id = $1`,
      [pkg.id],
    );

    const { rows: studentRows } = await pool.query(
      `SELECT (first_name || ' ' || last_name) AS name FROM users WHERE id = $1`,
      [userId],
    );
    const studentName = studentRows[0]?.name || "A student";
    notifyAdmins(
      "payment_submitted",
      "💳 New Credit Top-Up Request",
      `${studentName} requested ${pkgInfo[0].package_name} (${pkgInfo[0].credits_amount} credits) via ${paymentMethod}.`,
      rows[0].id,
    );

    res.status(201).json({ ...rows[0], ...pkgInfo[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to submit payment request." });
  }
};

// ── Payments: admin confirms/rejects/refunds ─────────────────────────────────
// PATCH /admin/payments/:id/status — body: { status: 'succeeded'|'failed'|'refunded' }.
// On 'succeeded': credits student_profiles.credits (the authoritative balance
// bookings.controller.js reads/writes) and logs a credits_ledger row, same
// dual-write convention as bookings.controller.js's create()/cancel().
// On 'refunded': reverses the credit if the student still has enough balance;
// otherwise leaves credits alone and flags the case for manual review rather
// than driving the balance negative (spec: no auto-claw-back).
// Idempotent: re-applying the same target status is a no-op, and only the
// documented transitions (pending→succeeded/failed, succeeded→refunded) are
// allowed — guards against double-confirming from duplicate admin clicks.
//
// ⚠️ FIXED (this pass): the credit/debit UPDATEs below used to target
// student_profiles directly with a plain `UPDATE ... WHERE user_id = $2`.
// Any student account created before student_profiles rows were reliably
// backfilled at registration (see auth.controller.js's register() fix)
// has NO row there — so that UPDATE silently matched zero rows. Postgres
// doesn't error on a no-op UPDATE, so the transaction still committed, the
// "confirmed"/notification still fired, but no credits were ever actually
// written anywhere. Switched both the credit (succeeded) and debit
// (refunded) paths to an upsert (INSERT ... ON CONFLICT (user_id) DO
// UPDATE) so a missing row can never silently swallow a credit change
// again, regardless of whether this particular gap or some future one
// causes a student to be missing a profile row.
const VALID_STATUSES = ["succeeded", "failed", "refunded"];

exports.updatePaymentStatus = async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!VALID_STATUSES.includes(status)) {
    return res.status(400).json({
      error: `status must be one of ${VALID_STATUSES.join(", ")}.`,
    });
  }

  // Uses a single checked-out client for the whole transaction — pool.query()
  // hands out a different connection per call, so BEGIN/COMMIT and the
  // FOR UPDATE lock below would not actually apply across statements.
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const { rows: payRows } = await client.query(
      `SELECT * FROM payments WHERE id = $1 FOR UPDATE`,
      [id],
    );
    if (!payRows.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ error: "Payment not found." });
    }
    const payment = payRows[0];

    if (payment.status === status) {
      await client.query("COMMIT");
      return res.json(payment);
    }

    if (status === "succeeded" || status === "failed") {
      if (payment.status !== "pending") {
        await client.query("ROLLBACK");
        return res.status(409).json({
          error: `Cannot mark a '${payment.status}' payment as '${status}'.`,
        });
      }
    } else if (status === "refunded") {
      if (payment.status !== "succeeded") {
        await client.query("ROLLBACK");
        return res
          .status(409)
          .json({ error: "Only a succeeded payment can be refunded." });
      }
    }

    let creditsAmount = 0;
    let packageName = "your credit top-up";
    if (payment.credit_package_id) {
      const { rows: pkgRows } = await client.query(
        `SELECT name, credits_amount FROM credit_packages WHERE id = $1`,
        [payment.credit_package_id],
      );
      creditsAmount = pkgRows[0]?.credits_amount ?? 0;
      packageName = pkgRows[0]?.name ?? packageName;
    }

    let flaggedForReview = false;

    if (status === "succeeded" && creditsAmount > 0) {
      // Upsert instead of a plain UPDATE — see fix note above. If this
      // student somehow has no student_profiles row yet, this creates one
      // with the credited amount instead of silently doing nothing.
      await client.query(
        `INSERT INTO student_profiles (user_id, credits)
         VALUES ($1, $2)
         ON CONFLICT (user_id)
         DO UPDATE SET credits = student_profiles.credits + EXCLUDED.credits`,
        [payment.user_id, creditsAmount],
      );
      await client.query(
        `INSERT INTO credits_ledger (user_id, amount, reason, currency)
         VALUES ($1, $2, $3, 'credits')`,
        [payment.user_id, creditsAmount, "Top-up"],
      );
    } else if (status === "refunded" && creditsAmount > 0) {
      // FOR UPDATE lock still applies to the row if it exists; if it
      // doesn't, balance is treated as 0 and we fall into the
      // flaggedForReview path below rather than trying to subtract from
      // a nonexistent row.
      const { rows: spRows } = await client.query(
        `SELECT credits FROM student_profiles WHERE user_id = $1 FOR UPDATE`,
        [payment.user_id],
      );
      const balance = spRows[0]?.credits ?? 0;
      if (balance >= creditsAmount) {
        await client.query(
          `UPDATE student_profiles SET credits = credits - $1 WHERE user_id = $2`,
          [creditsAmount, payment.user_id],
        );
        await client.query(
          `INSERT INTO credits_ledger (user_id, amount, reason, currency)
           VALUES ($1, $2, $3, 'credits')`,
          [payment.user_id, -creditsAmount, "Refund"],
        );
      } else {
        flaggedForReview = true;
      }
    }

    const paidAtClause = status === "succeeded" ? ", paid_at = now()" : "";
    const { rows } = await client.query(
      `UPDATE payments SET status = $1${paidAtClause} WHERE id = $2 RETURNING *`,
      [status, id],
    );

    await client.query("COMMIT");

    if (status === "succeeded") {
      notifyUser(
        payment.user_id,
        "payment_succeeded",
        "✅ Payment Confirmed",
        `Your payment for ${packageName} was confirmed — ${creditsAmount} credits added to your account.`,
        id,
      );
    } else if (status === "failed") {
      notifyUser(
        payment.user_id,
        "payment_failed",
        "❌ Payment Could Not Be Confirmed",
        `Your ${packageName} payment could not be verified. No credits were added — you can submit a new request.`,
        id,
      );
    } else if (status === "refunded") {
      notifyUser(
        payment.user_id,
        "payment_refunded",
        "💸 Payment Refunded",
        `Your ${packageName} payment has been refunded.`,
        id,
      );
    }

    res.json({ ...rows[0], flaggedForReview });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to update payment status." });
  } finally {
    client.release();
  }
};

// ── Payments: read-only ─────────────────────────────────────────────────────
// GET /credits/payments/mine — student's own top-up history.
exports.listMyPayments = async (req, res) => {
  const userId = req.user.sub;
  try {
    const { rows } = await pool.query(
      `SELECT p.id, p.amount_cents, p.currency, p.payment_method, p.status,
              p.created_at, p.paid_at, p.refund_requested_at, p.cancel_reason,
              cp.name AS package_name, cp.credits_amount
       FROM payments p
       LEFT JOIN credit_packages cp ON cp.id = p.credit_package_id
       WHERE p.user_id = $1
       ORDER BY p.created_at DESC`,
      [userId],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch payment history." });
  }
};

// ── Payments: student requests a refund ─────────────────────────────────────
// POST /credits/payments/:id/refund-request — student flags their own
// succeeded payment as wanting a refund. Does NOT itself refund anything —
// the actual succeeded->refunded transition (and credit clawback) stays
// admin-initiated via updatePaymentStatus above, matching the spec's
// "admin-initiated refund" requirement. This just timestamps the request so
// the admin Payments tab can surface it, and is idempotent (re-requesting
// doesn't reset the original timestamp).
exports.requestRefund = async (req, res) => {
  const { id } = req.params;
  const userId = req.user.sub;

  try {
    const { rows } = await pool.query(
      `SELECT id, status, refund_requested_at FROM payments
       WHERE id = $1 AND user_id = $2`,
      [id, userId],
    );
    if (!rows.length) {
      return res.status(404).json({ error: "Payment not found." });
    }
    const payment = rows[0];
    if (payment.status !== "succeeded") {
      return res.status(409).json({
        error: "Only a succeeded payment can have a refund requested.",
      });
    }

    const { rows: updated } = await pool.query(
      `UPDATE payments
       SET refund_requested_at = COALESCE(refund_requested_at, now())
       WHERE id = $1
       RETURNING id, amount_cents, currency, payment_method, status,
                 created_at, paid_at, refund_requested_at`,
      [id],
    );

    // Only notify on the actual first request — re-requesting is a no-op
    // above (COALESCE keeps the original timestamp), so this avoids
    // spamming admins if the student taps the button again.
    if (payment.refund_requested_at === null) {
      const { rows: studentRows } = await pool.query(
        `SELECT (first_name || ' ' || last_name) AS name FROM users WHERE id = $1`,
        [userId],
      );
      const studentName = studentRows[0]?.name || "A student";
      notifyAdmins(
        "refund_requested",
        "🔁 Refund Requested",
        `${studentName} requested a refund for a ₱${(updated[0].amount_cents / 100).toFixed(2)} payment.`,
        id,
      );
    }

    res.json(updated[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to request refund." });
  }
};

// ── Payments: student cancels a still-pending request ───────────────────────
// PATCH /credits/payments/:id/cancel — body: { reason: string }. Only valid
// from 'pending' — once an admin has acted (succeeded/failed/refunded)
// there's nothing left to withdraw; a refund request is the right tool at
// that point instead. No credits/money ever moved for a pending payment,
// so this is just a status + reason write, no ledger/balance touch needed.
const MAX_CANCEL_REASON_LENGTH = 500;

exports.cancelPayment = async (req, res) => {
  const { id } = req.params;
  const userId = req.user.sub;
  const reason = (req.body.reason || "").trim();

  if (!reason) {
    return res.status(400).json({ error: "reason is required." });
  }
  if (reason.length > MAX_CANCEL_REASON_LENGTH) {
    return res.status(400).json({
      error: `reason must be ${MAX_CANCEL_REASON_LENGTH} characters or fewer.`,
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT id, status FROM payments WHERE id = $1 AND user_id = $2`,
      [id, userId],
    );
    if (!rows.length) {
      return res.status(404).json({ error: "Payment not found." });
    }
    if (rows[0].status !== "pending") {
      return res.status(409).json({
        error: `Cannot cancel a '${rows[0].status}' payment.`,
      });
    }

    const { rows: updated } = await pool.query(
      `UPDATE payments
       SET status = 'cancelled', cancel_reason = $1
       WHERE id = $2
       RETURNING id, amount_cents, currency, payment_method, status,
                 created_at, paid_at, cancel_reason`,
      [reason, id],
    );

    const { rows: studentRows } = await pool.query(
      `SELECT (first_name || ' ' || last_name) AS name FROM users WHERE id = $1`,
      [userId],
    );
    const studentName = studentRows[0]?.name || "A student";
    notifyAdmins(
      "payment_cancelled",
      "🚫 Payment Request Cancelled",
      `${studentName} cancelled a ₱${(updated[0].amount_cents / 100).toFixed(2)} top-up request. Reason: ${reason}`,
      id,
    );

    res.json(updated[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to cancel payment." });
  }
};

// GET /admin/payments — full transaction list + revenue totals.
// Supports optional ?status= and ?method= filters.
exports.listPaymentsAdmin = async (req, res) => {
  const { status, method } = req.query;
  const params = [];
  let where = "1=1";

  if (status) {
    params.push(status);
    where += ` AND p.status = $${params.length}`;
  }
  if (method) {
    params.push(method);
    where += ` AND p.payment_method = $${params.length}`;
  }

  try {
    const { rows } = await pool.query(
      `SELECT p.*, cp.name AS package_name,
              (u.first_name || ' ' || u.last_name) AS student_name, u.email AS student_email
       FROM payments p
       JOIN users u ON u.id = p.user_id
       LEFT JOIN credit_packages cp ON cp.id = p.credit_package_id
       WHERE ${where}
       ORDER BY p.created_at DESC`,
      params,
    );

    const totalRevenueCents = rows
      .filter((r) => r.status === "succeeded")
      .reduce((sum, r) => sum + r.amount_cents, 0);

    res.json({ payments: rows, totalRevenueCents });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch payments." });
  }
};
