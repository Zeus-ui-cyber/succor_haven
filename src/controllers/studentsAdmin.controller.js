// src/controllers/studentsAdmin.controller.js
//
// Admin > Students List feature.
//
// Corrected schema assumptions (per live pgAdmin check):
//   - There is NO student_profiles table.
//   - course / year_level live directly on users (u.course, u.year_level).
//   - credits / points are NOT stored anywhere directly — derived from
//     credits_ledger, summed by currency ('credits' | 'points'), same
//     convention as admin.controller.js's listUsers/adjustCredits/adjustPoints.
//
// ⚠️ FIXED (audit, round 2): removed all references to `u.phone_verified`.
// Live error: "column u.phone_verified does not exist". Note that
// u.first_name, u.last_name, u.avatar_url, and u.is_active are NOT flagged
// as errors even though they appear earlier in the same SELECT, which
// confirms those columns are real — only phone_verified is wrong.
//
// I don't know the real column name (if a "verified" concept exists on
// `users` at all — it might live elsewhere, e.g. an OTP/verification log
// table). Rather than guess and reintroduce another broken column, the
// `verified`/`unverified` filter and the field are disabled for now with
// a TODO. Run `\d users` in psql (or check pgAdmin) and tell me the real
// column name and I'll wire the filter back in.
//
// ⚠️ NOTE: the Flutter side (student_detail_screen.dart, students_list_
// screen.dart) still reads profile['phone_verified'] to render a Verified/
// Unverified badge. Since this field no longer exists in the API response,
// that badge will always render "Unverified" — not a crash, just
// misleading until the real column is confirmed and wired back in on both
// ends. Same applies to the "Verified" filter dropdown in
// students_list_screen.dart — it currently sends a `verified` query param
// that this controller silently ignores.

const bcrypt = require("bcrypt");
const crypto = require("crypto");
const pool = require("../db/pool");

// ── GET /admin/students ───────────────────────────────────────────────────────
exports.list = async (req, res) => {
  const { search, status, /* verified, */ course, page = 1, limit = 20 } = req.query;

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
         COALESCE((
           SELECT SUM(amount) FROM credits_ledger cl
           WHERE cl.user_id = u.id AND cl.currency = 'credits'
         ), 0) AS credits,
         COALESCE((
           SELECT SUM(amount) FROM credits_ledger cl
           WHERE cl.user_id = u.id AND cl.currency = 'points'
         ), 0) AS points,
         COUNT(*) OVER() AS total_count,
         (SELECT COUNT(*) FROM bookings b
            WHERE b.student_id = u.id AND b.status IN ('pending','confirmed')
              AND b.scheduled_at > now()) AS upcoming_sessions
       FROM users u
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
              COALESCE((
                SELECT SUM(amount) FROM credits_ledger cl
                WHERE cl.user_id = u.id AND cl.currency = 'credits'
              ), 0) AS credits,
              COALESCE((
                SELECT SUM(amount) FROM credits_ledger cl
                WHERE cl.user_id = u.id AND cl.currency = 'points'
              ), 0) AS points
       FROM users u
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
              t.first_name AS teacher_first, t.last_name AS teacher_last,
              pr.name AS pricing_name
       FROM bookings b
       JOIN users t ON t.id = b.teacher_id
       LEFT JOIN pricing pr ON pr.id = b.pricing_id
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
        pricingName: s.pricing_name,
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
// ⚠️ FIXED: COALESCE($n, column) only skips a parameter when it's SQL NULL,
// not an empty string. The Flutter edit sheet always sends every field as
// a string (never null, to avoid a TextEditingController crash on missing
// data), so an untouched, previously-empty field like email/phone would
// get explicitly overwritten with '' instead of being left alone.
// firstName/lastName/email/phone are treated as required — a blank
// submission for these means "unchanged," not "clear it." course/
// yearLevel are optional fields where an intentional blank ("no longer
// enrolled") is valid, so those are left able to be cleared.
exports.update = async (req, res) => {
  const { id } = req.params;
  let { firstName, lastName, email, phone, course, yearLevel } = req.body;

  if (typeof firstName === "string" && firstName.trim() === "") firstName = null;
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
// (unchanged)
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