// src/services/sessionRoom.service.js
//
// Query layer for the session room's chat/notes/files, following the
// same shape as session.service.js (plain functions, no class). Kept
// separate from that file since it's a distinct concern (room contents
// vs. session lifecycle/listing).
//
// Confirmed: src/db/pool.js exports the pg Pool instance directly, so
// pool.query(text, params) returns { rows }, same shape session.service.js
// already relies on.

const pool = require("../db/pool");

// ── Chat ─────────────────────────────────────────────────────────────────
async function getChatHistory(sessionId) {
  const { rows } = await pool.query(
    `SELECT id, session_id, sender_id, body, created_at
     FROM session_chat_messages
     WHERE session_id = $1
     ORDER BY created_at ASC`,
    [sessionId],
  );
  return rows;
}

async function saveChatMessage(sessionId, senderId, body) {
  const { rows } = await pool.query(
    `INSERT INTO session_chat_messages (session_id, sender_id, body)
     VALUES ($1, $2, $3)
     RETURNING id, session_id, sender_id, body, created_at`,
    [sessionId, senderId, body],
  );
  return rows[0];
}

// ── Notes ────────────────────────────────────────────────────────────────
async function getNotes(sessionId) {
  const { rows } = await pool.query(
    `SELECT session_id, content, updated_by, updated_at
     FROM session_notes
     WHERE session_id = $1`,
    [sessionId],
  );
  // No row yet just means nobody's typed anything — return an empty
  // shell rather than null so the client doesn't need a special case.
  return (
    rows[0] ?? {
      session_id: sessionId,
      content: "",
      updated_by: null,
      updated_at: null,
    }
  );
}

async function upsertNotes(sessionId, userId, content) {
  const { rows } = await pool.query(
    `INSERT INTO session_notes (session_id, content, updated_by, updated_at)
     VALUES ($1, $2, $3, now())
     ON CONFLICT (session_id)
     DO UPDATE SET content = EXCLUDED.content,
                   updated_by = EXCLUDED.updated_by,
                   updated_at = now()
     RETURNING session_id, content, updated_by, updated_at`,
    [sessionId, content, userId],
  );
  return rows[0];
}

// ── Files ────────────────────────────────────────────────────────────────
async function listFiles(sessionId) {
  const { rows } = await pool.query(
    `SELECT id, session_id, uploader_id, file_name, file_path, mime_type, size_bytes, created_at
     FROM session_files
     WHERE session_id = $1
     ORDER BY created_at DESC`,
    [sessionId],
  );
  return rows;
}

async function saveFileRecord({
  sessionId,
  uploaderId,
  fileName,
  filePath,
  mimeType,
  sizeBytes,
}) {
  const { rows } = await pool.query(
    `INSERT INTO session_files (session_id, uploader_id, file_name, file_path, mime_type, size_bytes)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, session_id, uploader_id, file_name, file_path, mime_type, size_bytes, created_at`,
    [sessionId, uploaderId, fileName, filePath, mimeType, sizeBytes],
  );
  return rows[0];
}

// ── End session ──────────────────────────────────────────────────────────
async function endSession(sessionId) {
  const { rows } = await pool.query(
    `UPDATE sessions
     SET status = 'completed', ended_at = now()
     WHERE id = $1
     RETURNING id, status, ended_at`,
    [sessionId],
  );
  return rows[0] ?? null;
}

module.exports = {
  getChatHistory,
  saveChatMessage,
  getNotes,
  upsertNotes,
  listFiles,
  saveFileRecord,
  endSession,
};
