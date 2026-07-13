// src/realtime/socket.server.js
//
// Real-time layer for "My Sessions" video meetings — signaling, chat,
// whiteboard, and presence all run over this one Socket.IO server rather
// than separate transports, mirroring the single-Express-app style of
// the rest of the backend. No Google/Firebase services involved anywhere
// in this file, by design (China-deployment requirement).
//
// Phase 0 scope: connection auth + join/leave a per-session room, with an
// ownership check against the `sessions` table so only the assigned
// teacher/student can be in the room. WebRTC offer/answer/ICE relay,
// chat, whiteboard, and reactions handlers land in later phases as
// separate files under this same directory, each registered from here.

const { Server } = require("socket.io");
const { verifyAccess } = require("../services/jwt.service");
const sessionService = require("../services/session.service");

function initSocketServer(httpServer) {
  const io = new Server(httpServer, {
    path: "/socket.io",
    cors: {
      origin: (origin, callback) => {
        if (!origin || /^http:\/\/localhost(:\d+)?$/.test(origin)) {
          return callback(null, true);
        }
        callback(new Error(`Socket.IO CORS blocked: ${origin}`));
      },
      credentials: true,
    },
  });

  // Same bearer-token convention as auth.middleware.js's authenticate(),
  // just read from the Socket.IO handshake instead of an HTTP header.
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error("Missing auth token"));
      socket.user = verifyAccess(token); // { sub, role, email }
      next();
    } catch {
      next(new Error("Token expired or invalid"));
    }
  });

  io.on("connection", (socket) => {
    socket.on("session:join", async (sessionId, ack) => {
      try {
        const session = await sessionService.getById(sessionId);
        if (
          !session ||
          (session.teacher_id !== socket.user.sub &&
            session.student_id !== socket.user.sub)
        ) {
          return ack?.({ error: "Not authorized for this session." });
        }
        const room = `session:${sessionId}`;
        socket.join(room);
        socket.data.sessionId = sessionId;
        socket.to(room).emit("session:peer-joined", { userId: socket.user.sub });
        ack?.({ ok: true });
      } catch (err) {
        console.error("session:join error:", err);
        ack?.({ error: "Failed to join session." });
      }
    });

    socket.on("disconnect", () => {
      const sessionId = socket.data.sessionId;
      if (sessionId) {
        socket.to(`session:${sessionId}`).emit("session:peer-left", {
          userId: socket.user.sub,
        });
      }
    });
  });

  return io;
}

module.exports = { initSocketServer };
