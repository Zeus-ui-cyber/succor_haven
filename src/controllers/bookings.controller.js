// src/controllers/bookings.controller.js
const pool = require("../db/pool");

// ── GET /bookings — student sees their own, teacher sees theirs ───────────────
exports.list = async (req, res) => {
  const { role, sub } = req.user;
  const field = role === "student" ? "b.student_id" : "b.teacher_id";
  try {
    const { rows } = await pool.query(
      `SELECT b.*,
         s.first_name  AS student_first, s.last_name  AS student_last,
         t.first_name  AS teacher_first, t.last_name  AS teacher_last,
         t.avatar_url  AS teacher_avatar
       FROM bookings b
       JOIN users s ON s.id = b.student_id
       JOIN users t ON t.id = b.teacher_id
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
exports.create = async (req, res) => {
  const { sub } = req.user;
  const { teacherId, scheduledAt, durationMins = 30 } = req.body;

  try {
    // Get teacher's credit rate
    const { rows: tp } = await pool.query(
      `SELECT credits_per_session, is_approved FROM teacher_profiles WHERE user_id = $1`,
      [teacherId],
    );
    if (!tp.length || !tp[0].is_approved)
      return res
        .status(404)
        .json({ error: "Teacher not found or not approved" });

    const creditsCost = tp[0].credits_per_session;

    // Check student has enough credits
    const { rows: sp } = await pool.query(
      `SELECT credits FROM student_profiles WHERE user_id = $1`,
      [sub],
    );
    if (!sp.length || sp[0].credits < creditsCost)
      return res.status(400).json({ error: "Insufficient credits" });

    // Check for scheduling conflict
    const { rows: conflicts } = await pool.query(
      `SELECT id FROM bookings
       WHERE teacher_id = $1
         AND status IN ('pending','confirmed')
         AND scheduled_at = $2`,
      [teacherId, scheduledAt],
    );
    if (conflicts.length)
      return res.status(409).json({ error: "Time slot already booked" });

    // Deduct credits and create booking in a transaction
    await pool.query("BEGIN");
    await pool.query(
      `UPDATE student_profiles SET credits = credits - $1 WHERE user_id = $2`,
      [creditsCost, sub],
    );
    const { rows: booking } = await pool.query(
      `INSERT INTO bookings
         (student_id, teacher_id, scheduled_at, duration_mins, credits_cost, status)
       VALUES ($1,$2,$3,$4,$5,'confirmed') RETURNING *`,
      [sub, teacherId, scheduledAt, durationMins, creditsCost],
    );
    await pool.query("COMMIT");

    res.status(201).json(booking[0]);
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Booking failed" });
  }
};

// ── PATCH /bookings/:id/complete — teacher marks session done ─────────────────
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

    await pool.query("BEGIN");

    // Mark completed
    await pool.query(`UPDATE bookings SET status = 'completed' WHERE id = $1`, [
      id,
    ]);

    // Award points to student (1 point per credit spent)
    const pointsEarned = booking.credits_cost;
    await pool.query(
      `UPDATE student_profiles SET points = points + $1 WHERE user_id = $2`,
      [pointsEarned, booking.student_id],
    );
    await pool.query(
      `INSERT INTO points_ledger (user_id, booking_id, points, reason)
       VALUES ($1,$2,$3,'Session completed')`,
      [booking.student_id, id, pointsEarned],
    );

    // Update teacher session count
    await pool.query(
      `UPDATE teacher_profiles SET total_sessions = total_sessions + 1 WHERE user_id = $1`,
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
    await pool.query(`UPDATE bookings SET status = 'cancelled' WHERE id = $1`, [
      id,
    ]);
    // Refund credits to student
    await pool.query(
      `UPDATE student_profiles SET credits = credits + $1 WHERE user_id = $2`,
      [b.credits_cost, b.student_id],
    );
    await pool.query("COMMIT");

    res.json({ message: "Booking cancelled and credits refunded" });
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Cancellation failed" });
  }
};
