// src/controllers/bookings.controller.js
const pool = require("../db/pool");

// ── GET /bookings — student sees their own, teacher sees theirs ───────────────
// ⚠️ CHANGED: users has full_name (not first/last). No student_profiles or
//             points_ledger tables — points aren't part of a booking row.
exports.list = async (req, res) => {
  const { role, sub } = req.user;
  const field = role === "student" ? "b.student_id" : "b.teacher_id";
  try {
    const { rows } = await pool.query(
      `SELECT b.*,
         s.full_name  AS student_name,
         t.full_name  AS teacher_name,
         tp.avatar_url AS teacher_avatar,
         p.name AS pricing_name, p.session_type
       FROM bookings b
       JOIN users s ON s.id = b.student_id
       JOIN users t ON t.id = b.teacher_id
       LEFT JOIN teacher_profiles tp ON tp.user_id = b.teacher_id
       LEFT JOIN pricing p ON p.id = b.pricing_id
       WHERE ${field} = $1
       ORDER BY b.scheduled_at DESC
       LIMIT 50`,
      [sub],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch bookings" });
  }
};

// ── POST /bookings — student creates booking ──────────────────────────────────
// ⚠️ CHANGED: cost comes from `pricing` (by pricingId), not a per-teacher
//             rate — teacher_profiles no longer has credits_per_session.
// ⚠️ CHANGED: credit balance is SUM(credits_ledger.amount) for the student,
//             filtered to currency='credits' — there's no students_profiles
//             .credits column to read or update directly.
// ⚠️ ASSUMPTION: durationMins is client-supplied (default 30). The pricing
//             table has no duration_mins column — if sessions should have a
//             fixed duration per session_type, tell me and I'll add that
//             column via migration instead of trusting the client value.
exports.create = async (req, res) => {
  const { sub } = req.user;
  const { teacherId, pricingId, scheduledAt, durationMins = 30 } = req.body;

  if (!teacherId || !pricingId || !scheduledAt)
    return res
      .status(400)
      .json({ error: "teacherId, pricingId, and scheduledAt are required" });

  try {
    // Confirm teacher exists and is approved
    const { rows: tp } = await pool.query(
      `SELECT is_approved FROM teacher_profiles WHERE user_id = $1`,
      [teacherId],
    );
    if (!tp.length || !tp[0].is_approved)
      return res
        .status(404)
        .json({ error: "Teacher not found or not approved" });

    // Look up cost from pricing
    const { rows: pricingRows } = await pool.query(
      `SELECT credits_per_session FROM pricing WHERE id = $1 AND is_active = true`,
      [pricingId],
    );
    if (!pricingRows.length)
      return res.status(404).json({ error: "Pricing option not found or inactive" });
    const creditsCost = pricingRows[0].credits_per_session;

    // Check student has enough credits (sum of ledger rows, currency='credits')
    const { rows: balanceRows } = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) AS balance
       FROM credits_ledger
       WHERE user_id = $1 AND currency = 'credits'`,
      [sub],
    );
    if (balanceRows[0].balance < creditsCost)
      return res.status(400).json({ error: "Insufficient credits" });

    // Deduct credits, create booking — rely on the partial unique index
    // (uq_bookings_teacher_slot_active) to catch double-booking races
    // instead of a separate pre-check + race condition.
    await pool.query("BEGIN");

    await pool.query(
      `INSERT INTO credits_ledger (user_id, amount, reason, currency)
       VALUES ($1, $2, $3, 'credits')`,
      [sub, -creditsCost, `Booked session (pricing ${pricingId})`],
    );

    let booking;
    try {
      const { rows } = await pool.query(
        `INSERT INTO bookings
           (student_id, teacher_id, pricing_id, scheduled_at, duration_mins, credits_cost, status)
         VALUES ($1,$2,$3,$4,$5,$6,'confirmed') RETURNING *`,
        [sub, teacherId, pricingId, scheduledAt, durationMins, creditsCost],
      );
      booking = rows[0];
    } catch (insertErr) {
      if (insertErr.code === "23505") {
        // unique_violation on uq_bookings_teacher_slot_active
        await pool.query("ROLLBACK");
        return res.status(409).json({ error: "Time slot already booked" });
      }
      throw insertErr;
    }

    await pool.query("COMMIT");
    res.status(201).json(booking);
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Booking failed" });
  }
};

// ── PATCH /bookings/:id/complete — teacher marks session done ─────────────────
// ⚠️ CHANGED: points_ledger doesn't exist — points are awarded as a
//             credits_ledger row with currency='points'.
exports.complete = async (req, res) => {
  const { id } = req.params;
  const { sub, role } = req.user;

  try {
    const { rows } = await pool.query(`SELECT * FROM bookings WHERE id = $1`, [
      id,
    ]);
    if (!rows.length)
      return res.status(404).json({ error: "Booking not found" });

    const booking = rows[0];
    if (role === "teacher" && booking.teacher_id !== sub)
      return res.status(403).json({ error: "Forbidden" });
    if (booking.status !== "confirmed")
      return res.status(400).json({ error: "Only confirmed bookings can be completed" });

    await pool.query("BEGIN");

    await pool.query(
      `UPDATE bookings SET status = 'completed', updated_at = now() WHERE id = $1`,
      [id],
    );

    // Award points to student (1 point per credit spent — same rule as before)
    const pointsEarned = booking.credits_cost;
    await pool.query(
      `INSERT INTO credits_ledger (user_id, amount, reason, currency)
       VALUES ($1, $2, $3, 'points')`,
      [booking.student_id, pointsEarned, `Session completed (booking ${id})`],
    );

    // Update teacher session count
    await pool.query(
      `UPDATE teacher_profiles SET total_sessions = total_sessions + 1, updated_at = now()
       WHERE user_id = $1`,
      [booking.teacher_id],
    );

    await pool.query("COMMIT");
    res.json({ message: "Session completed", pointsEarned });
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to complete session" });
  }
};

// ── PATCH /bookings/:id/cancel ────────────────────────────────────────────────
exports.cancel = async (req, res) => {
  const { id } = req.params;
  const { sub } = req.user;

  try {
    const { rows } = await pool.query(`SELECT * FROM bookings WHERE id = $1`, [
      id,
    ]);
    if (!rows.length) return res.status(404).json({ error: "Not found" });
    const b = rows[0];

    if (b.student_id !== sub && b.teacher_id !== sub)
      return res.status(403).json({ error: "Forbidden" });
    if (!["pending", "confirmed"].includes(b.status))
      return res.status(400).json({ error: "Cannot cancel this booking" });

    await pool.query("BEGIN");
    await pool.query(
      `UPDATE bookings SET status = 'cancelled', updated_at = now() WHERE id = $1`,
      [id],
    );
    // Refund credits to student via ledger, not a direct balance update
    await pool.query(
      `INSERT INTO credits_ledger (user_id, amount, reason, currency)
       VALUES ($1, $2, $3, 'credits')`,
      [b.student_id, b.credits_cost, `Refund for cancelled booking ${id}`],
    );
    await pool.query("COMMIT");

    res.json({ message: "Booking cancelled and credits refunded" });
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Cancellation failed" });
  }
};