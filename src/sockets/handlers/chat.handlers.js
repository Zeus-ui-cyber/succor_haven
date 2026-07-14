// src/sockets/handlers/chat.handlers.js
//
// Live chat for the session room. Every message is persisted first
// (so REST GET /sessions/:id/chat history and the live socket feed can
// never disagree), then broadcast to the whole room — including the
// sender, so a single source of truth (the DB round-trip) drives every
// client's UI instead of the sender optimistically rendering its own
// message before the server confirms it saved.
//
// See signaling.handlers.js for the socket.data.sessionId /
// socket.user.sub read pattern; same applies here.

const pool = require("../../db/pool");
const { roomFor } = require("./signaling.handlers");

/**
 * @param {import('socket.io').Server} io
 * @param {import('socket.io').Socket} socket
 */
function registerChatHandlers(io, socket) {
  const userId = socket.user?.sub;

  socket.on("chat:send", async (payload, ack) => {
    const { sessionId } = socket.data;
    const body = (payload?.body ?? "").toString().trim();
    if (!sessionId || !body) {
      if (typeof ack === "function")
        ack({ ok: false, error: "Empty message." });
      return;
    }
    if (body.length > 2000) {
      if (typeof ack === "function") {
        ack({ ok: false, error: "Message too long (max 2000 characters)." });
      }
      return;
    }

    try {
      const { rows } = await pool.query(
        `INSERT INTO session_chat_messages (session_id, sender_id, body)
         VALUES ($1, $2, $3)
         RETURNING id, session_id, sender_id, body, created_at`,
        [sessionId, userId, body],
      );
      const message = rows[0];

      io.to(roomFor(sessionId)).emit("chat:message", message);
      if (typeof ack === "function") ack({ ok: true, message });
    } catch (err) {
      console.error("chat:send error:", err);
      if (typeof ack === "function") {
        ack({ ok: false, error: "Failed to send message." });
      }
    }
  });
}

module.exports = { registerChatHandlers };
