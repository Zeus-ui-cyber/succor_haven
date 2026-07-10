const bcrypt = require("bcrypt");
const pool = require("../db/pool");

// Shared pagination sanitizer — page/limit arrive as query strings with no
// bounds. page=0 or negative produces a negative OFFSET (Postgres error,
// not a clean 400); an unbounded limit lets a caller pull the whole table
// in one request. Clamped here instead of duplicating the same guard in
// every paginated endpoint.
function parsePagination(
  page,
  limit,
  { maxLimit = 100, defaultLimit = 30 } = {},
) {
  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(
    maxLimit,
    Math.max(1, parseInt(limit, 10) || defaultLimit),
  );
  return { pageNum, limitNum, offset: (pageNum - 1) * limitNum };
}

// ── GET /admin/dashboard ──────────────────────────────────────────────────────
exports.dashboard = async (req, res) => {
  try {
    const [users, bookings, revenue, pending] = await Promise.all([
      pool.query(`SELECT role, COUNT(*) FROM users GROUP BY role`),
      pool.query(`SELECT status, COUNT(*) FROM bookings GROUP BY status`),
      pool.query(
        `SELECT COALESCE(SUM(credits_cost),0) AS total FROM bookings WHERE status='completed'`,
      ),
      pool.query(
        `SELECT COUNT(*) FROM teacher_profiles WHERE is_approved = false`,
      ),
    ]);
    res.json({
      userCounts: users.rows,
      bookingCounts: bookings.rows,
      totalRevenueCents: Number(revenue.rows[0].total),
      pendingTeachers: Number(pending.rows[0].count),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Dashboard fetch failed" });
  }
};

// ── GET /admin/users ──────────────────────────────────────────────────────────
// ⚠️ FIXED (this pass): credits/points now read from student_profiles
// (the authoritative balance, same as bookings.controller.js) instead of
// SUM(credits_ledger). credits_ledger is an audit trail only — a new
// student's initial balance is never written there, so summing it
// under-reports (or entirely misses) any student who hasn't had a booking
// or admin adjustment yet. Teachers/admins simply show 0, same as before
// (they have no student_profiles row).
exports.listUsers = async (req, res) => {
  const { role, search } = req.query;
  const { pageNum, limitNum, offset } = parsePagination(
    req.query.page,
    req.query.limit,
  );
  const params = [];
  let where = "1=1";
  if (role) {
    params.push(role);
    where += ` AND u.role = $${params.length}`;
  }
  if (search) {
    params.push(`%${search}%`);
    where += ` AND ((u.first_name || ' ' || u.last_name) ILIKE $${params.length} OR u.email ILIKE $${params.length})`;
  }
  params.push(limitNum, offset);
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.email, u.phone,
              (u.first_name || ' ' || u.last_name) AS full_name,
              u.role, u.is_active, u.created_at,
              tp.is_approved AS teacher_approved,
              COALESCE(sp.credits, 0) AS credits,
              COALESCE(sp.points, 0) AS points
       FROM users u
       LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
       LEFT JOIN student_profiles sp ON sp.user_id = u.id
       WHERE ${where}
       ORDER BY u.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch users" });
  }
};

// ── PATCH /admin/teachers/:id/approve ────────────────────────────────────────
exports.approveTeacher = async (req, res) => {
  try {
    await pool.query(
      `UPDATE teacher_profiles SET is_approved = true WHERE user_id = $1`,
      [req.params.id],
    );
    res.json({ message: "Teacher approved" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Approval failed" });
  }
};

// ── POST /admin/teachers — Admin creates a Teacher account directly ───────────
exports.createTeacher = async (req, res) => {
  const {
    firstName,
    lastName,
    email,
    password,
    phone,
    bio,
    subjects,
    availability,
  } = req.body;

  if (!email) return res.status(400).json({ error: "Email required" });
  if (!password) return res.status(400).json({ error: "Password required" });
  if (!firstName) return res.status(400).json({ error: "First name required" });
  if (!lastName) return res.status(400).json({ error: "Last name required" });

  try {
    const hash = await bcrypt.hash(password, 10);

    await pool.query("BEGIN");

    const { rows } = await pool.query(
      `INSERT INTO users (email, password_hash, first_name, last_name, role, phone)
       VALUES ($1,$2,$3,$4,'teacher',$5)
       RETURNING *`,
      [email, hash, firstName.trim(), lastName.trim(), phone || null],
    );
    const user = rows[0];

    // teacher_profiles.availability is a real TEXT[] column (confirmed
    // live, same convention teachers.controller.js already uses) — pass
    // it through instead of silently dropping it.
    await pool.query(
      `INSERT INTO teacher_profiles
         (user_id, bio, subjects, availability, is_approved)
       VALUES ($1,$2,$3,$4,true)`,
      [user.id, bio || "", subjects || [], availability || []],
    );

    await pool.query("COMMIT");

    const { password_hash, ...publicUser } = user;
    res.status(201).json(publicUser);
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);

    if (err.code === "23505") {
      const field =
        err.constraint && err.constraint.includes("phone")
          ? "Phone number"
          : "Email";
      return res.status(409).json({ error: `${field} already registered` });
    }

    res.status(500).json({ error: "Failed to create teacher account" });
  }
};

// ── PATCH /admin/users/:id/toggle — activate / deactivate ─────────────────────
exports.toggleUser = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE users SET is_active = NOT is_active WHERE id = $1 RETURNING is_active`,
      [req.params.id],
    );
    if (!rows.length) return res.status(404).json({ error: "User not found" });
    res.json({ isActive: rows[0].is_active });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Toggle failed" });
  }
};

// ── DELETE /admin/users/:id — permanently delete a user ───────────────────────
exports.deleteUser = async (req, res) => {
  const { id } = req.params;

  if (String(req.user.sub) === String(id))
    return res
      .status(400)
      .json({ error: "You cannot delete your own account" });

  try {
    const { rows: existing } = await pool.query(
      `SELECT id FROM users WHERE id = $1`,
      [id],
    );
    if (!existing.length)
      return res.status(404).json({ error: "User not found" });

    const { rows: activity } = await pool.query(
      `SELECT COUNT(*) FROM bookings
       WHERE (student_id = $1 OR teacher_id = $1)
         AND status NOT IN ('cancelled')`,
      [id],
    );
    if (Number(activity[0].count) > 0) {
      return res.status(409).json({
        error:
          "User has booking history and cannot be deleted. Deactivate the account instead.",
      });
    }

    await pool.query(`DELETE FROM users WHERE id = $1`, [id]);
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete user" });
  }
};

// ── GET /admin/bookings ───────────────────────────────────────────────────────
exports.listBookings = async (req, res) => {
  const { status } = req.query;
  const { limitNum, offset } = parsePagination(req.query.page, req.query.limit);
  const params = [];
  let where = "1=1";
  if (status) {
    params.push(status);
    where += ` AND b.status = $${params.length}`;
  }
  params.push(limitNum, offset);
  try {
    const { rows } = await pool.query(
      `SELECT b.*,
         (s.first_name || ' ' || s.last_name) AS student_name,
         (t.first_name || ' ' || t.last_name) AS teacher_name
       FROM bookings b
       JOIN users s ON s.id = b.student_id
       JOIN users t ON t.id = b.teacher_id
       WHERE ${where}
       ORDER BY b.scheduled_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch bookings" });
  }
};

