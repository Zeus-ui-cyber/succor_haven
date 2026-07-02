// src/controllers/teachers.controller.js
const pool = require("../db/pool");

// ── GET /teachers — browse approved teachers ──────────────────────────────────
// ⚠️ CHANGED: users has full_name (not first_name/last_name). avatar_url,
//             rating, total_sessions all live on teacher_profiles, not users.
// ⚠️ REMOVED: credits_per_session — no longer a teacher_profiles column.
//             Session cost now comes from the `pricing` table (session_type),
//             selected by the student during booking — see bookings.controller.js.
//             If you want per-teacher rates instead, tell me and I'll add
//             a credits_per_session column back via migration.
exports.browse = async (req, res) => {
  const { subject, search, page = 1, limit = 20 } = req.query;
  const offset = (Number(page) - 1) * Number(limit);
  const params = [];
  let where = `tp.is_approved = true`;

  if (subject) {
    params.push(subject);
    where += ` AND $${params.length} = ANY(tp.subjects)`;
  }
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (u.full_name ILIKE $${params.length} OR tp.bio ILIKE $${params.length})`;
  }

  params.push(limit, offset);
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.full_name, u.email,
              tp.bio, tp.subjects, tp.availability, tp.avatar_url,
              tp.rating, tp.total_sessions
       FROM users u
       JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE u.role = 'teacher' AND ${where}
       ORDER BY tp.rating DESC, tp.total_sessions DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch teachers" });
  }
};

// ── GET /teachers/:id — single teacher profile ────────────────────────────────
exports.getOne = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.full_name, u.email, u.created_at,
              tp.bio, tp.subjects, tp.availability, tp.avatar_url,
              tp.rating, tp.total_sessions
       FROM users u
       JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE u.id = $1 AND u.role = 'teacher' AND tp.is_approved = true`,
      [req.params.id],
    );
    if (!rows.length)
      return res.status(404).json({ error: "Teacher not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch teacher" });
  }
};

// ── PATCH /teachers/profile — teacher updates own profile ─────────────────────
// ⚠️ CHANGED: no creditsPerSession param — that's not a teacher_profiles
//             column anymore.
exports.updateProfile = async (req, res) => {
  const { sub } = req.user;
  const { bio, subjects, availability, avatarUrl } = req.body;
  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM teacher_profiles WHERE user_id = $1`,
      [sub],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Teacher profile not found" });
    const existing = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE teacher_profiles
       SET bio = $1, subjects = $2, availability = $3, avatar_url = $4,
           updated_at = now()
       WHERE user_id = $5
       RETURNING *`,
      [
        bio ?? existing.bio,
        subjects ?? existing.subjects,
        availability ?? existing.availability,
        avatarUrl ?? existing.avatar_url,
        sub,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Update failed" });
  }
};