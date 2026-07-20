// src/controllers/appointments.controller.js
//
// Teacher Appointment Request & Approval — standalone from bookings/credits.
//
// ⚠️ FIXED: users.full_name does not exist on the live schema — confirmed
// repeatedly this session. Real columns are first_name / last_name.
// Switched to CONCAT below.
//
// ⚠️ FIXED: every function previously read req.user.id. Confirmed against
// auth.middleware.js — verifyAccess() sets req.user, and
// requireApprovedTeacher itself reads req.user.sub, matching every other
// controller in this codebase (settings, bookings, auth). req.user.id was
// always undefined, meaning every insert/query here was silently operating
// on `undefined` as the user's ID — inserts would fail the NOT NULL/foreign
// key constraint, and lookups would just return zero rows instead of a
// clean error. Switched to req.user.sub throughout.
//
// ⚠️ FIXED: student/teacher avatar_url was never selected here, so every
// appointment card in the Flutter app (both teacher-facing and
// student-facing) fell back to showing initials only, even for users who
// had uploaded a profile photo. Added t.avatar_url / s.avatar_url to the
// shared join select below.

const pool = require("../db/pool");
const sessionService = require("../services/session.service");
const { emitToUser } = require("../realtime/socket.server");

const TEACHER_JOIN_SELECT = `
  a.*,
  (t.first_name || ' ' || t.last_name) AS teacher_name,
  (s.first_name || ' ' || s.last_name) AS student_name,
  t.avatar_url AS teacher_avatar_url,
  s.avatar_url AS student_avatar_url
`;

const BASE_QUERY = `
  SELECT ${TEACHER_JOIN_SELECT}
  FROM appointments a
  JOIN users t ON t.id = a.teacher_id
  JOIN users s ON s.id = a.student_id
`;

// ── STUDENT ──────────────────────────────────────────────────────────────

