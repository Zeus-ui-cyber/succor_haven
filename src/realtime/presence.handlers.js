// src/realtime/presence.handlers.js
//
// Raise hand + emoji reactions — purely ephemeral, broadcast-only, no DB
// writes. Matches the spec's "Raise Hand: allows student to politely
// request to speak, teacher receives notification" and the reaction set
// (👍 ❤️ 👏 😂).

function registerPresenceHandlers(io, socket) {
  socket.on("presence:raise-hand", ({ raised }) => {
    const sessionId = socket.data.sessionId;
    if (!sessionId) return;
    socket.to(`session:${sessionId}`).emit("presence:raise-hand", {
      userId: socket.user.sub,
      raised: !!raised,
    });
  });

  socket.on("presence:reaction", ({ emoji }) => {
    const sessionId = socket.data.sessionId;
    if (!sessionId || typeof emoji !== "string") return;
    socket.to(`session:${sessionId}`).emit("presence:reaction", {
      userId: socket.user.sub,
      emoji,
    });
  });
}

module.exports = { registerPresenceHandlers };
