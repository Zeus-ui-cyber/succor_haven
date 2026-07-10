// src/controllers/teachers.controller.js
const pool = require("../db/pool");

const MAX_BIO_LENGTH = 500;

// Valid weekday tokens used across the app (matches
// create_teacher_account_screen.dart's day chips and admin.controller.js's
// createTeacher `availability` array).
const VALID_DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

async function getOwnProfileRow(userId) {
  const { rows } = await pool.query(
    `SELECT * FROM teacher_profiles WHERE user_id = $1`,
    [userId],
  );
  return rows[0] || null;
}

// ── GET /teachers — browse approved teachers ──────────────────────────────────
// Confirmed live via check_schema.js: teacher_profiles.availability IS a
// real column (plain TEXT[] of day names, e.g. {'Mon','Wed'}) and
// credits_per_session IS a real column too (default 6) — both are included
// here. users has first_name/last_name (not full_name); concatenated into
// full_name in the response so the Flutter side's existing parsing
// (TeacherProfileModel.fromJson) doesn't need to change.
//
// NOTE: tp.rating is cast to ::float8 because Postgres NUMERIC/DECIMAL
// columns are serialized as strings (e.g. "0.00") by the pg driver by
// default. TeacherProfileModel.fromJson does `json['rating'] as num?`,
// which throws on a String. Casting to float8 here makes it come back as
// a real JSON number instead.
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
    where += ` AND ((u.first_name || ' ' || u.last_name) ILIKE $${params.length} OR tp.bio ILIKE $${params.length})`;
  }

  params.push(limit, offset);
  try {
    const { rows } = await pool.query(
      `SELECT u.id, (u.first_name || ' ' || u.last_name) AS full_name, u.email, u.avatar_url,
              tp.bio, tp.subjects, tp.availability,
              tp.credits_per_session, tp.rating::float8, tp.total_sessions
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
// Same ::float8 cast as browse() above — without it, opening a teacher's
// profile page would throw the identical TypeError the list did.
exports.getOne = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, (u.first_name || ' ' || u.last_name) AS full_name, u.email, u.created_at, u.avatar_url,
              tp.bio, tp.subjects, tp.availability,
              tp.credits_per_session, tp.rating::float8, tp.total_sessions
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

// ── PATCH /teachers/profile — full-object update ───────────────────────────────
// `avatar_url` lives on `users`, not `teacher_profiles` — updated with a
// separate statement in the same transaction.
exports.updateProfile = async (req, res) => {
  const { sub } = req.user;
  const { bio, subjects, availability, avatarUrl } = req.body;
  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    await pool.query("BEGIN");

    const { rows } = await pool.query(
      `UPDATE teacher_profiles
       SET bio = $1, subjects = $2, availability = $3
       WHERE user_id = $4
       RETURNING *`,
      [
        bio ?? existing.bio,
        subjects ?? existing.subjects,
        availability ?? existing.availability,
        sub,
      ],
    );

    if (avatarUrl !== undefined) {
      await pool.query(`UPDATE users SET avatar_url = $1 WHERE id = $2`, [
        avatarUrl,
        sub,
      ]);
    }

    await pool.query("COMMIT");
    res.json(rows[0]);
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ error: "Update failed" });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS: BIO & SUBJECTS (granular — used by Edit Bio & Subjects screen)
// ═══════════════════════════════════════════════════════════════════════

// GET /teachers/profile/me
// Returns { bio, subjects } for the settings screen to load into its form.
exports.getMyProfile = async (req, res) => {
  const { sub } = req.user;
  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    res.json({
      bio: existing.bio || "",
      subjects: existing.subjects || [],
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch profile" });
  }
};

// PATCH /teachers/profile/bio
// body: { bio }
exports.updateBio = async (req, res) => {
  const { sub } = req.user;
  const { bio } = req.body;

  if (typeof bio !== "string") {
    return res.status(400).json({ error: "Bio must be a string." });
  }
  if (bio.length > MAX_BIO_LENGTH) {
    return res
      .status(400)
      .json({ error: `Bio must be ${MAX_BIO_LENGTH} characters or fewer.` });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    await pool.query(
      `UPDATE teacher_profiles SET bio = $1 WHERE user_id = $2`,
      [bio.trim(), sub],
    );
    res.json({ message: "Bio updated successfully." });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update bio." });
  }
};

// POST /teachers/profile/subjects
// body: { subject }
// `subjects` is stored as a plain text[] column — items are identified by
// their exact text (case-insensitive), there's no separate numeric id.
exports.addSubject = async (req, res) => {
  const { sub } = req.user;
  const { subject } = req.body;

  if (!subject?.trim()) {
    return res.status(400).json({ error: "Subject is required." });
  }
  const trimmed = subject.trim();

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.subjects || [];
    if (current.some((s) => s.toLowerCase() === trimmed.toLowerCase())) {
      return res
        .status(409)
        .json({ error: "This subject has already been added." });
    }

    const updated = [...current, trimmed];
    await pool.query(
      `UPDATE teacher_profiles SET subjects = $1 WHERE user_id = $2`,
      [updated, sub],
    );
    res
      .status(201)
      .json({ message: "Subject added successfully.", subjects: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to add subject." });
  }
};

// PATCH /teachers/profile/subjects
// body: { oldSubject, newSubject }
exports.updateSubject = async (req, res) => {
  const { sub } = req.user;
  const { oldSubject, newSubject } = req.body;

  if (!oldSubject?.trim() || !newSubject?.trim()) {
    return res
      .status(400)
      .json({ error: "oldSubject and newSubject are required." });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.subjects || [];
    const index = current.findIndex(
      (s) => s.toLowerCase() === oldSubject.trim().toLowerCase(),
    );
    if (index === -1) {
      return res.status(404).json({ error: "Subject not found." });
    }

    const updated = [...current];
    updated[index] = newSubject.trim();

    await pool.query(
      `UPDATE teacher_profiles SET subjects = $1 WHERE user_id = $2`,
      [updated, sub],
    );
    res.json({ message: "Subject updated successfully.", subjects: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update subject." });
  }
};

// DELETE /teachers/profile/subjects
// body: { subject }
exports.removeSubject = async (req, res) => {
  const { sub } = req.user;
  const { subject } = req.body;

  if (!subject?.trim()) {
    return res.status(400).json({ error: "Subject is required." });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.subjects || [];
    const updated = current.filter(
      (s) => s.toLowerCase() !== subject.trim().toLowerCase(),
    );

    if (updated.length === current.length) {
      return res.status(404).json({ error: "Subject not found." });
    }

    await pool.query(
      `UPDATE teacher_profiles SET subjects = $1 WHERE user_id = $2`,
      [updated, sub],
    );
    res.json({ message: "Subject removed successfully.", subjects: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to remove subject." });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS: AVAILABILITY (used by Set Availability screen)
//
// teacher_profiles.availability is a plain TEXT[] of weekday names (e.g.
// {'Mon','Wed','Fri'}) — confirmed live via check_schema.js. There is no
// separate teacher_availability table and no per-slot start/end time; a
// teacher is simply available or not on a given weekday. This matches
// create_teacher_account_screen.dart's day-toggle chips and
// admin.controller.js's createTeacher, which already use this exact shape.
// ═══════════════════════════════════════════════════════════════════════

// GET /teachers/profile/availability
// Returns the plain array of day names, e.g. ["Mon", "Wed", "Fri"].
exports.getAvailability = async (req, res) => {
  const { sub } = req.user;
  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    res.json(existing.availability || []);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch availability." });
  }
};

// POST /teachers/profile/availability
// body: { day } — one of VALID_DAYS, e.g. "Mon"
exports.addAvailabilitySlot = async (req, res) => {
  const { sub } = req.user;
  const { day } = req.body;

  if (!VALID_DAYS.includes(day)) {
    return res.status(400).json({
      error: `day must be one of: ${VALID_DAYS.join(", ")}`,
    });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.availability || [];
    if (current.includes(day)) {
      return res
        .status(409)
        .json({ error: "That day is already marked available." });
    }

    const updated = [...current, day];
    await pool.query(
      `UPDATE teacher_profiles SET availability = $1 WHERE user_id = $2`,
      [updated, sub],
    );
    res.status(201).json({
      message: "Availability added successfully.",
      availability: updated,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to add availability." });
  }
};

// DELETE /teachers/profile/availability
// body: { day }
exports.deleteAvailabilitySlot = async (req, res) => {
  const { sub } = req.user;
  const { day } = req.body;

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.availability || [];
    const updated = current.filter((d) => d !== day);

    if (updated.length === current.length) {
      return res
        .status(404)
        .json({ error: "That day was not in the availability list." });
    }

    await pool.query(
      `UPDATE teacher_profiles SET availability = $1 WHERE user_id = $2`,
      [updated, sub],
    );
    res.json({
      message: "Availability removed successfully.",
      availability: updated,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to remove availability." });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS: CREDITS PER SESSION
// teacher_profiles.credits_per_session is a real column (default 6) — a
// teacher can view/update their own rate. Session history/summary uses
// bookings.credits_cost, which is captured at booking time from whatever
// the rate was then (so past sessions keep their original price even if
// the teacher changes their rate later).
// ═══════════════════════════════════════════════════════════════════════

// GET /teachers/profile/credits
exports.getCreditsSummary = async (req, res) => {
  const { sub } = req.user;
  try {
    const { rows: profileRows } = await pool.query(
      `SELECT credits_per_session FROM teacher_profiles WHERE user_id = $1`,
      [sub],
    );
    if (!profileRows.length)
      return res.status(404).json({ error: "Teacher profile not found" });

    const { rows } = await pool.query(
      `SELECT b.id,
              b.credits_cost AS credits,
              b.scheduled_at AS date,
              (u.first_name || ' ' || u.last_name) AS "studentName"
         FROM bookings b
         JOIN users u ON u.id = b.student_id
        WHERE b.teacher_id = $1 AND b.status = 'completed'
        ORDER BY b.scheduled_at DESC`,
      [sub],
    );

    const totalCredits = rows.reduce((sum, s) => sum + (s.credits || 0), 0);

    res.json({
      creditsPerSession: profileRows[0].credits_per_session,
      totalCredits,
      totalSessions: rows.length,
      sessions: rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch credits summary." });
  }
};

// PATCH /teachers/profile/credits
// body: { creditsPerSession }
exports.updateCreditsPerSession = async (req, res) => {
  const { sub } = req.user;
  const { creditsPerSession } = req.body;

  if (!Number.isInteger(creditsPerSession) || creditsPerSession < 0) {
    return res
      .status(400)
      .json({ error: "creditsPerSession must be a non-negative integer." });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    await pool.query(
      `UPDATE teacher_profiles SET credits_per_session = $1 WHERE user_id = $2`,
      [creditsPerSession, sub],
    );
    res.json({ message: "Rate updated successfully.", creditsPerSession });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update rate." });
  }
};
