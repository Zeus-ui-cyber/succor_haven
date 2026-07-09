// src/controllers/settings.controller.js
//
// Fixed to match your actual project conventions:
//   - pool:      require("../db/pool")            (module.exports = pool)
//   - user id:   req.user.sub                      (JWT `sub` claim)
//   - errors:    { error: "..." }                   (matches auth.middleware.js)
//   - otp:       otpService.sendSmsOtp(phone)
//                otpService.verifyOtp(target, code)  — no `type` param
//
// ⚠️ Sections 7/8/9 (Teacher: Bio & Subjects, Availability, Credits Per
// Session) were removed from this file — they now live in
// teachers.controller.js under /teachers/profile/*, backed by
// teacher_profiles instead of teacher_subjects / teacher_availability.
// If anything still imports settingsCtrl.getTeacherProfile / updateBio /
// addSubject / updateSubject / removeSubject / getAvailability /
// addAvailabilitySlot / updateAvailabilitySlot / deleteAvailabilitySlot /
// getCreditsSummary, update it to use teachCtrl instead — those exports no
// longer exist here.
//
// ⚠️ FIXED (this pass): the previous version wrote to a `full_name` column
// on UPDATE, based on a comment claiming pgAdmin confirmed that column
// exists. That check was run against the LOCAL succor_haven Postgres
// instance, not neondb — confirmed via runtime log (`DB CHECK: {
// current_database: 'neondb', ... }`) followed immediately by `error:
// column "full_name" does not exist`. The real columns are first_name /
// last_name, same as every other table in this app. Rewritten below.
//
// ⚠️ ALSO FIXED: `profile_picture_url` was referenced throughout (in the
// UPDATE ... RETURNING clause here, and as the column name in
// uploadProfilePicture below). This was untested — the full_name error
// above happened first in the same query, so profile_picture_url's
// correctness was never actually exercised. Per the confirmed live schema
// (teachers.controller.js hit a real runtime error whose Postgres hint
// read `Perhaps you meant to reference the column "u.avatar_url"`), the
// real column on `users` is `avatar_url`, not `profile_picture_url`.
// Renamed throughout. If this turns out wrong, run:
//   SELECT column_name FROM information_schema.columns WHERE table_name = 'users';
// against neondb (via psql, Neon's own web SQL editor, or a correctly
// re-registered pgAdmin connection — not the local server) and tell me
// the real name.

const bcrypt = require("bcrypt"); // swap for require("bcryptjs") if that's what auth.controller.js uses
const path = require("path");
const fs = require("fs");
const pool = require("../db/pool");
const otpService = require("../services/otp.service");

const MIN_PASSWORD_LENGTH = 8;

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

// ═══════════════════════════════════════════════════════════════════════
// 1. EDIT PROFILE
// ═══════════════════════════════════════════════════════════════════════

// PATCH /settings/profile
// body: { firstName, lastName }
exports.updateProfile = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { firstName, lastName } = req.body;

  if (!firstName?.trim() || !lastName?.trim()) {
    return res.status(400).json({ error: "First name and last name are required." });
  }

  const result = await pool.query(
    `UPDATE users
        SET first_name = $1, last_name = $2
      WHERE id = $3
      RETURNING id, email, first_name, last_name, role, avatar_url, created_at`,
    [firstName.trim(), lastName.trim(), userId],
  );

  if (result.rowCount === 0) {
    return res.status(404).json({ error: "User not found." });
  }

  return res.status(200).json({
    message: "Profile updated successfully.",
    user: result.rows[0],
  });
});

// POST /settings/profile/picture  (multipart/form-data, field: profilePicture)
exports.uploadProfilePicture = asyncHandler(async (req, res) => {
  const userId = req.user.sub;

  if (!req.file) {
    return res.status(400).json({ error: "No image file was uploaded." });
  }

  const relativeUrl = `/uploads/profile-pictures/${req.file.filename}`;

  const existing = await pool.query(
    `SELECT avatar_url FROM users WHERE id = $1`,
    [userId],
  );
  const oldUrl = existing.rows[0]?.avatar_url;

  await pool.query(`UPDATE users SET avatar_url = $1 WHERE id = $2`, [
    relativeUrl,
    userId,
  ]);

  if (oldUrl) {
    const oldPath = path.join(__dirname, "..", "..", oldUrl); // controllers/ -> src/ -> project root
    fs.unlink(oldPath, () => {}); // best-effort cleanup, ignore errors
  }

  return res.status(200).json({
    message: "Profile picture updated successfully.",
    avatarUrl: relativeUrl,
  });
});

