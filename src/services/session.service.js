// src/services/session.service.js
//
// "My Sessions" video meetings. A session is the meeting-instance layer
// created automatically the moment a `bookings` row is confirmed (paid,
// instant booking) or an `appointments` row is approved (request/approval
// workflow) — see the callers of createFromBooking/createFromAppointment
// in bookings.controller.js and appointments.controller.js.
//
// listMine() also surfaces appointment requests that haven't become a
// session yet (pending / declined / rescheduled) so the Flutter "My
// Sessions" list can show the "Pending Approval" card state the product
// spec asks for, without the caller needing to query two endpoints.

const pool = require("../db/pool");

const VALID_DURATIONS = [30, 60, 90, 120];

const SESSION_JOIN_SELECT = `
  s.*,
  (t.first_name || ' ' || t.last_name) AS teacher_name,
  (st.first_name || ' ' || st.last_name) AS student_name,
  t.avatar_url AS teacher_avatar_url,
  st.avatar_url AS student_avatar_url
`;

// Read-time reconciliation: with no scheduler running yet (that's Phase 5
// — see session.service.js's TODO below), a session that was never
// started can sit at status='upcoming' forever once its window has
// passed. Sweeping this on every read keeps the list/detail views honest
// in the meantime; the future cron job can call this same query on an
// interval instead of relying on a request happening to come in.
// TODO(phase 5): replace/augment with node-cron scheduler.service.js so
// stale sessions flip even with no active readers, and so reminder
// notifications can fire off the same pass.
async function reconcileStale() {
  await pool.query(
    `UPDATE sessions SET status = 'missed'
     WHERE status = 'upcoming'
       AND scheduled_at + (duration_mins || ' minutes')::interval < now()`,
  );
  await pool.query(
    `UPDATE sessions SET status = 'completed', ended_at = COALESCE(ended_at, now())
     WHERE status = 'in_progress'
       AND scheduled_at + (duration_mins || ' minutes')::interval < now()`,
  );
}

// Called after appointments.controller.js transitions an appointment to
// 'approved' (either via approveAppointment or a student accepting a
// proposed reschedule). ON CONFLICT DO NOTHING makes this safe to call
// from both of those code paths without double-creating a session.
// ⚠️ Combining preferred_date + preferred_time with plain `::date + ::time`
// produces a timezone-naive timestamp. Casting that straight into
// scheduled_at (TIMESTAMPTZ) would make Postgres silently assume the
// database's own ambient session timezone (UTC on Neon) instead of the
// student's real one — a student typing "9:30" could end up with a
// session that actually unlocks at a totally different real-world clock
// time. Fix: subtract the student's captured UTC offset first, then
// explicitly interpret the result `AT TIME ZONE 'UTC'` — that's immune to
// whatever the database's ambient timezone happens to be, unlike an
// implicit cast. See 0008_appointment_timezone.sql.
async function createFromAppointment(appointment) {
  const { rows } = await pool.query(
    `INSERT INTO sessions
       (appointment_id, teacher_id, student_id, subject, title, scheduled_at, duration_mins)
     VALUES (
       $1, $2, $3, $4, $5,
       (($6::date + $7::time) - ($8 * interval '1 minute')) AT TIME ZONE 'UTC',
       $9
     )
     ON CONFLICT (appointment_id) DO NOTHING
     RETURNING *`,
    [
      appointment.id,
      appointment.teacher_id,
      appointment.student_id,
      appointment.subject,
      appointment.title,
      appointment.preferred_date,
      appointment.preferred_time,
      appointment.timezone_offset_minutes ?? 480,
      appointment.duration_mins ?? 60,
    ],
  );
  return rows[0] ?? null;
}

// Called after bookings.controller.js inserts a booking (bookings go
// straight to status='confirmed' on creation — there's no separate
// confirm step to hook, unlike appointments). bookings has no `subject`
// column, so it falls back to a generic title; teacher_profiles.subjects
// could be joined in later if a more specific label is wanted.
async function createFromBooking(booking) {
  const { rows } = await pool.query(
    `INSERT INTO sessions
       (booking_id, teacher_id, student_id, subject, title, scheduled_at, duration_mins)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (booking_id) DO NOTHING
     RETURNING *`,
    [
      booking.id,
      booking.teacher_id,
      booking.student_id,
      "Tutoring Session",
      null,
      booking.scheduled_at,
      booking.duration_mins ?? 30,
    ],
  );
  return rows[0] ?? null;
}

