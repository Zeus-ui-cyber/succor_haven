// src/controllers/bookings.controller.js
const pool = require("../db/pool");

// ── GET /bookings — student sees their own, teacher sees theirs ───────────────
// Uses first_name/last_name (the real users columns, confirmed live via
// check_schema.js) concatenated to a single display name, same convention
// as teachers.controller.js. Dropped the `pricing` table join — that table
// does not exist in the live database; session cost comes from
// teacher_profiles.credits_per_session at booking time instead (see
// create() below).
//
// FIXED: avatar_url lives on `users` (aliased `t` for the teacher's user
// row here), NOT on `teacher_profiles` (aliased `tp`) — teachers.controller.js
// confirms this too (it updates avatar_url via a separate UPDATE on
// `users`). The query below referenced `tp.avatar_url`, which doesn't
// exist and made every /bookings request fail with a 500
// ("column tp.avatar_url does not exist"). Changed to `t.avatar_url`.
exports.list = async (req, res) => {
  const { role, sub } = req.user;
  const field = role === "student" ? "b.student_id" : "b.teacher_id";
  try {
    const { rows } = await pool.query(
      `SELECT b.*,
         (s.first_name || ' ' || s.last_name) AS student_name,
         (t.first_name || ' ' || t.last_name) AS teacher_name,
         t.avatar_url AS teacher_avatar
       FROM bookings b
       JOIN users s ON s.id = b.student_id
       JOIN users t ON t.id = b.teacher_id
       LEFT JOIN teacher_profiles tp ON tp.user_id = b.teacher_id
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
// Cost comes from the teacher's own teacher_profiles.credits_per_session —
// there is no `pricing` table in the live database, so this no longer
// accepts/looks up a pricingId. student_profiles.credits is the
// authoritative balance (kept in sync everywhere, including
// admin.controller.js's adjustCredits) — credits_ledger is written
// alongside it purely as a history/audit log, not as the source of truth.
exports.create = async (req, res) => {
  const { sub } = req.user;
  const { teacherId, scheduledAt, durationMins = 30 } = req.body;

  if (!teacherId || !scheduledAt)
    return res
      .status(400)
      .json({ error: "teacherId and scheduledAt are required" });

  try {
    // Confirm teacher exists, is approved, and get their session cost
    const { rows: tp } = await pool.query(
      `SELECT is_approved, credits_per_session FROM teacher_profiles WHERE user_id = $1`,
      [teacherId],
    );
    if (!tp.length || !tp[0].is_approved)
      return res
        .status(404)
        .json({ error: "Teacher not found or not approved" });
    const creditsCost = tp[0].credits_per_session ?? 6;

    // Check student has enough credits (student_profiles.credits is the
    // authoritative balance)
    const { rows: sp } = await pool.query(
      `SELECT credits FROM student_profiles WHERE user_id = $1`,
      [sub],
    );
    if (!sp.length || sp[0].credits < creditsCost)
      return res.status(400).json({ error: "Insufficient credits" });

    await pool.query("BEGIN");

    await pool.query(
      `UPDATE student_profiles SET credits = credits - $1 WHERE user_id = $2`,
      [creditsCost, sub],
    );
    await pool.query(
      `INSERT INTO credits_ledger (user_id, amount, reason, currency)
       VALUES ($1, $2, $3, 'credits')`,
      [sub, -creditsCost, `Booked session with teacher ${teacherId}`],
    );

    const { rows } = await pool.query(
      `INSERT INTO bookings
         (student_id, teacher_id, scheduled_at, duration_mins, credits_cost, status)
       VALUES ($1,$2,$3,$4,$5,'confirmed') RETURNING *`,
      [sub, teacherId, scheduledAt, durationMins, creditsCost],
    );

    await pool.query("COMMIT");
    res.status(201).json(rows[0]);
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Booking failed" });
  }
};

// ── PATCH /bookings/:id/complete — teacher marks session done ─────────────────
// Points are awarded via points_ledger (matches admin.controller.js's
// adjustPoints — keeping a single ledger table for points instead of
// splitting between points_ledger and credits_ledger(currency='points')).
// student_profiles.points is updated directly too, same authoritative-
// balance pattern as credits.
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
      return res
        .status(400)
        .json({ error: "Only confirmed bookings can be completed" });

    await pool.query("BEGIN");

    await pool.query(`UPDATE bookings SET status = 'completed' WHERE id = $1`, [
      id,
    ]);

    // Award points to student (1 point per credit spent — same rule as before)
    const pointsEarned = booking.credits_cost;
    await pool.query(
      `UPDATE student_profiles SET points = points + $1 WHERE user_id = $2`,
      [pointsEarned, booking.student_id],
    );
    await pool.query(
      `INSERT INTO points_ledger (user_id, booking_id, points, reason)
       VALUES ($1, $2, $3, $4)`,
      [
        booking.student_id,
        id,
        pointsEarned,
        `Session completed (booking ${id})`,
      ],
    );

    // Update teacher session count
    await pool.query(
      `UPDATE teacher_profiles SET total_sessions = total_sessions + 1
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
    await pool.query(`UPDATE bookings SET status = 'cancelled' WHERE id = $1`, [
      id,
    ]);
    // Refund credits — update the authoritative balance and log it
    await pool.query(
      `UPDATE student_profiles SET credits = credits + $1 WHERE user_id = $2`,
      [b.credits_cost, b.student_id],
    );
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
