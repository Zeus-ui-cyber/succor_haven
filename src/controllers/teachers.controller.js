// src/controllers/teachers.controller.js
const crypto = require("crypto");
const pool = require("../db/pool");

const MAX_BIO_LENGTH = 500;

// slot_time comes back from pg as "HH:MM:SS" — accept either that or "HH:MM"
// on the way in, and just read the first two colon-separated parts.
function timeToMinutes(t) {
  const [h, m] = t.split(":").map(Number);
  return h * 60 + m;
}

function validateSlotShape({ slotDate, slotTime, durationMins }) {
  if (!slotDate || !/^\d{4}-\d{2}-\d{2}$/.test(slotDate)) {
    return "slotDate must be in YYYY-MM-DD format.";
  }
  if (!slotTime || !/^\d{2}:\d{2}(:\d{2})?$/.test(slotTime)) {
    return "slotTime must be in HH:MM format.";
  }
  if (!Number.isInteger(durationMins) || durationMins <= 0) {
    return "durationMins must be a positive integer.";
  }
  return null;
}

// existingSlots: rows from teacher_availability (slot_date, slot_time, duration_mins)
function findOverlap(existingSlots, { slotDate, slotTime, durationMins }, excludeId) {
  const newStart = timeToMinutes(slotTime);
  const newEnd = newStart + durationMins;

  return existingSlots.find((slot) => {
    if (slot.id === excludeId) return false;
    // slot_date from pg is a Date object or ISO string depending on driver
    // config — compare as strings sliced to YYYY-MM-DD to avoid TZ drift.
    const slotDateStr =
      slot.slot_date instanceof Date
        ? slot.slot_date.toISOString().slice(0, 10)
        : String(slot.slot_date).slice(0, 10);
    if (slotDateStr !== slotDate) return false;

    const existingStart = timeToMinutes(slot.slot_time);
    const existingEnd = existingStart + slot.duration_mins;
    return newStart < existingEnd && existingStart < newEnd;
  });
}

async function getOwnProfileRow(userId) {
  const { rows } = await pool.query(
    `SELECT * FROM teacher_profiles WHERE user_id = $1`,
    [userId],
  );
  return rows[0] || null;
}

