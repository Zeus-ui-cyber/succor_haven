// src/middleware/auth.middleware.js
const { verifyAccess } = require("../services/jwt.service");
const pool = require("../db/pool");

function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res
      .status(401)
      .json({ error: "Missing or invalid Authorization header" });
  }
  try {
    req.user = verifyAccess(header.slice(7));
    next();
  } catch {
    res.status(401).json({ error: "Token expired or invalid" });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ error: "Forbidden" });
    }
    next();
  };
}

// Blocks teacher-only actions until the admin has approved their profile.
// Non-teachers (e.g. admins hitting the same route) pass through untouched.
// Use this AFTER authenticate (and typically after requireRole) on any
// teacher route that should be unavailable while pending review — e.g.
// viewing/managing bookings — but NOT on /teachers/profile, since teachers
// need to be able to complete their profile while awaiting approval.
async function requireApprovedTeacher(req, res, next) {
  if (req.user?.role !== "teacher") return next();
  try {
    const { rows } = await pool.query(
      `SELECT is_approved FROM teacher_profiles WHERE user_id = $1`,
      [req.user.sub],
    );
    if (!rows.length || !rows[0].is_approved) {
      return res.status(403).json({
        error: "Your teacher account is pending admin approval.",
        code: "TEACHER_NOT_APPROVED",
      });
    }
    next();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to verify approval status" });
  }
}

module.exports = { authenticate, requireRole, requireApprovedTeacher };