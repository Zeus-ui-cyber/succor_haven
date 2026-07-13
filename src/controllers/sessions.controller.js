// src/controllers/sessions.controller.js
//
// Read side of "My Sessions". Session rows themselves are only ever
// created as a side effect of appointments.controller.js/
// bookings.controller.js (see session.service.js) — there's no POST
// /sessions here on purpose.

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

module.exports = { getMySessions, getSessionById, getTurnCredentials };
