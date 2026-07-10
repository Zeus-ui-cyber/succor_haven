// src/controllers/studentsAdmin.controller.js
//
// Admin > Students List feature.
//
// Confirmed live schema (check_schema.js):
//   - student_profiles IS a real table (user_id, credits, points,
//     native_language, learning_goals, level) — it's the authoritative
//     balance source, same as bookings.controller.js already uses.
//   - course / year_level live directly on users (u.course, u.year_level)
//     — added via migration_001.sql.
//
// ⚠️ FIXED (this pass): list()/getOne() previously computed credits/points
// as SUM(credits_ledger.amount) grouped by currency. credits_ledger is
// only ever an audit trail of deltas (bookings, admin adjustments) — a
// new student's starting balance is never written there — so summing it
// diverges from student_profiles.credits/points, the number
// bookings.controller.js actually checks/updates when a student books a
// session. Switched both to read student_profiles directly.
//
// ⚠️ STILL OPEN: no `phone_verified` column exists on `users`. The
// verified/unverified filter and field remain disabled below with a TODO,
// same as before — if a "verified" concept exists at all it likely lives
// elsewhere (e.g. an OTP/verification log table). Confirm the real column
// name if/when this needs wiring up.

const bcrypt = require("bcrypt");
const crypto = require("crypto");
const pool = require("../db/pool");

