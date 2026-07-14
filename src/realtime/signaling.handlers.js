// src/realtime/signaling.handlers.js
//
// WebRTC offer/answer/ICE relay for the 1-on-1 video call. This server
// never looks at the SDP/ICE payloads themselves — it's a dumb relay
// between the two sockets already sitting in the same `session:<id>`
// room (membership + ownership already verified by socket.server.js's
// 'session:join' handler before either socket can reach here).
//
// Negotiation pattern: whoever is ALREADY in the room when the second
// participant joins is the one who creates the offer (triggered by the
// 'session:peer-joined' event socket.server.js emits) — see
// video_call_controller.dart on the Flutter side. That avoids the classic
// two-sided "who offers first" race without needing perfect-negotiation
// machinery, since a session room only ever has exactly 2 participants.

function registerSignalingHandlers(io, socket) {
  socket.on("webrtc:offer", ({ sdp }) => {
    const room = socket.data.sessionId;
    if (!room || !sdp) return;
    socket.to(`session:${room}`).emit("webrtc:offer", {
      sdp,
      from: socket.user.sub,
    });
  });

  socket.on("webrtc:answer", ({ sdp }) => {
    const room = socket.data.sessionId;
    if (!room || !sdp) return;
    socket.to(`session:${room}`).emit("webrtc:answer", {
      sdp,
      from: socket.user.sub,
    });
  });

  socket.on("webrtc:ice-candidate", ({ candidate }) => {
    const room = socket.data.sessionId;
    if (!room || !candidate) return;
    socket.to(`session:${room}`).emit("webrtc:ice-candidate", {
      candidate,
      from: socket.user.sub,
    });
  });
}

module.exports = { registerSignalingHandlers };