// ═══════════════════════════════════════════════════════════════════════
// 2. CHANGE PASSWORD
// ═══════════════════════════════════════════════════════════════════════

// POST /settings/password/otp/send
exports.sendPasswordChangeOtp = asyncHandler(async (req, res) => {
  const userId = req.user.sub;

  const result = await pool.query(`SELECT phone FROM users WHERE id = $1`, [userId]);
  const phone = result.rows[0]?.phone;

  if (!phone) {
    return res.status(400).json({ error: "No registered phone number found for this account." });
  }

  await otpService.sendSmsOtp(phone);

  return res.status(200).json({ message: "Verification code sent." });
});

// POST /settings/password/change
// body: { otp, currentPassword, newPassword, confirmPassword }
exports.changePassword = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { otp, currentPassword, newPassword, confirmPassword } = req.body;

  if (!otp || !currentPassword || !newPassword || !confirmPassword) {
    return res.status(400).json({ error: "All fields are required." });
  }
  if (newPassword !== confirmPassword) {
    return res.status(400).json({ error: "New passwords do not match." });
  }
  if (newPassword.length < MIN_PASSWORD_LENGTH) {
    return res
      .status(400)
      .json({ error: `Password must be at least ${MIN_PASSWORD_LENGTH} characters.` });
  }
  if (newPassword === currentPassword) {
    return res
      .status(400)
      .json({ error: "New password must differ from your current password." });
  }

  const userResult = await pool.query(
    `SELECT phone, password_hash FROM users WHERE id = $1`,
    [userId],
  );
  const user = userResult.rows[0];
  if (!user) {
    return res.status(404).json({ error: "User not found." });
  }
  if (!user.phone) {
    return res.status(400).json({ error: "No registered phone number found." });
  }

  const otpValid = await otpService.verifyOtp(user.phone, otp);
  if (!otpValid) {
    return res.status(400).json({ error: "Invalid or expired verification code." });
  }

  const currentMatches = await bcrypt.compare(currentPassword, user.password_hash);
  if (!currentMatches) {
    return res.status(400).json({ error: "Current password is incorrect." });
  }

  const newHash = await bcrypt.hash(newPassword, 10);
  await pool.query(`UPDATE users SET password_hash = $1 WHERE id = $2`, [newHash, userId]);

  return res.status(200).json({ message: "Password changed successfully." });
});

// ═══════════════════════════════════════════════════════════════════════
// 3. PHONE NUMBER MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════

// GET /settings/phone
exports.getPhones = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const result = await pool.query(
    `SELECT phone AS "primaryPhone", backup_phone AS "backupPhone"
       FROM users WHERE id = $1`,
    [userId],
  );
  if (result.rowCount === 0) {
    return res.status(404).json({ error: "User not found." });
  }
  return res.status(200).json(result.rows[0]);
});

// POST /settings/phone/otp/send
// body: { phone } — the *new* number being verified (primary or backup)
exports.sendPhoneOtp = asyncHandler(async (req, res) => {
  const { phone } = req.body;
  if (!phone?.trim()) {
    return res.status(400).json({ error: "Phone number is required." });
  }

  await otpService.sendSmsOtp(phone.trim());

  return res.status(200).json({ message: "Verification code sent." });
});

// PATCH /settings/phone/primary
// body: { phone, otp }
exports.updatePrimaryPhone = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { phone, otp } = req.body;

  if (!phone || !otp) {
    return res.status(400).json({ error: "Phone number and code are required." });
  }

  const otpValid = await otpService.verifyOtp(phone, otp);
  if (!otpValid) {
    return res.status(400).json({ error: "Invalid or expired verification code." });
  }

  await pool.query(`UPDATE users SET phone = $1 WHERE id = $2`, [phone, userId]);
  return res.status(200).json({ message: "Primary phone number updated." });
});

// PATCH /settings/phone/backup
// body: { phone, otp }
exports.updateBackupPhone = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { phone, otp } = req.body;

  if (!phone || !otp) {
    return res.status(400).json({ error: "Phone number and code are required." });
  }

  const otpValid = await otpService.verifyOtp(phone, otp);
  if (!otpValid) {
    return res.status(400).json({ error: "Invalid or expired verification code." });
  }

  await pool.query(`UPDATE users SET backup_phone = $1 WHERE id = $2`, [phone, userId]);
  return res.status(200).json({ message: "Backup phone number updated." });
});