// ── GET /admin/rewards ────────────────────────────────────────────────────────
// ⚠️ FIXED (this pass): confirmed live via check_schema.js — rewards now
// has name/points_required/reward_type/reward_value (migration_002.sql
// renamed the old title/points_cost columns to match what this file and
// the Flutter app already expected). Ordering by points_required is
// correct as-is; no query changes needed here beyond this note.
exports.listRewards = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM rewards ORDER BY points_required`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch rewards" });
  }
};

// ── POST /admin/rewards ───────────────────────────────────────────────────────
exports.createReward = async (req, res) => {
  const { name, description, pointsRequired, rewardType, rewardValue } =
    req.body;
  try {
    const { rows } = await pool.query(
      `INSERT INTO rewards (name, description, points_required, reward_type, reward_value)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [name, description, pointsRequired, rewardType, rewardValue],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create reward" });
  }
};

// ── PATCH /admin/rewards/:id ──────────────────────────────────────────────────
exports.updateReward = async (req, res) => {
  const {
    name,
    description,
    pointsRequired,
    rewardType,
    rewardValue,
    isActive,
  } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE rewards SET name=$1, description=$2, points_required=$3,
         reward_type=$4, reward_value=$5, is_active=$6
       WHERE id=$7 RETURNING *`,
      [
        name,
        description,
        pointsRequired,
        rewardType,
        rewardValue,
        isActive,
        req.params.id,
      ],
    );
    if (!rows.length)
      return res.status(404).json({ error: "Reward not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Update failed" });
  }
};

// ── DELETE /admin/rewards/:id ─────────────────────────────────────────────────
exports.deleteReward = async (req, res) => {
  try {
    const { rowCount } = await pool.query(`DELETE FROM rewards WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rowCount) return res.status(404).json({ error: "Reward not found" });
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Delete failed" });
  }
};