// Unified feed for the Flutter "My Sessions" tab: real sessions (from
// either origin) plus not-yet-approved appointment requests, newest
// first within each group. Each row carries `kind` so the client can
// tell a real, joinable session apart from a pending/declined request.
async function listMine(userId, role) {
  await reconcileStale();
  const sessionField = role === "teacher" ? "s.teacher_id" : "s.student_id";
  const { rows: sessionRows } = await pool.query(
    `SELECT ${SESSION_JOIN_SELECT}
     FROM sessions s
     JOIN users t  ON t.id = s.teacher_id
     JOIN users st ON st.id = s.student_id
     WHERE ${sessionField} = $1
     ORDER BY s.scheduled_at DESC`,
    [userId],
  );

  const apptField = role === "teacher" ? "a.teacher_id" : "a.student_id";
  const { rows: pendingRows } = await pool.query(
    `SELECT a.id, a.teacher_id, a.student_id, a.subject, a.title,
            a.preferred_date, a.preferred_time,
            a.duration_mins, a.status,
            (t.first_name || ' ' || t.last_name) AS teacher_name,
            (s.first_name || ' ' || s.last_name) AS student_name,
            t.avatar_url AS teacher_avatar_url,
            s.avatar_url AS student_avatar_url
     FROM appointments a
     JOIN users t ON t.id = a.teacher_id
     JOIN users s ON s.id = a.student_id
     WHERE ${apptField} = $1
       AND a.status IN ('pending', 'declined', 'rescheduled')
       AND NOT EXISTS (SELECT 1 FROM sessions x WHERE x.appointment_id = a.id)
     ORDER BY a.preferred_date DESC, a.preferred_time DESC`,
    [userId],
  );

  const sessions = sessionRows.map((r) => ({ kind: "session", ...r }));
  const pending = pendingRows.map((r) => ({
    kind: "pending_appointment",
    id: r.id,
    teacher_id: r.teacher_id,
    student_id: r.student_id,
    subject: r.subject,
    title: r.title,
    scheduled_at: null,
    preferred_date: r.preferred_date,
    preferred_time: r.preferred_time,
    duration_mins: r.duration_mins,
    status: r.status,
    teacher_name: r.teacher_name,
    student_name: r.student_name,
    teacher_avatar_url: r.teacher_avatar_url,
    student_avatar_url: r.student_avatar_url,
  }));

  return [...sessions, ...pending];
}

async function getById(sessionId) {
  await reconcileStale();
  const { rows } = await pool.query(
    `SELECT ${SESSION_JOIN_SELECT}
     FROM sessions s
     JOIN users t  ON t.id = s.teacher_id
     JOIN users st ON st.id = s.student_id
     WHERE s.id = $1`,
    [sessionId],
  );
  return rows[0] ?? null;
}

// ── Room lifecycle ──────────────────────────────────────────────────────
// Called from socket.server.js's 'session:join' handler the first time
// either participant actually joins the room — this is what flips the
// "Upcoming" badge to "In Progress" and starts the in-call timer. Scoped
// to status='upcoming' so it only ever fires once per session.
async function markInProgress(sessionId) {
  const { rows } = await pool.query(
    `UPDATE sessions SET status = 'in_progress', started_at = COALESCE(started_at, now())
     WHERE id = $1 AND status = 'upcoming'
     RETURNING *`,
    [sessionId],
  );
  return rows[0] ?? null;
}

// Teacher-only, per the spec's "Session Completed" / End Session button.
// Deliberately allowed from 'upcoming' too (not just 'in_progress') so a
// teacher can end a session even if the student never actually joined.
async function endSession(sessionId, teacherId) {
  const { rows } = await pool.query(
    `UPDATE sessions
     SET status = 'completed', ended_at = now()
     WHERE id = $1 AND teacher_id = $2 AND status IN ('upcoming', 'in_progress')
     RETURNING *`,
    [sessionId, teacherId],
  );
  return rows[0] ?? null;
}

