// src/realtime/chat.handlers.js
//
// Live session chat. Every message is persisted (session_chat_messages)
// then echoed back to the WHOLE room, sender included — the Flutter chat
// controller doesn't optimistically append its own message, it just
// waits for this same event, so there's exactly one code path for
// "a message appeared" regardless of who sent it.

const sessionService = require("../services/session.service");

function registerChatHandlers(io, socket) {
  socket.on("chat:send", async ({ body }, ack) => {
    const sessionId = socket.data.sessionId;
    if (!sessionId) return ack?.({ error: "Not in a session room." });
    const text = typeof body === "string" ? body.trim() : "";
    if (!text) return ack?.({ error: "Message body is required." });
    if (text.length > 4000) return ack?.({ error: "Message is too long." });

    try {
      const message = await sessionService.addChatMessage(
        sessionId,
        socket.user.sub,
        text,
      );
      io.to(`session:${sessionId}`).emit("chat:new", message);
      ack?.({ ok: true });
    } catch (err) {
      console.error("chat:send error:", err);
      ack?.({ error: "Failed to send message." });
    }
  });
}

module.exports = { registerChatHandlers };
