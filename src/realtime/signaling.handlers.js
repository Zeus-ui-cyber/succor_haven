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
//
// Screen sharing reuses this SAME offer/answer/ICE relay for renegotiation
// (adding/removing the screen-share track mid-call just triggers another
// createOffer() on the sharing side) — the relay is generic by room, not
// tied to "first offer only". The one thing that needs real coordination
// is which side is allowed to share at a time, handled below.

// room ("session:<id>") -> userId currently sharing their screen in that
// room. Module-level (not per-socket) so it's shared across every
// registerSignalingHandlers() call in this process — fine since this app
// runs as a single Node process, no clustering. Used to stop both sides
// from starting a screen share at the same moment (which would otherwise
// race two concurrent renegotiations against each other).
const activeScreenShares = new Map();

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

  socket.on("screenshare:start", (_payload, ack) => {
    const room = socket.data.sessionId;
    if (!room) return ack?.({ error: "Not in a session room." });
    const roomKey = `session:${room}`;
    const currentSharer = activeScreenShares.get(roomKey);
    if (currentSharer && currentSharer !== socket.user.sub) {
      return ack?.({
        error: "The other participant is already sharing their screen.",
      });
    }
    activeScreenShares.set(roomKey, socket.user.sub);
    socket.to(roomKey).emit("screenshare:started", { userId: socket.user.sub });
    ack?.({ ok: true });
  });

  socket.on("screenshare:stop", () => {
    const room = socket.data.sessionId;
    if (!room) return;
    stopScreenShareFor(room, socket.user.sub, socket);
  });

  socket.on("media:state", (state) => {
    const room = socket.data.sessionId;
    if (!room) return;
    socket.to(`session:${room}`).emit("media:state", state);
  });
}

function stopScreenShareFor(sessionId, userId, socket) {
  const roomKey = `session:${sessionId}`;
  if (activeScreenShares.get(roomKey) !== userId) return;
  activeScreenShares.delete(roomKey);
  socket.to(roomKey).emit("screenshare:stopped", { userId });
}

module.exports = { registerSignalingHandlers, stopScreenShareFor };
