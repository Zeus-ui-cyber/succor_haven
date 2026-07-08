// src/routes/index.js
const express = require("express");
const {
  authenticate,
  requireRole,
  requireApprovedTeacher,
} = require("../middleware/auth.middleware");
const authCtrl = require("../controllers/auth.controller");
const bookCtrl = require("../controllers/bookings.controller");
const teachCtrl = require("../controllers/teachers.controller");
const courseCtrl = require("../controllers/courses.controller");
const adminCtrl = require("../controllers/admin.controller");
const creditRulesCtrl = require("../controllers/creditRules.controller");
const pricingCtrl = require("../controllers/pricing.controller");
const milestonesCtrl = require("../controllers/milestones.controller");

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

// ── Bookings ──────────────────────────────────────────────────────────────────
// ⚠️ FIXED: requireApprovedTeacher was previously applied to GET /bookings
// and PATCH /bookings/:id/cancel for everyone, including students — which
// meant a student could never list or cancel their own bookings (they'd
// fail the teacher-approval check). It now only gates the teacher-specific
// complete action.
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
  requireApprovedTeacher,
  bookCtrl.complete,
);
router.patch("/bookings/:id/cancel", authenticate, bookCtrl.cancel);

// ── Teachers ──────────────────────────────────────────────────────────────────
// Profile update is allowed even while pending — teachers must be able to
// fill in their bio/subjects/availability before the admin reviews them.
router.get("/teachers", authenticate, teachCtrl.browse);
router.get("/teachers/:id", authenticate, teachCtrl.getOne);
router.patch(
  "/teachers/profile",
  authenticate,
  requireRole("teacher"),
  teachCtrl.updateProfile,
);

// ── Courses ───────────────────────────────────────────────────────────────────
router.get("/courses", authenticate, courseCtrl.browse);
router.get("/courses/categories", authenticate, courseCtrl.categories);
router.get("/courses/:id", authenticate, courseCtrl.getOne);

// ── Admin ─────────────────────────────────────────────────────────────────────
const admin = [authenticate, requireRole("admin")];
router.get("/admin/dashboard", ...admin, adminCtrl.dashboard);
router.get("/admin/users", ...admin, adminCtrl.listUsers);
router.patch("/admin/users/:id/toggle", ...admin, adminCtrl.toggleUser);
router.delete("/admin/users/:id", ...admin, adminCtrl.deleteUser);
router.patch("/admin/users/:id/credits", ...admin, adminCtrl.adjustCredits);
router.patch("/admin/users/:id/points", ...admin, adminCtrl.adjustPoints);
router.post("/admin/teachers", ...admin, adminCtrl.createTeacher);
router.get("/admin/teachers/:id/bookings", ...admin, adminCtrl.teacherSchedule);
router.get("/admin/bookings", ...admin, adminCtrl.listBookings);
router.patch("/admin/bookings/:id/cancel", ...admin, adminCtrl.cancelBooking);
router.get("/admin/rewards", ...admin, adminCtrl.listRewards);
router.post("/admin/rewards", ...admin, adminCtrl.createReward);
router.patch("/admin/rewards/:id", ...admin, adminCtrl.updateReward);
router.delete("/admin/rewards/:id", ...admin, adminCtrl.deleteReward);

// ── Admin · Credit Rules ──────────────────────────────────────────────────────
router.get("/admin/credit-rules", ...admin, creditRulesCtrl.list);
router.post("/admin/credit-rules", ...admin, creditRulesCtrl.create);
router.patch("/admin/credit-rules/:id", ...admin, creditRulesCtrl.update);
router.delete("/admin/credit-rules/:id", ...admin, creditRulesCtrl.remove);

// ── Admin · Session Pricing ───────────────────────────────────────────────────
router.get("/admin/pricing", ...admin, pricingCtrl.list);
router.post("/admin/pricing", ...admin, pricingCtrl.create);
router.patch("/admin/pricing/:id", ...admin, pricingCtrl.update);
router.delete("/admin/pricing/:id", ...admin, pricingCtrl.remove);

// ── Admin · Courses ────────────────────────────────────────────────────────────
router.post("/admin/courses", ...admin, courseCtrl.create);
router.patch("/admin/courses/:id", ...admin, courseCtrl.update);
router.delete("/admin/courses/:id", ...admin, courseCtrl.remove);

// ── Admin · Milestones ────────────────────────────────────────────────────────
router.get("/admin/milestones", ...admin, milestonesCtrl.list);
router.post("/admin/milestones", ...admin, milestonesCtrl.create);
router.patch("/admin/milestones/:id", ...admin, milestonesCtrl.update);
router.delete("/admin/milestones/:id", ...admin, milestonesCtrl.remove);

module.exports = router;
