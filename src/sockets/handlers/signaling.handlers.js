// src/sockets/handlers/signaling.handlers.js
//
// WebRTC offer/answer/ICE relay over the existing session Socket.IO
// room. Pure relay — no state kept here; the peer connection state
// machine lives entirely on the two clients.
//
// Confirmed against src/realtime/socket.server.js:
//   - `session:join` does socket.join(`session:${sessionId}`) and sets
//     socket.data.sessionId — read fresh inside each handler below
//     (NOT destructured once at registration time), since these
//     handlers are registered at connection time, before the client has
//     necessarily joined a session room yet.
//   - The io.use() auth middleware sets socket.user = { sub, role, email }
//     (from verifyAccess) — userId comes from socket.user.sub, not
//     socket.data.
//   - Exactly two participants per room (teacher + student), so
//     `socket.to(room).emit(...)` (which excludes the sender) is always
//     "send to the other participant" without needing to target a
//     specific socket id.

function roomFor(sessionId) {
  return `session:${sessionId}`;
}

/**
 * @param {import('socket.io').Server} io
 * @param {import('socket.io').Socket} socket
 */
function registerSignalingHandlers(io, socket) {
  const userId = socket.user?.sub;

  // Caller creates an offer once both sides are present; relayed as-is.
  socket.on("webrtc:offer", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("webrtc:offer", {
      fromUserId: userId,
      sdp: payload?.sdp,
    });
  });

  socket.on("webrtc:answer", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("webrtc:answer", {
      fromUserId: userId,
      sdp: payload?.sdp,
    });
  });

  socket.on("webrtc:ice-candidate", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("webrtc:ice-candidate", {
      fromUserId: userId,
      candidate: payload?.candidate,
    });
  });

  // Lets the other side know this participant intentionally dropped the
  // call (as opposed to a network blip) so the UI can show "left the
  // call" rather than just spinning on a stalled connection.
  socket.on("webrtc:hangup", () => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("webrtc:hangup", { fromUserId: userId });
  });
}

module.exports = { registerSignalingHandlers, roomFor };
