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
const studentsAdminCtrl = require("../controllers/studentsAdmin.controller");
const appointmentsController = require("../controllers/appointments.controller");
const modulesCtrl = require("../controllers/modules.controller");
const announcementsCtrl = require("../controllers/announcements.controller");
const announcementCommentsCtrl = require("../controllers/announcementComments.controller");
const notificationsCtrl = require("../controllers/notifications.controller");
const paymentsCtrl = require("../controllers/payments.controller"); // ← NEW

const router = express.Router();

// ── Settings · profile picture upload config ──────────────────────────────────
// Stored outside src/ at project-root/uploads/profile-pictures. Served
// statically via `app.use("/uploads", express.static(...))` in app.js.
const profilePictureDir = path.join(
  __dirname,
  "..",
  "..",
  "uploads",
  "profile-pictures",
);
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

// ── Modules · upload config ──────────────────────────────────────────────────
// Stored outside src/ at project-root/uploads/modules. Served statically
// via the same `app.use("/uploads", express.static(...))` in app.js that
// already handles profile-pictures — no extra static route needed.
const moduleFileDir = path.join(__dirname, "..", "..", "uploads", "modules");
fs.mkdirSync(moduleFileDir, { recursive: true });

const moduleFileStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, moduleFileDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || "";
    cb(null, `module-${req.user?.sub ?? "unknown"}-${Date.now()}${ext}`);
  },
});

const ALLOWED_MODULE_TYPES = [
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
];

const uploadModuleFile = multer({
  storage: moduleFileStorage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB — documents, larger than profile pics
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_MODULE_TYPES.includes(file.mimetype)) {
      return cb(
        new Error("Only PDF, DOC, DOCX, PPT, or PPTX files are allowed."),
      );
    }
    cb(null, true);
  },
});

// ── Announcements · cover image / attachment upload config ───────────────────
// Stored outside src/ at project-root/uploads/announcements. Served
// statically via the same `app.use("/uploads", express.static(...))` in
// app.js that already handles profile-pictures and modules.
const announcementFileDir = path.join(
  __dirname,
  "..",
  "..",
  "uploads",
  "announcements",
);
fs.mkdirSync(announcementFileDir, { recursive: true });

const announcementFileStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, announcementFileDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || "";
    cb(null, `announcement-${req.user?.sub ?? "unknown"}-${Date.now()}${ext}`);
  },
});

const ALLOWED_ANNOUNCEMENT_TYPES = [
  ...ALLOWED_IMAGE_TYPES,
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
];

