// src/controllers/sessions.controller.js
//
// Read side of "My Sessions". Session rows themselves are only ever
// created as a side effect of appointments.controller.js/
// bookings.controller.js (see session.service.js) — there's no POST
// /sessions here on purpose.

const fs = require("fs");
const sessionService = require("../services/session.service");
const turnService = require("../services/turn.service");

// GET /sessions/mine
async function getMySessions(req, res) {
  try {
    const { sub, role } = req.user;
    const rows = await sessionService.listMine(sub, role);
    return res.json(rows);
  } catch (err) {
    console.error("getMySessions error:", err);
    return res.status(500).json({ error: "Failed to load sessions." });
  }
}

// GET /sessions/:id
async function getSessionById(req, res) {
  try {
    const { id } = req.params;
    const { sub } = req.user;
    const session = await sessionService.getById(id);
    if (!session) return res.status(404).json({ error: "Session not found." });
    if (session.teacher_id !== sub && session.student_id !== sub) {
      return res.status(403).json({ error: "Not authorized to view this session." });
    }
    return res.json(session);
  } catch (err) {
    console.error("getSessionById error:", err);
    return res.status(500).json({ error: "Failed to load session." });
  }
}

// Shared ownership check used by every room-scoped endpoint below.
// Returns the session row on success, or null after already sending an
// error response — callers just `if (!session) return;`.
async function _authorizeSession(req, res) {
  const { id } = req.params;
  const { sub } = req.user;
  const session = await sessionService.getById(id);
  if (!session) {
    res.status(404).json({ error: "Session not found." });
    return null;
  }
  if (session.teacher_id !== sub && session.student_id !== sub) {
    res.status(403).json({ error: "Not authorized for this session." });
    return null;
  }
  return session;
}

// GET /sessions/:id/turn-credentials
// Short-lived STUN/TURN ICE server config for the WebRTC peer connection
// (Phase 2). Scoped to the session's assigned teacher/student only — this
// is the "secure authentication so only the assigned teacher and student
// can join" requirement from the spec, applied at the signaling layer too.
async function getTurnCredentials(req, res) {
  try {
    const { id } = req.params;
    const { sub } = req.user;
    const session = await sessionService.getById(id);
    if (!session) return res.status(404).json({ error: "Session not found." });
    if (session.teacher_id !== sub && session.student_id !== sub) {
      return res.status(403).json({ error: "Not authorized for this session." });
    }
    const creds = turnService.issueCredentials(sub);
    return res.json(creds);
  } catch (err) {
    console.error("getTurnCredentials error:", err);
    return res.status(500).json({ error: "Failed to issue TURN credentials." });
  }
}

// PATCH /sessions/:id/end — teacher ends the meeting early or wraps it up.
// (Sessions also auto-complete on their own once duration_mins elapses,
// via session.service.js's reconcileStale() — this is the manual path.)
async function endSession(req, res) {
  try {
    const { id } = req.params;
    const { sub, role } = req.user;
    if (role !== "teacher") {
      return res.status(403).json({ error: "Only the teacher can end the session." });
    }
    const session = await sessionService.endSession(id, sub);
    if (!session) {
      return res.status(400).json({ error: "Cannot end this session." });
    }
    return res.json(session);
  } catch (err) {
    console.error("endSession error:", err);
    return res.status(500).json({ error: "Failed to end session." });
  }
}

// GET /sessions/:id/chat — full history, for opening the chat panel.
// Live delivery of new messages happens over Socket.IO
// (src/realtime/chat.handlers.js); this is just the initial load.
async function getChatHistory(req, res) {
  try {
    const session = await _authorizeSession(req, res);
    if (!session) return;
    const rows = await sessionService.listChat(session.id);
    return res.json(rows);
  } catch (err) {
    console.error("getChatHistory error:", err);
    return res.status(500).json({ error: "Failed to load chat history." });
  }
}

// GET /sessions/:id/notes — a student's own live notes for this session.
// Teacher-side "notes" are the separate appointments.teacher_notes field,
// not this table, so a teacher hitting this just gets an empty draft.
async function getMyNotes(req, res) {
  try {
    const session = await _authorizeSession(req, res);
    if (!session) return;
    const { sub, role } = req.user;
    if (role !== "student") return res.json({ content: "" });
    const notes = await sessionService.getNotes(session.id, sub);
    return res.json({ content: notes?.content ?? "" });
  } catch (err) {
    console.error("getMyNotes error:", err);
    return res.status(500).json({ error: "Failed to load notes." });
  }
}

// PATCH /sessions/:id/notes  { content }
async function saveMyNotes(req, res) {
  try {
    const session = await _authorizeSession(req, res);
    if (!session) return;
    const { sub, role } = req.user;
    if (role !== "student") {
      return res.status(403).json({ error: "Only the student can save notes." });
    }
    const { content } = req.body;
    if (typeof content !== "string") {
      return res.status(400).json({ error: "content must be a string." });
    }
    const notes = await sessionService.saveNotes(session.id, sub, content);
    return res.json(notes);
  } catch (err) {
    console.error("saveMyNotes error:", err);
    return res.status(500).json({ error: "Failed to save notes." });
  }
}

// GET /sessions/:id/files — teaching materials shared in this session.
async function getSessionFiles(req, res) {
  try {
    const session = await _authorizeSession(req, res);
    if (!session) return;
    const rows = await sessionService.listFiles(session.id);
    return res.json(rows);
  } catch (err) {
    console.error("getSessionFiles error:", err);
    return res.status(500).json({ error: "Failed to load files." });
  }
}

// POST /sessions/:id/files — teacher uploads a teaching material
// (multer-parsed req.file, same disk-storage pattern as modules/
// announcements — see routes/index.js's uploadSessionFile config).
async function uploadSessionFile(req, res) {
  try {
    const session = await _authorizeSession(req, res);
    if (!session) return;
    const { sub, role } = req.user;
    if (role !== "teacher") {
      if (req.file) fs.unlink(req.file.path, () => {});
      return res.status(403).json({ error: "Only the teacher can upload materials." });
    }
    if (!req.file) {
      return res.status(400).json({ error: "A file is required." });
    }
    const file = await sessionService.addFile(session.id, sub, {
      fileUrl: `/uploads/session-files/${req.file.filename}`,
      fileName: req.file.originalname,
      fileType: req.file.mimetype,
      fileSize: req.file.size,
    });
    return res.status(201).json(file);
  } catch (err) {
    console.error("uploadSessionFile error:", err);
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(500).json({ error: "Failed to upload file." });
  }
}

module.exports = {
  getMySessions,
  getSessionById,
  getTurnCredentials,
  endSession,
  getChatHistory,
  getMyNotes,
  saveMyNotes,
  getSessionFiles,
  uploadSessionFile,
};