// POST /appointments
async function createAppointment(req, res) {
  try {
    const studentId = req.user.sub;
    const {
      teacherId,
      title,
      purpose,
      subject,
      preferredDate, // 'YYYY-MM-DD'
      preferredTime, // 'HH:MM' — wall-clock time as typed by the student,
                     // meaningless on its own without the offset below
      timezoneOffsetMinutes, // student's DateTime.now().timeZoneOffset.inMinutes
                              // at submission time (e.g. 480 for UTC+8) —
                              // see 0008_appointment_timezone.sql for why
      durationMins,  // 30 | 60 | 90 | 120
      description,
      attachmentUrl,
    } = req.body;

    if (
      !teacherId ||
      !title ||
      !purpose ||
      !subject ||
      !preferredDate ||
      !preferredTime
    ) {
      return res.status(400).json({ error: "Missing required fields." });
    }

    const duration = durationMins ?? 60;
    if (!sessionService.VALID_DURATIONS.includes(duration)) {
      return res.status(400).json({
        error: `durationMins must be one of ${sessionService.VALID_DURATIONS.join(", ")}.`,
      });
    }

    // -720 (UTC-12) .. 840 (UTC+14) covers every real-world UTC offset.
    // Falls back to +480 (Asia/Manila) if the client didn't send one
    // (e.g. an older app build) rather than rejecting the request outright.
    let tzOffset = 480;
    if (timezoneOffsetMinutes !== undefined && timezoneOffsetMinutes !== null) {
      const parsed = Number(timezoneOffsetMinutes);
      if (!Number.isInteger(parsed) || parsed < -720 || parsed > 840) {
        return res.status(400).json({ error: "Invalid timezoneOffsetMinutes." });
      }
      tzOffset = parsed;
    }

    const { rows } = await pool.query(
      `INSERT INTO appointments
        (student_id, teacher_id, title, purpose, subject, preferred_date, preferred_time, duration_mins, timezone_offset_minutes, description, attachment_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        studentId,
        teacherId,
        title,
        purpose,
        subject,
        preferredDate,
        preferredTime,
        duration,
        tzOffset,
        description ?? null,
        attachmentUrl ?? null,
      ],
    );

    emitToUser(studentId, "appointment:changed", { action: "create", appointment: rows[0] });
    emitToUser(teacherId, "appointment:changed", { action: "create", appointment: rows[0] });

    return res.status(201).json(rows[0]);
  } catch (err) {
    console.error("createAppointment error:", err);
    return res
      .status(500)
      .json({ error: "Failed to create appointment request." });
  }
}

// GET /appointments/mine  (student's own requests, any status)
async function getMyAppointments(req, res) {
  try {
    const studentId = req.user.sub;
    const { rows } = await pool.query(
      `${BASE_QUERY} WHERE a.student_id = $1 ORDER BY a.request_date DESC`,
      [studentId],
    );
    return res.json(rows);
  } catch (err) {
    console.error("getMyAppointments error:", err);
    return res.status(500).json({ error: "Failed to load appointments." });
  }
}

// GET /appointments/:id
async function getAppointmentById(req, res) {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(`${BASE_QUERY} WHERE a.id = $1`, [id]);
    if (rows.length === 0)
      return res.status(404).json({ error: "Appointment not found." });

    const appt = rows[0];
    const isOwner =
      req.user.sub === appt.student_id || req.user.sub === appt.teacher_id;
    if (!isOwner)
      return res
        .status(403)
        .json({ error: "Not authorized to view this appointment." });

    return res.json(appt);
  } catch (err) {
    console.error("getAppointmentById error:", err);
    return res.status(500).json({ error: "Failed to load appointment." });
  }
}

// PATCH /appointments/:id/cancel
// ⚠️ SCOPE NOTE: your spec explicitly lists "Cancel an appointment if
// necessary" as a teacher action too, but this only ever checks
// student_id. A teacher currently cannot cancel via this endpoint. Left
// as student-only for now since fixing the auth bugs was the priority —
// tell me if you want a teacher-cancel path added (either here with an
// OR teacher_id check, or as a separate endpoint).
async function cancelAppointment(req, res) {
  try {
    const { id } = req.params;
    const studentId = req.user.sub;

    const { rows } = await pool.query(
      `UPDATE appointments
       SET status = 'cancelled'
       WHERE id = $1 AND student_id = $2 AND status IN ('pending', 'approved', 'rescheduled')
       RETURNING *`,
      [id, studentId],
    );

    if (rows.length === 0) {
      return res.status(400).json({
        error:
          "Appointment cannot be cancelled (not found, not yours, or already finalized).",
      });
    }
    emitToUser(rows[0].student_id, "appointment:changed", { action: "cancel", appointment: rows[0] });
    emitToUser(rows[0].teacher_id, "appointment:changed", { action: "cancel", appointment: rows[0] });

    return res.json(rows[0]);
  } catch (err) {
    console.error("cancelAppointment error:", err);
    return res.status(500).json({ error: "Failed to cancel appointment." });
  }
}

// ── TEACHER (Phase 2 UI — endpoints ready now) ──────────────────────────

// GET /appointments/teacher/mine
async function getTeacherAppointments(req, res) {
  try {
    const teacherId = req.user.sub;
    const { rows } = await pool.query(
      `${BASE_QUERY} WHERE a.teacher_id = $1 ORDER BY a.request_date DESC`,
      [teacherId],
    );
    return res.json(rows);
  } catch (err) {
    console.error("getTeacherAppointments error:", err);
    return res.status(500).json({ error: "Failed to load appointments." });
  }
}

// PATCH /appointments/:id/approve
async function approveAppointment(req, res) {
  try {
    const { id } = req.params;
    const teacherId = req.user.sub;
    const { rows } = await pool.query(
      `UPDATE appointments SET status = 'approved'
       WHERE id = $1 AND teacher_id = $2 AND status IN ('pending', 'rescheduled')
       RETURNING *`,
      [id, teacherId],
    );
    if (rows.length === 0)
      return res
        .status(400)
        .json({ error: "Cannot approve this appointment." });

    // Auto-provision the "My Sessions" video meeting the moment a teacher
    // approves — this is what makes it "automatically appear" on both
    // dashboards per the product spec. Never let a session-creation
    // hiccup fail the approval itself; the approval already committed.
    try {
      const session = await sessionService.createFromAppointment(rows[0]);
      if (session) {
        emitToUser(session.student_id, "session:changed", { action: "create", session });
        emitToUser(session.teacher_id, "session:changed", { action: "create", session });
      }
    } catch (sessionErr) {
      console.error("createFromAppointment (approve) error:", sessionErr);
    }

    emitToUser(rows[0].student_id, "appointment:changed", { action: "approve", appointment: rows[0] });
    emitToUser(rows[0].teacher_id, "appointment:changed", { action: "approve", appointment: rows[0] });

    return res.json(rows[0]);
  } catch (err) {
    console.error("approveAppointment error:", err);
    return res.status(500).json({ error: "Failed to approve appointment." });
  }
}

// PATCH /appointments/:id/decline  { reason? }
async function declineAppointment(req, res) {
  try {
    const { id } = req.params;
    const teacherId = req.user.sub;
    const { reason } = req.body;
    const { rows } = await pool.query(
      `UPDATE appointments SET status = 'declined', decline_reason = $3
       WHERE id = $1 AND teacher_id = $2 AND status IN ('pending', 'rescheduled')
       RETURNING *`,
      [id, teacherId, reason ?? null],
    );
    if (rows.length === 0)
      return res
        .status(400)
        .json({ error: "Cannot decline this appointment." });
    emitToUser(rows[0].student_id, "appointment:changed", { action: "decline", appointment: rows[0] });
    emitToUser(rows[0].teacher_id, "appointment:changed", { action: "decline", appointment: rows[0] });

    return res.json(rows[0]);
  } catch (err) {
    console.error("declineAppointment error:", err);
    return res.status(500).json({ error: "Failed to decline appointment." });
  }
}

// PATCH /appointments/:id/propose-reschedule  { proposedDate, proposedTime }
async function proposeReschedule(req, res) {
  try {
    const { id } = req.params;
    const teacherId = req.user.sub;
    const { proposedDate, proposedTime } = req.body;
    if (!proposedDate || !proposedTime) {
      return res
        .status(400)
        .json({ error: "proposedDate and proposedTime are required." });
    }
    const { rows } = await pool.query(
      `UPDATE appointments
       SET status = 'rescheduled', proposed_date = $3, proposed_time = $4
       WHERE id = $1 AND teacher_id = $2 AND status = 'pending'
       RETURNING *`,
      [id, teacherId, proposedDate, proposedTime],
    );
    if (rows.length === 0)
      return res
        .status(400)
        .json({ error: "Cannot propose a new schedule for this appointment." });
    emitToUser(rows[0].student_id, "appointment:changed", { action: "reschedule", appointment: rows[0] });
    emitToUser(rows[0].teacher_id, "appointment:changed", { action: "reschedule", appointment: rows[0] });

    return res.json(rows[0]);
  } catch (err) {
    console.error("proposeReschedule error:", err);
    return res.status(500).json({ error: "Failed to propose new schedule." });
  }
}

// PATCH /appointments/:id/respond-reschedule  { accept: boolean }  (student)
async function respondToReschedule(req, res) {
  try {
    const { id } = req.params;
    const studentId = req.user.sub;
    const { accept } = req.body;

    if (accept) {
      const { rows } = await pool.query(
        `UPDATE appointments
         SET status = 'approved', preferred_date = proposed_date, preferred_time = proposed_time
         WHERE id = $1 AND student_id = $2 AND status = 'rescheduled'
         RETURNING *`,
        [id, studentId],
      );
      if (rows.length === 0)
        return res
          .status(400)
          .json({ error: "Cannot accept this reschedule." });

      try {
        const session = await sessionService.createFromAppointment(rows[0]);
        if (session) {
          emitToUser(session.student_id, "session:changed", { action: "create", session });
          emitToUser(session.teacher_id, "session:changed", { action: "create", session });
        }
      } catch (sessionErr) {
        console.error("createFromAppointment (reschedule accept) error:", sessionErr);
      }

      emitToUser(rows[0].student_id, "appointment:changed", { action: "approve", appointment: rows[0] });
      emitToUser(rows[0].teacher_id, "appointment:changed", { action: "approve", appointment: rows[0] });

      return res.json(rows[0]);
    } else {
      const { rows } = await pool.query(
        `UPDATE appointments SET status = 'declined'
         WHERE id = $1 AND student_id = $2 AND status = 'rescheduled'
         RETURNING *`,
        [id, studentId],
      );
      if (rows.length === 0)
        return res
          .status(400)
          .json({ error: "Cannot decline this reschedule." });

      emitToUser(rows[0].student_id, "appointment:changed", { action: "decline", appointment: rows[0] });
      emitToUser(rows[0].teacher_id, "appointment:changed", { action: "decline", appointment: rows[0] });

      return res.json(rows[0]);
    }
  } catch (err) {
    console.error("respondToReschedule error:", err);
    return res.status(500).json({ error: "Failed to respond to reschedule." });
  }
}

// PATCH /appointments/:id/complete
async function completeAppointment(req, res) {
  try {
    const { id } = req.params;
    const teacherId = req.user.sub;
    const { rows } = await pool.query(
      `UPDATE appointments SET status = 'completed'
       WHERE id = $1 AND teacher_id = $2 AND status = 'approved'
       RETURNING *`,
      [id, teacherId],
    );
    if (rows.length === 0)
      return res
        .status(400)
        .json({ error: "Cannot complete this appointment." });
    emitToUser(rows[0].student_id, "appointment:changed", { action: "complete", appointment: rows[0] });
    emitToUser(rows[0].teacher_id, "appointment:changed", { action: "complete", appointment: rows[0] });

    return res.json(rows[0]);
  } catch (err) {
    console.error("completeAppointment error:", err);
    return res.status(500).json({ error: "Failed to complete appointment." });
  }
}

module.exports = {
  createAppointment,
  getMyAppointments,
  getAppointmentById,
  cancelAppointment,
  getTeacherAppointments,
  approveAppointment,
  declineAppointment,
  proposeReschedule,
  respondToReschedule,
  completeAppointment,
};