// ── Attendance ───────────────────────────────────────────────────────────
// One row per join (a reconnect creates a new row rather than reusing the
// old one) — session_card.dart/end-of-session summary sums these for
// total duration + attendance %, per the spec's "Automatically record
// Join Time / Leave Time / Duration" requirement.
async function recordJoin(sessionId, userId) {
  const { rows } = await pool.query(
    `INSERT INTO session_attendance (session_id, user_id, joined_at)
     VALUES ($1, $2, now())
     RETURNING id`,
    [sessionId, userId],
  );
  return rows[0].id;
}

async function recordLeave(attendanceId) {
  await pool.query(
    `UPDATE session_attendance
     SET left_at = now(),
         duration_secs = EXTRACT(EPOCH FROM (now() - joined_at))::int
     WHERE id = $1`,
    [attendanceId],
  );
}

// ── Live notes (student-only — see 0009_session_room.sql) ────────────────
async function getNotes(sessionId, studentId) {
  const { rows } = await pool.query(
    `SELECT * FROM session_notes WHERE session_id = $1 AND student_id = $2`,
    [sessionId, studentId],
  );
  return rows[0] ?? null;
}

async function saveNotes(sessionId, studentId, content) {
  const { rows } = await pool.query(
    `INSERT INTO session_notes (session_id, student_id, content)
     VALUES ($1, $2, $3)
     ON CONFLICT (session_id, student_id)
     DO UPDATE SET content = EXCLUDED.content, updated_at = now()
     RETURNING *`,
    [sessionId, studentId, content],
  );
  return rows[0];
}

// ── Chat ─────────────────────────────────────────────────────────────────
const CHAT_JOIN_SELECT = `
  c.*,
  (u.first_name || ' ' || u.last_name) AS sender_name,
  u.avatar_url AS sender_avatar_url,
  u.role AS sender_role
`;

async function listChat(sessionId) {
  const { rows } = await pool.query(
    `SELECT ${CHAT_JOIN_SELECT}
     FROM session_chat_messages c
     JOIN users u ON u.id = c.sender_id
     WHERE c.session_id = $1
     ORDER BY c.created_at ASC`,
    [sessionId],
  );
  return rows;
}

// Called from chat.handlers.js on every 'chat:send' socket event — persists
// then returns the joined row so it can be broadcast to the room as-is.
async function addChatMessage(sessionId, senderId, body) {
  const { rows } = await pool.query(
    `INSERT INTO session_chat_messages (session_id, sender_id, body)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [sessionId, senderId, body],
  );
  const { rows: joined } = await pool.query(
    `SELECT ${CHAT_JOIN_SELECT}
     FROM session_chat_messages c
     JOIN users u ON u.id = c.sender_id
     WHERE c.id = $1`,
    [rows[0].id],
  );
  return joined[0];
}

// ── Teaching materials ────────────────────────────────────────────────────
async function listFiles(sessionId) {
  const { rows } = await pool.query(
    `SELECT f.*, (u.first_name || ' ' || u.last_name) AS uploaded_by_name
     FROM session_files f
     JOIN users u ON u.id = f.uploaded_by
     WHERE f.session_id = $1
     ORDER BY f.created_at DESC`,
    [sessionId],
  );
  return rows;
}

async function addFile(sessionId, uploadedBy, { fileUrl, fileName, fileType, fileSize }) {
  const { rows } = await pool.query(
    `INSERT INTO session_files (session_id, uploaded_by, file_url, file_name, file_type, file_size)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [sessionId, uploadedBy, fileUrl, fileName, fileType ?? null, fileSize ?? null],
  );
  return rows[0];
}

module.exports = {
  VALID_DURATIONS,
  createFromAppointment,
  createFromBooking,
  listMine,
  getById,
  markInProgress,
  endSession,
  recordJoin,
  recordLeave,
  getNotes,
  saveNotes,
  listChat,
  addChatMessage,
  listFiles,
  addFile,
};
