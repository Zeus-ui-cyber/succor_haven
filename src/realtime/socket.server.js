// src/realtime/socket.server.js
//
// Real-time layer for "My Sessions" video meetings — signaling, chat,
// whiteboard, and presence all run over this one Socket.IO server rather
// than separate transports, mirroring the single-Express-app style of
// the rest of the backend. No Google/Firebase services involved anywhere
// in this file, by design (China-deployment requirement).
//
// Connection auth + join/leave a per-session room, with an ownership
// check against the `sessions` table so only the assigned teacher/student
// can be in the room. WebRTC offer/answer/ICE relay, chat, whiteboard,
// and presence each live in their own handler file under this directory
// and get registered per-socket below — this file owns only the
// join/leave lifecycle (room membership, attendance, in-progress status)
// that the others depend on.

const { Server } = require("socket.io");
const { verifyAccess } = require("../services/jwt.service");
const sessionService = require("../services/session.service");
const { registerSignalingHandlers } = require("./signaling.handlers");
const { registerChatHandlers } = require("./chat.handlers");
const { registerWhiteboardHandlers } = require("./whiteboard.handlers");
const { registerPresenceHandlers } = require("./presence.handlers");

let ioInstance = null;

function initSocketServer(httpServer) {
  const io = new Server(httpServer, {
    path: "/socket.io",
    cors: {
      origin: true,
      credentials: true,
    },
  });

  ioInstance = io;

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
    // Join a user-specific room to allow targeted real-time updates (e.g. notifications,
    // session updates, and appointment status changes).
    const userId = socket.user.sub;
    const userRoom = `user:${userId}`;
    socket.join(userRoom);
    console.log(`Socket client connected: user ${userId} joined room ${userRoom}`);

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

        // First real join flips "Upcoming" -> "In Progress" and starts
        // the in-call timer; every join (including reconnects) gets its
        // own attendance row so join/leave/duration can be summed later.
        await sessionService.markInProgress(sessionId);
        socket.data.attendanceId = await sessionService.recordJoin(
          sessionId,
          socket.user.sub,
        );

        socket
          .to(room)
          .emit("session:peer-joined", { userId: socket.user.sub });
        ack?.({ ok: true });
      } catch (err) {
        console.error("session:join error:", err);
        ack?.({ error: "Failed to join session." });
      }
    });

    registerSignalingHandlers(io, socket);
    registerChatHandlers(io, socket);
    registerWhiteboardHandlers(io, socket);
    registerPresenceHandlers(io, socket);

    socket.on("disconnect", async () => {
      const sessionId = socket.data.sessionId;
      if (!sessionId) return;
      socket.to(`session:${sessionId}`).emit("session:peer-left", {
        userId: socket.user.sub,
      });
      if (socket.data.attendanceId) {
        try {
          await sessionService.recordLeave(socket.data.attendanceId);
        } catch (err) {
          console.error("recordLeave error:", err);
        }
      }
    });
  });

  return io;
}

/**
 * Emit a Socket.IO event to a specific user.
 * @param {string|number} userId
 * @param {string} event
 * @param {any} data
 */
function emitToUser(userId, event, data) {
  if (ioInstance) {
    ioInstance.to(`user:${userId}`).emit(event, data);
  } else {
    console.warn(`[Socket.server] ioInstance not ready. Cannot emit ${event} to user ${userId}`);
  }
}

module.exports = { initSocketServer, emitToUser };