// ── PATCH /admin/users/:id/credits — admin adjusts a student's credit balance ─
// body: { amount: number (can be negative), reason?: string }
// ⚠️ FIXED (this pass): student_profiles.credits is the authoritative
// balance (see bookings.controller.js). This previously only wrote a
// credits_ledger row and computed the "new" balance as
// SUM(credits_ledger) — never touching student_profiles at all. That
// meant an admin's credit adjustment would show a different number here
// than what bookings.controller.js actually used to decide if the student
// could book a session, since the two were reading from different places.
// Now: read/lock the real balance from student_profiles, update it
// directly, and still log the change to credits_ledger as an audit trail
// (not as the source of truth) — same pattern bookings.controller.js uses.
exports.adjustCredits = async (req, res) => {
  const { id } = req.params;
  const { amount, reason } = req.body;
  const delta = Number(amount);

  if (!Number.isFinite(delta) || delta === 0)
    return res.status(400).json({ error: "amount must be a non-zero number" });

  try {
    const { rows: userRows } = await pool.query(
      `SELECT role FROM users WHERE id = $1`,
      [id],
    );
    if (!userRows.length)
      return res.status(404).json({ error: "User not found" });
    if (userRows[0].role !== "student")
      return res
        .status(400)
        .json({ error: "Credit adjustments only apply to student accounts" });

    await pool.query("BEGIN");

    const { rows: spRows } = await pool.query(
      `SELECT credits FROM student_profiles WHERE user_id = $1 FOR UPDATE`,
      [id],
    );
    if (!spRows.length) {
      await pool.query("ROLLBACK");
      return res.status(404).json({ error: "Student profile not found" });
    }

    const newBalance = spRows[0].credits + delta;
    if (newBalance < 0) {
      await pool.query("ROLLBACK");
      return res
        .status(400)
        .json({ error: "Adjustment would result in negative credits" });
    }

    await pool.query(
      `UPDATE student_profiles SET credits = $1 WHERE user_id = $2`,
      [newBalance, id],
    );
    await pool.query(
      `INSERT INTO credits_ledger (user_id, amount, reason, currency)
       VALUES ($1, $2, $3, 'credits')`,
      [id, delta, reason || (delta > 0 ? "Admin credit" : "Admin deduction")],
    );

    await pool.query("COMMIT");
    res.json({ credits: newBalance });
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to adjust credits" });
  }
};