// ── GET /teachers — browse approved teachers ──────────────────────────────────
// ⚠️ FIXED: teacher_profiles has no `availability` column (confirmed via
// pgAdmin — it only has bio, subjects, avatar_url, is_approved, rating,
// total_sessions). Availability lives in a separate `teacher_availability`
// table (id, teacher_id, slot_date, slot_time, duration_mins, is_booked).
// Selecting tp.availability here was throwing "column does not exist" and
// breaking the student dashboard's teacher list. Dropped from this query —
// if the teacher card UI needs availability data, it should be fetched
// separately per teacher (or joined in once we settle the availability
// controller conventions), not pulled from teacher_profiles.
//
// ⚠️ FIXED (audit, round 3): `u.full_name` also does not exist — live
// error was "column u.full_name does not exist". The real columns are
// u.first_name / u.last_name (same ones studentsAdmin.controller.js has
// been querying successfully all along). Concatenating them in SQL and
// aliasing back to `full_name` so the JSON response shape — and therefore
// the Flutter side — doesn't need to change.
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
      `SELECT u.id, (u.first_name || ' ' || u.last_name) AS full_name, u.email,
              tp.bio, tp.subjects, tp.avatar_url,
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
// ⚠️ FIXED: same tp.availability removal as browse() above, plus the same
// u.full_name → first_name/last_name concatenation fix.
exports.getOne = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.id, (u.first_name || ' ' || u.last_name) AS full_name, u.email, u.created_at,
              tp.bio, tp.subjects, tp.avatar_url,
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

// ── PATCH /teachers/profile — full-object update (kept as-is, unused by the
//    new granular Settings screens below, but left for any other caller) ──────
exports.updateProfile = async (req, res) => {
  const { sub } = req.user;
  const { bio, subjects, availability, avatarUrl } = req.body;
  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const { rows } = await pool.query(
      `UPDATE teacher_profiles
       SET bio = $1, subjects = $2, avatar_url = $3,
           updated_at = now()
       WHERE user_id = $4
       RETURNING *`,
      [
        bio ?? existing.bio,
        subjects ?? existing.subjects,
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
    return res.status(400).json({ error: `Bio must be ${MAX_BIO_LENGTH} characters or fewer.` });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    await pool.query(
      `UPDATE teacher_profiles SET bio = $1, updated_at = now() WHERE user_id = $2`,
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
      return res.status(409).json({ error: "This subject has already been added." });
    }

    const updated = [...current, trimmed];
    await pool.query(
      `UPDATE teacher_profiles SET subjects = $1, updated_at = now() WHERE user_id = $2`,
      [updated, sub],
    );
    res.status(201).json({ message: "Subject added successfully.", subjects: updated });
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
    return res.status(400).json({ error: "oldSubject and newSubject are required." });
  }

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.subjects || [];
    const index = current.findIndex((s) => s.toLowerCase() === oldSubject.trim().toLowerCase());
    if (index === -1) {
      return res.status(404).json({ error: "Subject not found." });
    }

    const updated = [...current];
    updated[index] = newSubject.trim();

    await pool.query(
      `UPDATE teacher_profiles SET subjects = $1, updated_at = now() WHERE user_id = $2`,
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
    const updated = current.filter((s) => s.toLowerCase() !== subject.trim().toLowerCase());

    if (updated.length === current.length) {
      return res.status(404).json({ error: "Subject not found." });
    }

    await pool.query(
      `UPDATE teacher_profiles SET subjects = $1, updated_at = now() WHERE user_id = $2`,
      [updated, sub],
    );
    res.json({ message: "Subject removed successfully.", subjects: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to remove subject." });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS: AVAILABILITY (granular — used by Set Availability screen)
//
// ⚠️ NOT YET RECONCILED WITH SCHEMA: these functions still read/write a
// `teacher_profiles.availability` JSONB column that does NOT exist in the
// real database. The real availability data lives in a separate
// `teacher_availability` table (id, teacher_id, slot_date, slot_time,
// duration_mins, is_booked) — a completely different shape (date+time
// slots vs. day-of-week + startTime/endTime JSONB blob).
//
// These four endpoints (getAvailability / addAvailabilitySlot /
// updateAvailabilitySlot / deleteAvailabilitySlot) will throw "column
// availability does not exist" the moment they're called, same as browse()
// did. They're left as-is for now since they weren't the reported bug —
// but they need a rewrite against `teacher_availability` before the
// teacher-side "Set Availability" screen will work. Share
// availability.controller.js (used by the student booking flow) and I'll
// rewrite these to match the same conventions.
//
// Also note: these functions call validateSlotShape({ day, startTime,
// endTime }) and findOverlap(..., { day, startTime, endTime }, ...), but
// both helper functions are defined above to expect { slotDate, slotTime,
// durationMins } instead — a second, separate mismatch from the schema
// issue. This will need to be reconciled in the same rewrite.
// ═══════════════════════════════════════════════════════════════════════

// GET /teachers/profile/availability
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
// body: { day, startTime, endTime }
exports.addAvailabilitySlot = async (req, res) => {
  const { sub } = req.user;
  const { day, startTime, endTime } = req.body;

  const validationError = validateSlotShape({ day, startTime, endTime });
  if (validationError) return res.status(400).json({ error: validationError });

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.availability || [];
    const conflict = findOverlap(current, { day, startTime, endTime }, null);
    if (conflict) {
      return res.status(409).json({
        error: `This overlaps with an existing slot (${conflict.startTime}-${conflict.endTime}) on that day.`,
      });
    }

    const newSlot = { id: crypto.randomUUID(), day, startTime, endTime };
    const updated = [...current, newSlot];

    await pool.query(
      `UPDATE teacher_profiles SET availability = $1, updated_at = now() WHERE user_id = $2`,
      [JSON.stringify(updated), sub],
    );
    res.status(201).json({ message: "Availability added successfully.", slot: newSlot });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to add availability." });
  }
};

// PATCH /teachers/profile/availability/:id
// body: { day, startTime, endTime }
exports.updateAvailabilitySlot = async (req, res) => {
  const { sub } = req.user;
  const { id } = req.params;
  const { day, startTime, endTime } = req.body;

  const validationError = validateSlotShape({ day, startTime, endTime });
  if (validationError) return res.status(400).json({ error: validationError });

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.availability || [];
    const index = current.findIndex((s) => s.id === id);
    if (index === -1) {
      return res.status(404).json({ error: "Availability slot not found." });
    }

    const conflict = findOverlap(current, { day, startTime, endTime }, id);
    if (conflict) {
      return res.status(409).json({
        error: `This overlaps with an existing slot (${conflict.startTime}-${conflict.endTime}) on that day.`,
      });
    }

    const updated = [...current];
    updated[index] = { id, day, startTime, endTime };

    await pool.query(
      `UPDATE teacher_profiles SET availability = $1, updated_at = now() WHERE user_id = $2`,
      [JSON.stringify(updated), sub],
    );
    res.json({ message: "Availability updated successfully.", slot: updated[index] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update availability." });
  }
};

// DELETE /teachers/profile/availability/:id
exports.deleteAvailabilitySlot = async (req, res) => {
  const { sub } = req.user;
  const { id } = req.params;

  try {
    const existing = await getOwnProfileRow(sub);
    if (!existing)
      return res.status(404).json({ error: "Teacher profile not found" });

    const current = existing.availability || [];
    const updated = current.filter((s) => s.id !== id);

    if (updated.length === current.length) {
      return res.status(404).json({ error: "Availability slot not found." });
    }

    await pool.query(
      `UPDATE teacher_profiles SET availability = $1, updated_at = now() WHERE user_id = $2`,
      [JSON.stringify(updated), sub],
    );
    res.json({ message: "Availability slot removed successfully." });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to remove availability." });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS: CREDITS PER SESSION (read-only — used by Credits Per Session
// screen). No per-teacher rate exists anymore; session cost is set via the
// `pricing` table at booking time and already reflected in
// bookings.credits_cost, so this is purely a summary of completed sessions.
// ═══════════════════════════════════════════════════════════════════════

// GET /teachers/profile/credits
// ⚠️ FIXED (audit, round 3): u.full_name → first_name/last_name
// concatenation, same as browse()/getOne() above.
exports.getCreditsSummary = async (req, res) => {
  const { sub } = req.user;
  try {
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
      totalCredits,
      totalSessions: rows.length,
      sessions: rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch credits summary." });
  }
};