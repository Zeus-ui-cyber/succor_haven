// src/controllers/sessionRoom.controller.js
//
// REST side of the session room. The chat endpoints exist alongside the
// live socket feed (chat.handlers.js) for two reasons: (1) history needs
// a plain GET regardless of socket connection state, and (2) POST here
// is a fallback path for chat if a client's socket connection is
// momentarily down — the socket handler is still the primary path for
// live sends.
//
// Same ownership rule as sessions.controller.js: only the session's
// assigned teacher_id/student_id may read or act on it.

const sessionService = require("../services/session.service");
const sessionRoomService = require("../services/sessionRoom.service");

async function _authorizeParticipant(req, res) {
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

// ── Chat ─────────────────────────────────────────────────────────────────
async function getChat(req, res) {
  try {
    const session = await _authorizeParticipant(req, res);
    if (!session) return;
    const messages = await sessionRoomService.getChatHistory(session.id);
    return res.json(messages);
  } catch (err) {
    console.error("getChat error:", err);
    return res.status(500).json({ error: "Failed to load chat history." });
  }
}

async function postChat(req, res) {
  try {
    const session = await _authorizeParticipant(req, res);
    if (!session) return;
    const body = (req.body?.body ?? "").toString().trim();
    if (!body)
      return res.status(400).json({ error: "Message body is required." });
    if (body.length > 2000) {
      return res
        .status(400)
        .json({ error: "Message too long (max 2000 characters)." });
    }
    const message = await sessionRoomService.saveChatMessage(
      session.id,
      req.user.sub,
      body,
    );

    // Best-effort push to anyone connected live right now, so a REST
    // fallback send still shows up in real time for the other side.
    // ⚠️ ASSUMPTION: io instance is attached via `app.set('io', io)` in
    // app.js/server bootstrap — adjust if yours is exposed differently.
    const io = req.app.get("io");
    if (io) {
      const { roomFor } = require("../sockets/handlers/signaling.handlers");
      io.to(roomFor(session.id)).emit("chat:message", message);
    }

    return res.status(201).json(message);
  } catch (err) {
    console.error("postChat error:", err);
    return res.status(500).json({ error: "Failed to send message." });
  }
}

// ── Notes ────────────────────────────────────────────────────────────────
async function getNotes(req, res) {
  try {
    const session = await _authorizeParticipant(req, res);
    if (!session) return;
    const notes = await sessionRoomService.getNotes(session.id);
    return res.json(notes);
  } catch (err) {
    console.error("getNotes error:", err);
    return res.status(500).json({ error: "Failed to load notes." });
  }
}

async function patchNotes(req, res) {
  try {
    const session = await _authorizeParticipant(req, res);
    if (!session) return;
    const content = (req.body?.content ?? "").toString();
    if (content.length > 50000) {
      return res.status(400).json({ error: "Notes are too long." });
    }
    const notes = await sessionRoomService.upsertNotes(
      session.id,
      req.user.sub,
      content,
    );
    return res.json(notes);
  } catch (err) {
    console.error("patchNotes error:", err);
    return res.status(500).json({ error: "Failed to save notes." });
  }
}

// ── Files ────────────────────────────────────────────────────────────────
async function getFiles(req, res) {
  try {
    const session = await _authorizeParticipant(req, res);
    if (!session) return;
    const files = await sessionRoomService.listFiles(session.id);
    return res.json(files);
  } catch (err) {
    console.error("getFiles error:", err);
    return res.status(500).json({ error: "Failed to load files." });
  }
}

async function postFile(req, res) {
  try {
    const session = await _authorizeParticipant(req, res);
    if (!session) return;
    if (!req.file) return res.status(400).json({ error: "No file uploaded." });

    const record = await sessionRoomService.saveFileRecord({
      sessionId: session.id,
      uploaderId: req.user.sub,
      fileName: req.file.originalname,
      // Served the same way profile-pictures/modules already are, via
      // the existing `app.use("/uploads", express.static(...))`.
      filePath: `/uploads/session-files/${req.file.filename}`,
      mimeType: req.file.mimetype,
      sizeBytes: req.file.size,
    });

    const io = req.app.get("io");
    if (io) {
      const { roomFor } = require("../sockets/handlers/signaling.handlers");
      io.to(roomFor(session.id)).emit("files:new", record);
    }

    return res.status(201).json(record);
  } catch (err) {
    console.error("postFile error:", err);
    return res.status(500).json({ error: "Failed to upload file." });
  }
}

// ── End session ──────────────────────────────────────────────────────────
async function endSession(req, res) {
  try {
    const { id } = req.params;
    const { sub } = req.user;
    const session = await sessionService.getById(id);
    if (!session) return res.status(404).json({ error: "Session not found." });
    // Per spec: only the teacher ends the session (not the student).
    if (session.teacher_id !== sub) {
      return res
        .status(403)
        .json({ error: "Only the teacher can end this session." });
    }

    const updated = await sessionRoomService.endSession(session.id);

    const io = req.app.get("io");
    if (io) {
      const { roomFor } = require("../sockets/handlers/signaling.handlers");
      io.to(roomFor(session.id)).emit("session:ended", {
        sessionId: session.id,
      });
      // Force both sockets out of the room so nothing lingers after the
      // teardown — matches "disconnects both sides" from the plan.
      io.socketsLeave(roomFor(session.id));
    }

    return res.json(updated);
  } catch (err) {
    console.error("endSession error:", err);
    return res.status(500).json({ error: "Failed to end session." });
  }
}

module.exports = {
  getChat,
  postChat,
  getNotes,
  patchNotes,
  getFiles,
  postFile,
  endSession,
};