// ═══════════════════════════════════════════════════════════════════════
// 4. LANGUAGE SETTINGS
// ═══════════════════════════════════════════════════════════════════════

const SUPPORTED_LANGUAGES = ["en", "zh"];

// PATCH /settings/language
// body: { language }
// ⚠️ UNVERIFIED: language_pref column not yet confirmed against neondb —
// no runtime error has been observed on this endpoint yet, but that could
// mean it's correct OR simply that it hasn't been exercised. Same caution
// applies to backup_phone, notify_upcoming_session, notify_session_reminder,
// notify_student_booking, notify_general_announcement below — none of
// these have thrown yet, but "hasn't thrown yet" is not the same as
// "confirmed correct," per this session's track record.
exports.updateLanguage = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { language } = req.body;

  if (!language || !SUPPORTED_LANGUAGES.includes(language)) {
    return res
      .status(400)
      .json({ error: `Language must be one of: ${SUPPORTED_LANGUAGES.join(", ")}.` });
  }

  await pool.query(`UPDATE users SET language_pref = $1 WHERE id = $2`, [language, userId]);
  return res.status(200).json({ message: "Language preference updated." });
});

// ═══════════════════════════════════════════════════════════════════════
// 5. NOTIFICATION SETTINGS (shared: student + teacher)
// ═══════════════════════════════════════════════════════════════════════

// GET /settings/notifications
exports.getNotificationPreferences = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const result = await pool.query(
    `SELECT notify_upcoming_session     AS "upcomingSession",
            notify_session_reminder     AS "sessionReminder",
            notify_student_booking      AS "studentBooking",
            notify_general_announcement AS "generalAnnouncement"
       FROM users WHERE id = $1`,
    [userId],
  );
  if (result.rowCount === 0) {
    return res.status(404).json({ error: "User not found." });
  }
  return res.status(200).json(result.rows[0]);
});

// PATCH /settings/notifications
// body: { upcomingSession?, sessionReminder?, studentBooking?, generalAnnouncement? }
// All fields optional — only the ones the caller sends get updated, so the
// same endpoint works for both the student screen (which only ever sends
// upcomingSession/sessionReminder) and the teacher screen (which also sends
// studentBooking/generalAnnouncement).
exports.updateNotificationPreferences = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { upcomingSession, sessionReminder, studentBooking, generalAnnouncement } = req.body;

  const fields = [];
  const values = [];
  let i = 1;

  const addField = (column, value) => {
    if (value === undefined) return;
    if (typeof value !== "boolean") {
      throw Object.assign(new Error(`${column} must be a boolean.`), { statusCode: 400 });
    }
    fields.push(`${column} = $${i++}`);
    values.push(value);
  };

  try {
    addField("notify_upcoming_session", upcomingSession);
    addField("notify_session_reminder", sessionReminder);
    addField("notify_student_booking", studentBooking);
    addField("notify_general_announcement", generalAnnouncement);
  } catch (e) {
    return res.status(e.statusCode || 400).json({ error: e.message });
  }

  if (fields.length === 0) {
    return res.status(400).json({ error: "At least one notification preference is required." });
  }

  values.push(userId);
  await pool.query(
    `UPDATE users SET ${fields.join(", ")} WHERE id = $${i}`,
    values,
  );

  return res.status(200).json({ message: "Notification preferences updated." });
});

// ═══════════════════════════════════════════════════════════════════════
// 6. HELP CENTER
// ═══════════════════════════════════════════════════════════════════════

// POST /settings/concerns
// body: { subject, message }
exports.submitConcern = asyncHandler(async (req, res) => {
  const userId = req.user.sub;
  const { subject, message } = req.body;

  if (!subject?.trim() || !message?.trim()) {
    return res.status(400).json({ error: "Subject and message are required." });
  }

  await pool.query(
    `INSERT INTO support_concerns (user_id, subject, message)
     VALUES ($1, $2, $3)`,
    [userId, subject.trim(), message.trim()],
  );

  return res
    .status(201)
    .json({ message: "Your message has been submitted. We'll be in touch soon." });
});