// src/realtime/socket.server.js
//
// Real-time layer for "My Sessions" video meetings — signaling, chat,
// whiteboard, and presence all run over this one Socket.IO server rather
// than separate transports, mirroring the single-Express-app style of
// the rest of the backend. No Google/Firebase services involved anywhere
// in this file, by design (China-deployment requirement).
//
// Phase 0 scope was connection auth + join/leave a per-session room. This
// pass wires in the four handler modules (signaling/chat/whiteboard/
// presence) that were previously just planned as "land in later phases
// as separate files under this same directory" — they're registered
// below, right after session:join, so their event listeners are live
// for the whole lifetime of the socket connection (checking
// socket.data.sessionId internally before doing anything, since a
// client can have connected but not yet joined a room).

const { Server } = require("socket.io");
const { verifyAccess } = require("../services/jwt.service");
const sessionService = require("../services/session.service");
const {
  registerSignalingHandlers,
} = require("../sockets/handlers/signaling.handlers");
const { registerChatHandlers } = require("../sockets/handlers/chat.handlers");
const {
  registerWhiteboardHandlers,
} = require("../sockets/handlers/whiteboard.handlers");
const {
  registerPresenceHandlers,
} = require("../sockets/handlers/presence.handlers");

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
    // NEW: signaling/chat/whiteboard/presence event listeners, live for
    // this whole connection. Each one no-ops until socket.data.sessionId
    // is set by session:join below, so registering them here (rather
    // than inside the join handler) is safe — there's no window where a
    // client could fire e.g. "chat:send" before joining and have it do
    // anything, since every handler checks socket.data.sessionId first.
    registerSignalingHandlers(io, socket);
    registerChatHandlers(io, socket);
    registerWhiteboardHandlers(io, socket);
    registerPresenceHandlers(io, socket);

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
        socket
          .to(room)
          .emit("session:peer-joined", { userId: socket.user.sub });
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