// ── PATCH /admin/users/:id/points — admin adjusts a student's points balance ──
// body: { amount: number (can be negative), reason?: string }
// ⚠️ FIXED (this pass): same student_profiles-as-source-of-truth fix as
// adjustCredits above. points_ledger (not credits_ledger currency='points')
// is the real audit-trail table for points — matches
// bookings.controller.js complete().
exports.adjustPoints = async (req, res) => {
  const { id } = req.params;
  const { amount, reason } = req.body;
  const delta = Number(amount);

  if (!Number.isFinite(delta) || delta === 0)
    return res.status(400).json({ error: "amount must be a non-zero number" });

  try {
    const { rows: userRows } = await pool.query(
      `SELECT role FROM users WHERE id = $1`,
      [id],
    );
    if (!userRows.length)
      return res.status(404).json({ error: "User not found" });
    if (userRows[0].role !== "student")
      return res
        .status(400)
        .json({ error: "Point adjustments only apply to student accounts" });

    await pool.query("BEGIN");

    const { rows: spRows } = await pool.query(
      `SELECT points FROM student_profiles WHERE user_id = $1 FOR UPDATE`,
      [id],
    );
    if (!spRows.length) {
      await pool.query("ROLLBACK");
      return res.status(404).json({ error: "Student profile not found" });
    }

    const newBalance = spRows[0].points + delta;
    if (newBalance < 0) {
      await pool.query("ROLLBACK");
      return res
        .status(400)
        .json({ error: "Adjustment would result in negative points" });
    }

    await pool.query(
      `UPDATE student_profiles SET points = $1 WHERE user_id = $2`,
      [newBalance, id],
    );
    await pool.query(
      `INSERT INTO points_ledger (user_id, points, reason)
       VALUES ($1, $2, $3)`,
      [id, delta, reason || (delta > 0 ? "Admin credit" : "Admin deduction")],
    );

    await pool.query("COMMIT");
    res.json({ points: newBalance });
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Failed to adjust points" });
  }
};

// ── GET /admin/teachers/:id/bookings — admin views a teacher's full schedule ──
exports.teacherSchedule = async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await pool.query(
      `SELECT b.*,
         (s.first_name || ' ' || s.last_name) AS student_name,
         (t.first_name || ' ' || t.last_name) AS teacher_name
       FROM bookings b
       JOIN users s ON s.id = b.student_id
       JOIN users t ON t.id = b.teacher_id
       WHERE b.teacher_id = $1
       ORDER BY b.scheduled_at DESC
       LIMIT 100`,
      [id],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch teacher schedule" });
  }
};

// ── PATCH /admin/bookings/:id/cancel — admin force-cancels any booking ────────
// ⚠️ FIXED (this pass): refund now updates student_profiles.credits
// directly (the authoritative balance), with credits_ledger kept as the
// audit-trail entry — same pattern as bookings.controller.js's own
// cancel(). Previously this only inserted a credits_ledger row without
// touching student_profiles, so an admin-cancelled booking's refund never
// actually reached the student's real balance.
exports.cancelBooking = async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await pool.query(`SELECT * FROM bookings WHERE id = $1`, [
      id,
    ]);
    if (!rows.length)
      return res.status(404).json({ error: "Booking not found" });
    const b = rows[0];

    if (!["pending", "confirmed"].includes(b.status))
      return res.status(400).json({ error: "Cannot cancel this booking" });

    await pool.query("BEGIN");
    await pool.query(`UPDATE bookings SET status = 'cancelled' WHERE id = $1`, [
      id,
    ]);
    await pool.query(
      `UPDATE student_profiles SET credits = credits + $1 WHERE user_id = $2`,
      [b.credits_cost, b.student_id],
    );
    await pool.query(
      `INSERT INTO credits_ledger (user_id, amount, reason, currency)
       VALUES ($1, $2, $3, 'credits')`,
      [
        b.student_id,
        b.credits_cost,
        `Refund for cancelled booking ${id} (admin)`,
      ],
    );
    await pool.query("COMMIT");

    res.json({ message: "Booking cancelled and credits refunded" });
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Cancellation failed" });
  }
};
