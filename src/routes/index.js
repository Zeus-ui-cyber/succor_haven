// src/routes/index.js
const express = require("express");
const path = require("path");
const fs = require("fs");
const multer = require("multer"); // npm install multer, if not already installed

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
const settingsCtrl = require("../controllers/settings.controller");

const router = express.Router();

// ── Settings · profile picture upload config ──────────────────────────────────
// Stored outside src/ at project-root/uploads/profile-pictures. Served
// statically via `app.use("/uploads", express.static(...))` in app.js.
const profilePictureDir = path.join(__dirname, "..", "..", "uploads", "profile-pictures");
fs.mkdirSync(profilePictureDir, { recursive: true });

const profilePictureStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profilePictureDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || ".jpg";
    cb(null, `user-${req.user?.sub ?? "unknown"}-${Date.now()}${ext}`);
  },
});

const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];

const uploadProfilePicture = multer({
  storage: profilePictureStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_IMAGE_TYPES.includes(file.mimetype)) {
      return cb(new Error("Only JPEG, PNG, or WEBP images are allowed."));
    }
    cb(null, true);
  },
});

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

// ── Teachers (public browse) ──────────────────────────────────────────────────
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

// ── Teachers · own account settings (bio / subjects / availability / credits) ─
// ⚠️ RESOLVED (see prior TODO): these replace the old /settings/teacher/*
// routes, which used settingsCtrl for the same bio/subjects/availability/
// credits data. Keeping both live would mean two write paths to the same
// columns via two different controllers — settingsCtrl is no longer wired
// for these operations. If settingsCtrl.getTeacherProfile / updateBio /
// addSubject / updateSubject / removeSubject / getAvailability /
// addAvailabilitySlot / updateAvailabilitySlot / deleteAvailabilitySlot /
// getCreditsSummary are unused elsewhere, they can be removed from
// settings.controller.js entirely.
//
// ⚠️ CORRECTED: subjects live in teacher_profiles as an array (e.g. TEXT[]),
// not as their own rows with an id column — unlike availability slots, which
// still have an id (crypto.randomUUID()) since they come from a JSONB array
// of objects. So subjects PATCH/DELETE take the subject value itself in the
// body, not a :id param.
router.get(
  "/teachers/profile/me",
  authenticate,
  requireRole("teacher"),
  teachCtrl.getMyProfile,
);
router.patch(
  "/teachers/profile/bio",
  authenticate,
  requireRole("teacher"),
  teachCtrl.updateBio,
);
router.post(
  "/teachers/profile/subjects",
  authenticate,
  requireRole("teacher"),
  teachCtrl.addSubject,
);
router.patch(
  "/teachers/profile/subjects",
  authenticate,
  requireRole("teacher"),
  teachCtrl.updateSubject,
);
router.delete(
  "/teachers/profile/subjects",
  authenticate,
  requireRole("teacher"),
  teachCtrl.removeSubject,
);
router.get(
  "/teachers/profile/availability",
  authenticate,
  requireRole("teacher"),
  teachCtrl.getAvailability,
);
router.post(
  "/teachers/profile/availability",
  authenticate,
  requireRole("teacher"),
  teachCtrl.addAvailabilitySlot,
);
router.patch(
  "/teachers/profile/availability/:id",
  authenticate,
  requireRole("teacher"),
  teachCtrl.updateAvailabilitySlot,
);
router.delete(
  "/teachers/profile/availability/:id",
  authenticate,
  requireRole("teacher"),
  teachCtrl.deleteAvailabilitySlot,
);
router.get(
  "/teachers/profile/credits",
  authenticate,
  requireRole("teacher"),
  teachCtrl.getCreditsSummary,
);

// ── Courses ───────────────────────────────────────────────────────────────────
router.get("/courses", authenticate, courseCtrl.browse);
router.get("/courses/categories", authenticate, courseCtrl.categories);
router.get("/courses/:id", authenticate, courseCtrl.getOne);

// ── Settings ──────────────────────────────────────────────────────────────────
router.patch("/settings/profile", authenticate, settingsCtrl.updateProfile);
router.post(
  "/settings/profile/picture",
  authenticate,
  uploadProfilePicture.single("profilePicture"),
  settingsCtrl.uploadProfilePicture,
);

router.post("/settings/password/otp/send", authenticate, settingsCtrl.sendPasswordChangeOtp);
router.post("/settings/password/change", authenticate, settingsCtrl.changePassword);

router.get("/settings/phone", authenticate, settingsCtrl.getPhones);
router.post("/settings/phone/otp/send", authenticate, settingsCtrl.sendPhoneOtp);
router.patch("/settings/phone/primary", authenticate, settingsCtrl.updatePrimaryPhone);
router.patch("/settings/phone/backup", authenticate, settingsCtrl.updateBackupPhone);

router.patch("/settings/language", authenticate, settingsCtrl.updateLanguage);

router.get("/settings/notifications", authenticate, settingsCtrl.getNotificationPreferences);
router.patch(
  "/settings/notifications",
  authenticate,
  settingsCtrl.updateNotificationPreferences,
);

router.post("/settings/concerns", authenticate, settingsCtrl.submitConcern);

// ── Admin ─────────────────────────────────────────────────────────────────────
const admin = [authenticate, requireRole("admin")];
router.get("/admin/dashboard", ...admin, adminCtrl.dashboard);
router.get("/admin/users", ...admin, adminCtrl.listUsers);
router.patch("/admin/users/:id/toggle", ...admin, adminCtrl.toggleUser);
router.delete("/admin/users/:id", ...admin, adminCtrl.deleteUser);
router.patch("/admin/users/:id/credits", ...admin, adminCtrl.adjustCredits);
router.patch("/admin/users/:id/points", ...admin, adminCtrl.adjustPoints);
router.patch("/admin/teachers/:id/approve", ...admin, adminCtrl.approveTeacher);
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