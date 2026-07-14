// src/sockets/handlers/presence.handlers.js
//
// Lightweight, ephemeral presence signals — raise hand and emoji
// reactions. No persistence per the plan; these are UI-only broadcasts.

const { roomFor } = require("./signaling.handlers");

const ALLOWED_REACTIONS = new Set(["👍", "👏", "❤️", "😂", "🎉", "🤔"]);

/**
 * @param {import('socket.io').Server} io
 * @param {import('socket.io').Socket} socket
 */
function registerPresenceHandlers(io, socket) {
  const userId = socket.user?.sub;

  // `raised` is a boolean the client toggles — keeping it explicit
  // rather than treating "raise-hand" as a one-shot event means a late
  // joiner's UI can be told the current state, not just future changes.
  socket.on("presence:raise-hand", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    const raised = Boolean(payload?.raised);
    io.to(roomFor(sessionId)).emit("presence:hand-raised", {
      userId,
      raised,
    });
  });

  socket.on("presence:reaction", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    const emoji = payload?.emoji;
    if (!ALLOWED_REACTIONS.has(emoji)) return; // ignore anything unexpected
    io.to(roomFor(sessionId)).emit("presence:reaction", {
      userId,
      emoji,
      at: Date.now(),
    });
  });
}

module.exports = { registerPresenceHandlers };
