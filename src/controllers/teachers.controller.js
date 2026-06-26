// src/controllers/teachers.controller.js
const pool = require("../db/pool");

// ── GET /teachers — browse approved teachers ──────────────────────────────────
exports.browse = async (req, res) => {
  const { subject, search, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;
  const params = [];
  let where = `tp.is_approved = true`;

  if (subject) {
    params.push(subject);
    where += ` AND $${params.length} = ANY(tp.subjects)`;
  }
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (u.first_name ILIKE $${params.length} OR u.last_name ILIKE $${params.length} OR tp.bio ILIKE $${params.length})`;
  }

  params.push(limit, offset);
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.first_name, u.last_name, u.avatar_url,
              tp.bio, tp.subjects, tp.availability,
              tp.credits_per_session, tp.rating, tp.total_sessions
       FROM users u
       JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE ${where}
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
      `SELECT u.id, u.first_name, u.last_name, u.avatar_url, u.created_at,
              tp.bio, tp.subjects, tp.availability,
              tp.credits_per_session, tp.rating, tp.total_sessions
       FROM users u
       JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE u.id = $1 AND tp.is_approved = true`,
      [req.params.id],
    );
    if (!rows.length)
      return res.status(404).json({ error: "Teacher not found" });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch teacher" });
  }
};

// ── PATCH /teachers/profile — teacher updates own profile ─────────────────────
exports.updateProfile = async (req, res) => {
  const { sub } = req.user;
  const { bio, subjects, availability, creditsPerSession } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE teacher_profiles
       SET bio=$1, subjects=$2, availability=$3, credits_per_session=$4
       WHERE user_id=$5 RETURNING *`,
      [bio, subjects, availability, creditsPerSession, sub],
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Update failed" });
  }
};
