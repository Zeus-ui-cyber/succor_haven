// src/sockets/handlers/whiteboard.handlers.js
//
// Whiteboard is broadcast-only per the plan — no DB table, no
// persistence, no "restore on reconnect" replay. A stroke, an undo/redo
// step, or a clear is just relayed to whoever else is in the room at
// that moment.
//
// See signaling.handlers.js for the socket.data.sessionId /
// socket.user.sub read pattern; same applies here.

const { roomFor } = require("./signaling.handlers");

/**
 * @param {import('socket.io').Server} io
 * @param {import('socket.io').Socket} socket
 */
function registerWhiteboardHandlers(io, socket) {
  const role = socket.user?.role;

  // payload shape left to the client (pen/shape/text stroke data, an
  // undo/redo marker, etc.) — this is a pure relay, so we don't
  // validate the drawing payload's internal structure here.
  socket.on("whiteboard:draw", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("whiteboard:draw", payload);
  });

  socket.on("whiteboard:undo", () => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("whiteboard:undo");
  });

  socket.on("whiteboard:redo", () => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    socket.to(roomFor(sessionId)).emit("whiteboard:redo");
  });

  // Clear is broadcast to the WHOLE room (including sender) via
  // io.to(...) rather than socket.to(...), so both canvases wipe in the
  // same tick instead of the initiator's clearing locally first and the
  // remote side lagging behind on the round trip.
  socket.on("whiteboard:clear", () => {
    const { sessionId } = socket.data;
    if (!sessionId) return;
    io.to(roomFor(sessionId)).emit("whiteboard:clear");
  });

  // Teacher-only: toggle whether the student can draw. Silently no-ops
  // for a student trying to call this rather than erroring, since a
  // stray/forged event here is low-stakes (worst case: nothing happens).
  socket.on("whiteboard:set-student-permission", (payload) => {
    const { sessionId } = socket.data;
    if (!sessionId || role !== "teacher") return;
    const canDraw = Boolean(payload?.canDraw);
    io.to(roomFor(sessionId)).emit("whiteboard:student-permission", {
      canDraw,
    });
  });
}

module.exports = { registerWhiteboardHandlers };
