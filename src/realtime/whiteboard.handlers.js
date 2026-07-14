// src/realtime/whiteboard.handlers.js
//
// Live whiteboard sync — broadcast-only, nothing persisted (see
// 0009_session_room.sql's header comment for why). Strokes are relayed
// as opaque payloads; this server doesn't need to understand their shape,
// only who's allowed to send them.
//
// Per the spec ("Student permissions can be enabled or disabled"), draw
// access is enforced here server-side, not just hidden in the client UI —
// an in-memory per-session flag the teacher toggles. Defaults to allowed
// (true) since a tutoring whiteboard is normally collaborative; the
// teacher can lock it down mid-session.

const roomPermissions = new Map(); // sessionId -> { studentCanDraw: boolean }

function registerWhiteboardHandlers(io, socket) {
  socket.on("whiteboard:stroke", (stroke) => {
    const sessionId = socket.data.sessionId;
    if (!sessionId || !stroke) return;
    if (socket.user.role === "student") {
      const perms = roomPermissions.get(sessionId);
      if (perms && perms.studentCanDraw === false) return; // silently dropped
    }
    socket.to(`session:${sessionId}`).emit("whiteboard:stroke", stroke);
  });

  socket.on("whiteboard:clear", () => {
    const sessionId = socket.data.sessionId;
    if (!sessionId || socket.user.role !== "teacher") return;
    io.to(`session:${sessionId}`).emit("whiteboard:clear");
  });

  socket.on("whiteboard:set-permission", ({ studentCanDraw }) => {
    const sessionId = socket.data.sessionId;
    if (!sessionId || socket.user.role !== "teacher") return;
    roomPermissions.set(sessionId, { studentCanDraw: !!studentCanDraw });
    io.to(`session:${sessionId}`).emit("whiteboard:permission", {
      studentCanDraw: !!studentCanDraw,
    });
  });
}

module.exports = { registerWhiteboardHandlers };
