// src/controllers/payments.controller.js
//
// Phase 1: credit_packages CRUD (admin) + read-only payment history
// (student's own + admin's full list). No checkout/webhook logic yet —
// that's Phase 2, once a provider is confirmed. amount fields are stored
// in cents (integer) to avoid floating-point currency bugs.

const pool = require("../db/pool");

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

// ── Payments: read-only (Phase 1) ───────────────────────────────────────────
// GET /credits/payments/mine — student's own top-up history.
exports.listMyPayments = async (req, res) => {
  const userId = req.user.sub;
  try {
    const { rows } = await pool.query(
      `SELECT p.id, p.amount_cents, p.currency, p.payment_method, p.status,
              p.created_at, p.paid_at,
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
