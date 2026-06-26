// src/routes/index.js
const express = require("express");
const { authenticate, requireRole } = require("../middleware/auth.middleware");
const authCtrl = require("../controllers/auth.controller");
const bookCtrl = require("../controllers/bookings.controller");
const teachCtrl = require("../controllers/teachers.controller");
const adminCtrl = require("../controllers/admin.controller");

const router = express.Router();

// ── Auth (public) ─────────────────────────────────────────────────────────────
router.post("/auth/register", authCtrl.register);
router.post("/auth/login", authCtrl.login);
router.post("/auth/otp/send", authCtrl.sendOtp);
router.post("/auth/otp/verify", authCtrl.verifyOtp);
router.post("/auth/refresh", authCtrl.refresh);
router.post("/auth/logout", authCtrl.logout);

// ── Auth (protected) ──────────────────────────────────────────────────────────
router.get("/auth/me", authenticate, authCtrl.me);

// ── Teachers (public browse) ──────────────────────────────────────────────────
router.get("/teachers", authenticate, teachCtrl.browse);
router.get("/teachers/:id", authenticate, teachCtrl.getOne);
router.patch(
  "/teachers/profile",
  authenticate,
  requireRole("teacher"),
  teachCtrl.updateProfile,
);

// ── Bookings ──────────────────────────────────────────────────────────────────
router.get(
  "/bookings",
  authenticate,
  requireRole("student", "teacher"),
  bookCtrl.list,
);
router.post("/bookings", authenticate, requireRole("student"), bookCtrl.create);
router.patch(
  "/bookings/:id/complete",
  authenticate,
  requireRole("teacher", "admin"),
  bookCtrl.complete,
);
router.patch("/bookings/:id/cancel", authenticate, bookCtrl.cancel);

// ── Admin ─────────────────────────────────────────────────────────────────────
const admin = [authenticate, requireRole("admin")];
router.get("/admin/dashboard", ...admin, adminCtrl.dashboard);
router.get("/admin/users", ...admin, adminCtrl.listUsers);
router.patch("/admin/users/:id/toggle", ...admin, adminCtrl.toggleUser);
router.patch("/admin/teachers/:id/approve", ...admin, adminCtrl.approveTeacher);
router.get("/admin/bookings", ...admin, adminCtrl.listBookings);
router.get("/admin/rewards", ...admin, adminCtrl.listRewards);
router.post("/admin/rewards", ...admin, adminCtrl.createReward);
router.patch("/admin/rewards/:id", ...admin, adminCtrl.updateReward);

module.exports = router;