const uploadAnnouncementFile = multer({
  storage: announcementFileStorage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB, same ceiling as modules
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_ANNOUNCEMENT_TYPES.includes(file.mimetype)) {
      return cb(
        new Error("Only JPEG, PNG, WEBP, PDF, DOC, or DOCX files are allowed."),
      );
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

// ── Rewards (student-facing, read-only) ────────────────────────────────────────
router.get("/rewards", authenticate, adminCtrl.listRewards);

// ── Credit Packages (public read, any authenticated role) ────────────────────
// NEW: "Buy Credits" screen reads active tiers from here. Admin CRUD is
// registered further down in the ── Admin ── section.
router.get("/credit-packages", authenticate, paymentsCtrl.listPackages);

// ── Payments (student) ────────────────────────────────────────────────────────
// NEW: student's own top-up history, shown under Profile/Settings.
router.get(
  "/credits/payments/mine",
  authenticate,
  requireRole("student"),
  paymentsCtrl.listMyPayments,
);
// NEW: student submits a top-up request (manual-confirmation flow — see
// payments.controller.js). Creates a `pending` payment row for the admin
// Payments tab to confirm/reject.
router.post(
  "/credits/payments",
  authenticate,
  requireRole("student"),
  paymentsCtrl.requestPayment,
);
// NEW: student flags a succeeded payment as wanting a refund — just a
// timestamp for the admin Payments tab to prioritize; the actual refund
// stays admin-initiated via PATCH /admin/payments/:id/status.
router.post(
  "/credits/payments/:id/refund-request",
  authenticate,
  requireRole("student"),
  paymentsCtrl.requestRefund,
);
// NEW: student withdraws a still-pending request with a reason
// (Shopee-style cancel flow). Only valid from 'pending' — once an admin
// has acted, requestRefund above is the right tool instead.
router.patch(
  "/credits/payments/:id/cancel",
  authenticate,
  requireRole("student"),
  paymentsCtrl.cancelPayment,
);

// ── Modules ───────────────────────────────────────────────────────────────────
// Both admin and teacher can view/upload. Update/delete permission is
// enforced inside modules.controller.js (admin: any; teacher: own only),
// since requireRole alone can't express "own resource" logic.
router.get(
  "/modules",
  authenticate,
  requireRole("admin", "teacher"),
  modulesCtrl.list,
);
router.get(
  "/modules/:id",
  authenticate,
  requireRole("admin", "teacher"),
  modulesCtrl.getOne,
);
router.post(
  "/modules",
  authenticate,
  requireRole("admin", "teacher"),
  uploadModuleFile.single("file"),
  modulesCtrl.create,
);
router.patch(
  "/modules/:id",
  authenticate,
  requireRole("admin", "teacher"),
  uploadModuleFile.single("file"),
  modulesCtrl.update,
);
router.delete(
  "/modules/:id",
  authenticate,
  requireRole("admin", "teacher"),
  modulesCtrl.remove,
);

// ── Settings ──────────────────────────────────────────────────────────────────
router.patch("/settings/profile", authenticate, settingsCtrl.updateProfile);
router.post(
  "/settings/profile/picture",
  authenticate,
  uploadProfilePicture.single("profilePicture"),
  settingsCtrl.uploadProfilePicture,
);

router.post(
  "/settings/password/otp/send",
  authenticate,
  settingsCtrl.sendPasswordChangeOtp,
);
router.post(
  "/settings/password/change",
  authenticate,
  settingsCtrl.changePassword,
);

router.get("/settings/phone", authenticate, settingsCtrl.getPhones);
router.post(
  "/settings/phone/otp/send",
  authenticate,
  settingsCtrl.sendPhoneOtp,
);
router.patch(
  "/settings/phone/primary",
  authenticate,
  settingsCtrl.updatePrimaryPhone,
);
router.patch(
  "/settings/phone/backup",
  authenticate,
  settingsCtrl.updateBackupPhone,
);

router.patch("/settings/language", authenticate, settingsCtrl.updateLanguage);

router.get(
  "/settings/notifications",
  authenticate,
  settingsCtrl.getNotificationPreferences,
);
router.patch(
  "/settings/notifications",
  authenticate,
  settingsCtrl.updateNotificationPreferences,
);

router.post("/settings/concerns", authenticate, settingsCtrl.submitConcern);

// ── Appointments ──────────────────────────────────────────────────────────────
// Student
router.post(
  "/appointments",
  authenticate,
  requireRole("student"),
  appointmentsController.createAppointment,
);
router.get(
  "/appointments/mine",
  authenticate,
  requireRole("student"),
  appointmentsController.getMyAppointments,
);
router.patch(
  "/appointments/:id/cancel",
  authenticate,
  appointmentsController.cancelAppointment,
);
router.patch(
  "/appointments/:id/respond-reschedule",
  authenticate,
  appointmentsController.respondToReschedule,
);

// Shared (student or teacher viewing their own appointment — enforce
// ownership inside the controller, since role alone can't tell us that)
router.get(
  "/appointments/:id",
  authenticate,
  appointmentsController.getAppointmentById,
);

// Teacher (Phase 2 UI, endpoints ready now)
router.get(
  "/appointments/teacher/mine",
  authenticate,
  requireRole("teacher"),
  appointmentsController.getTeacherAppointments,
);
router.patch(
  "/appointments/:id/approve",
  authenticate,
  requireRole("teacher", "admin"),
  appointmentsController.approveAppointment,
);
router.patch(
  "/appointments/:id/decline",
  authenticate,
  requireRole("teacher", "admin"),
  appointmentsController.declineAppointment,
);
router.patch(
  "/appointments/:id/propose-reschedule",
  authenticate,
  requireRole("teacher", "admin"),
  appointmentsController.proposeReschedule,
);
router.patch(
  "/appointments/:id/complete",
  authenticate,
  requireRole("teacher", "admin"),
  appointmentsController.completeAppointment,
);

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

// ── Admin · Credit Packages ("Buy Credits" tiers) ─────────────────────────────
// NEW: admin-only create/update/delete. Public read (GET /credit-packages,
// no /admin prefix) is registered earlier, open to any authenticated role.
router.get("/admin/credit-packages", ...admin, paymentsCtrl.listPackagesAdmin);
router.post("/admin/credit-packages", ...admin, paymentsCtrl.createPackage);
router.patch(
  "/admin/credit-packages/:id",
  ...admin,
  paymentsCtrl.updatePackage,
);
router.delete(
  "/admin/credit-packages/:id",
  ...admin,
  paymentsCtrl.deletePackage,
);

// ── Admin · Payments ───────────────────────────────────────────────────────────
// NEW: full transaction list + revenue totals, filterable by ?status=/?method=.
router.get("/admin/payments", ...admin, paymentsCtrl.listPaymentsAdmin);
// NEW: confirm/reject/refund a payment. On 'succeeded', credits the
// student's balance in the same transaction (see payments.controller.js).
router.patch(
  "/admin/payments/:id/status",
  ...admin,
  paymentsCtrl.updatePaymentStatus,
);

// ── Admin · Students List ──────────────────────────────────────────────────────
router.get("/admin/students", ...admin, studentsAdminCtrl.list);
router.get("/admin/students/summary", ...admin, studentsAdminCtrl.summary);
router.get("/admin/students/:id", ...admin, studentsAdminCtrl.getOne);
router.patch("/admin/students/:id", ...admin, studentsAdminCtrl.update);
router.post(
  "/admin/students/:id/reset-password",
  ...admin,
  studentsAdminCtrl.resetPassword,
);

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

// ── Announcements (student/teacher-facing, visibility-filtered) ──────────────
router.get("/announcements", authenticate, announcementsCtrl.list);
router.get("/announcements/:id", authenticate, announcementsCtrl.getOne);
router.post("/announcements/:id/like", authenticate, announcementsCtrl.like);
router.delete(
  "/announcements/:id/like",
  authenticate,
  announcementsCtrl.unlike,
);
router.post(
  "/announcements/:id/bookmark",
  authenticate,
  announcementsCtrl.bookmark,
);
router.delete(
  "/announcements/:id/bookmark",
  authenticate,
  announcementsCtrl.unbookmark,
);

// ── Admin · Announcements (create/manage) ─────────────────────────────────────
router.get("/admin/announcements", ...admin, announcementsCtrl.adminList);
router.post(
  "/announcements/upload",
  ...admin,
  uploadAnnouncementFile.single("file"),
  announcementsCtrl.uploadAsset,
);
router.post("/announcements", ...admin, announcementsCtrl.create);
router.patch("/announcements/:id", ...admin, announcementsCtrl.update);
router.delete("/announcements/:id", ...admin, announcementsCtrl.remove);
router.patch("/announcements/:id/archive", ...admin, announcementsCtrl.archive);
router.patch("/announcements/:id/restore", ...admin, announcementsCtrl.restore);
router.patch("/announcements/:id/pin", ...admin, announcementsCtrl.pin);
router.patch("/announcements/:id/unpin", ...admin, announcementsCtrl.unpin);

// ── Announcement Comments (author or admin can delete; anyone who can see
// the announcement can read/post, gated server-side on comments_enabled) ──
router.get(
  "/announcements/:id/comments",
  authenticate,
  announcementCommentsCtrl.list,
);
router.post(
  "/announcements/:id/comments",
  authenticate,
  announcementCommentsCtrl.create,
);
router.delete(
  "/announcements/comments/:commentId",
  authenticate,
  announcementCommentsCtrl.remove,
);

// ── In-app Notifications (bell icon feed) ────────────────────────────────────
router.get("/notifications", authenticate, notificationsCtrl.list);
router.get(
  "/notifications/unread-count",
  authenticate,
  notificationsCtrl.unreadCount,
);
router.patch(
  "/notifications/read-all",
  authenticate,
  notificationsCtrl.markAllRead,
);
router.patch(
  "/notifications/:id/read",
  authenticate,
  notificationsCtrl.markRead,
);

module.exports = router;