// ── GET /admin/students ───────────────────────────────────────────────────────
exports.list = async (req, res) => {
  const {
    search,
    status,
    /* verified, */ course,
    page = 1,
    limit = 20,
  } = req.query;

  const params = [];
  let where = `u.role = 'student'`;

  if (search) {
    params.push(`%${search}%`);
    const i = params.length;
    where += ` AND (
      u.first_name ILIKE $${i} OR u.last_name ILIKE $${i} OR
      u.email ILIKE $${i} OR u.phone ILIKE $${i} OR
      u.id::text ILIKE $${i} OR u.course ILIKE $${i}
    )`;
  }
  if (status === "active") where += ` AND u.is_active = true`;
  if (status === "inactive") where += ` AND u.is_active = false`;

  // TODO: re-enable once the real "verified" column name is confirmed.
  // if (verified === "verified") where += ` AND u.phone_verified = true`;
  // if (verified === "unverified") where += ` AND u.phone_verified = false`;

  if (course) {
    params.push(course);
    where += ` AND u.course = $${params.length}`;
  }

  const offset = (Number(page) - 1) * Number(limit);
  params.push(limit, offset);

  try {
    const { rows } = await pool.query(
      `SELECT
         u.id, u.first_name, u.last_name, u.email, u.phone,
         u.avatar_url, u.is_active, u.created_at,
         u.course, u.year_level,
         COALESCE(sp.credits, 0) AS credits,
         COALESCE(sp.points, 0) AS points,
         COUNT(*) OVER() AS total_count,
         (SELECT COUNT(*) FROM bookings b
            WHERE b.student_id = u.id AND b.status IN ('pending','confirmed')
              AND b.scheduled_at > now()) AS upcoming_sessions
       FROM users u
       LEFT JOIN student_profiles sp ON sp.user_id = u.id
       WHERE ${where}
       ORDER BY u.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );

    const total = rows.length ? Number(rows[0].total_count) : 0;
    const students = rows.map(({ total_count, ...r }) => r);

    res.json({
      students,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        totalPages: Math.max(1, Math.ceil(total / Number(limit))),
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch students" });
  }
};

// ── GET /admin/students/summary ───────────────────────────────────────────────
// (unchanged — this one never referenced student_profiles or phone_verified)
exports.summary = async (req, res) => {
  try {
    const [total, active, inactive, upcoming] = await Promise.all([
      pool.query(`SELECT COUNT(*) FROM users WHERE role = 'student'`),
      pool.query(
        `SELECT COUNT(*) FROM users WHERE role = 'student' AND is_active = true`,
      ),
      pool.query(
        `SELECT COUNT(*) FROM users WHERE role = 'student' AND is_active = false`,
      ),
      pool.query(
        `SELECT COUNT(DISTINCT student_id) FROM bookings
         WHERE status IN ('pending','confirmed') AND scheduled_at > now()`,
      ),
    ]);
    res.json({
      totalStudents: Number(total.rows[0].count),
      activeStudents: Number(active.rows[0].count),
      inactiveStudents: Number(inactive.rows[0].count),
      studentsWithUpcomingSessions: Number(upcoming.rows[0].count),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch student summary" });
  }
};

// ── GET /admin/students/:id ───────────────────────────────────────────────────
exports.getOne = async (req, res) => {
  const { id } = req.params;
  try {
    const { rows: profileRows } = await pool.query(
      `SELECT u.id, u.first_name, u.last_name, u.email, u.phone,
              u.avatar_url, u.is_active, u.created_at,
              u.course, u.year_level,
              COALESCE(sp.credits, 0) AS credits,
              COALESCE(sp.points, 0) AS points
       FROM users u
       LEFT JOIN student_profiles sp ON sp.user_id = u.id
       WHERE u.id = $1 AND u.role = 'student'`,
      [id],
    );
    if (!profileRows.length)
      return res.status(404).json({ error: "Student not found" });
    const profile = profileRows[0];

    const { rows: subjectRows } = await pool.query(
      `SELECT DISTINCT unnest(tp.subjects) AS subject
       FROM bookings b
       JOIN teacher_profiles tp ON tp.user_id = b.teacher_id
       WHERE b.student_id = $1`,
      [id],
    );

    const { rows: sessions } = await pool.query(
      `SELECT b.id, b.scheduled_at, b.duration_mins, b.status, b.credits_cost,
              t.first_name AS teacher_first, t.last_name AS teacher_last
       FROM bookings b
       JOIN users t ON t.id = b.teacher_id
       WHERE b.student_id = $1
       ORDER BY b.scheduled_at DESC
       LIMIT 100`,
      [id],
    );

    const completed = sessions.filter((s) => s.status === "completed");
    const cancelled = sessions.filter((s) => s.status === "cancelled");
    const attendanceBase = completed.length + cancelled.length;

    const progressSummary = {
      totalSessionsCompleted: completed.length,
      totalBookings: sessions.length,
      subjectsCompleted: subjectRows.length,
      attendanceRate:
        attendanceBase === 0
          ? null
          : Math.round((completed.length / attendanceBase) * 100),
      lastSessionDate: completed[0]?.scheduled_at ?? null,
    };

    const timeline = [
      {
        type: "account_created",
        at: profile.created_at,
        label: "Account created",
      },
      ...sessions.map((s) => ({
        type:
          s.status === "completed"
            ? "session_completed"
            : s.status === "cancelled"
              ? "session_cancelled"
              : "session_booked",
        at: s.scheduled_at,
        label: `Session with ${s.teacher_first} ${s.teacher_last} — ${s.status}`,
      })),
    ].sort((a, b) => new Date(b.at) - new Date(a.at));

    res.json({
      profile,
      takenSubjects: subjectRows.map((r) => r.subject),
      sessionHistory: sessions.map((s) => ({
        id: s.id,
        scheduledAt: s.scheduled_at,
        durationMins: s.duration_mins,
        status: s.status,
        creditsCost: s.credits_cost,
        teacherName: `${s.teacher_first} ${s.teacher_last}`,
        teacherNotes: null,
      })),
      progressSummary,
      activityTimeline: timeline,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch student detail" });
  }
};

// ── PATCH /admin/students/:id ─────────────────────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;
  let { firstName, lastName, email, phone, course, yearLevel } = req.body;

  if (typeof firstName === "string" && firstName.trim() === "")
    firstName = null;
  if (typeof lastName === "string" && lastName.trim() === "") lastName = null;
  if (typeof email === "string" && email.trim() === "") email = null;
  if (typeof phone === "string" && phone.trim() === "") phone = null;

  try {
    await pool.query(
      `UPDATE users SET
         first_name = COALESCE($1, first_name),
         last_name  = COALESCE($2, last_name),
         email      = COALESCE($3, email),
         phone      = COALESCE($4, phone),
         course     = COALESCE($5, course),
         year_level = COALESCE($6, year_level)
       WHERE id = $7 AND role = 'student'`,
      [firstName, lastName, email, phone, course, yearLevel, id],
    );

    res.json({ message: "Student updated" });
  } catch (err) {
    console.error(err);
    if (err.code === "23505") {
      return res.status(409).json({ error: "Email or phone already in use" });
    }
    res.status(500).json({ error: "Failed to update student" });
  }
};

// ── POST /admin/students/:id/reset-password ───────────────────────────────────
exports.resetPassword = async (req, res) => {
  const { id } = req.params;
  try {
    const tempPassword = crypto.randomBytes(6).toString("base64url");
    const hash = await bcrypt.hash(tempPassword, 10);

    const { rowCount } = await pool.query(
      `UPDATE users SET password_hash = $1 WHERE id = $2 AND role = 'student'`,
      [hash, id],
    );
    if (!rowCount) return res.status(404).json({ error: "Student not found" });

    res.json({ tempPassword });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to reset password" });
  }
};
