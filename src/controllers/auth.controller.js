// src/controllers/auth.controller.js

const bcrypt = require("bcrypt");
const pool = require("../db/pool");
const otpSvc = require("../services/otp.service");
const jwtSvc = require("../services/jwt.service");

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function userPublic(user) {
  const { password_hash, ...publicUser } = user;
  return publicUser;
}

async function issueTokens(user) {
  const accessToken = jwtSvc.signAccess(user);
  const refreshToken = await jwtSvc.issueRefreshToken(user.id);

  return {
    accessToken,
    refreshToken,
    user: userPublic(user),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/register
// ─────────────────────────────────────────────────────────────────────────────
// FIX: the `users` table has separate `first_name` / `last_name` columns
// (see src/db/schema.sql), not a single `full_name` column. This previously
// destructured `fullName` from req.body and inserted it into a `full_name`
// column that doesn't exist — every registration (student self-signup, and
// previously teacher self-signup) was failing with a SQL error ("column
// full_name does not exist"). Now accepts firstName/lastName directly,
// matching what the Flutter side (AuthController.register()) actually sends.

exports.register = async (req, res) => {
  const {
    email,
    password,
    firstName,
    lastName,
    role,
    phone,

    // teacher fields
    bio,
    subjects,
    availability,

    // accepted but currently not persisted
    nativeLanguage,
    learningGoals,
    level,
  } = req.body;

  if (!["student", "teacher"].includes(role)) {
    return res.status(400).json({ error: "Invalid role" });
  }

  if (!email) {
    return res.status(400).json({ error: "Email required" });
  }

  if (!password) {
    return res.status(400).json({ error: "Password required" });
  }

  if (!firstName || !lastName) {
    return res.status(400).json({ error: "First and last name required" });
  }

  try {
    const hash = await bcrypt.hash(password, 10);

    const { rows } = await pool.query(
      `
      INSERT INTO users (
        email,
        password_hash,
        first_name,
        last_name,
        role,
        phone
      )
      VALUES ($1,$2,$3,$4,$5,$6)
      RETURNING *
      `,
      [email, hash, firstName, lastName, role, phone || null],
    );

    const user = rows[0];

    if (role === "student") {
      await pool.query(
        `
        INSERT INTO student_profiles
        (
          user_id,
          native_language,
          learning_goals,
          level
        )
        VALUES ($1,$2,$3,$4)
        `,
        [user.id, nativeLanguage || "", learningGoals || [], level || ""],
      );
    }

    if (role === "teacher") {
      await pool.query(
        `
        INSERT INTO teacher_profiles
        (
          user_id,
          bio,
          subjects,
          availability
        )
        VALUES ($1,$2,$3,$4)
        `,
        [user.id, bio || "", subjects || [], availability || []],
      );
    }

    res.status(201).json(await issueTokens(user));
  } catch (err) {
    console.error(err);

    if (err.code === "23505") {
      // Unique violation — could be email or phone depending on which
      // constraint fired. err.constraint gives the constraint name if you
      // want to disambiguate further later (e.g. 'users_phone_key').
      const field =
        err.constraint && err.constraint.includes("phone")
          ? "Phone number"
          : "Email";
      return res.status(409).json({
        error: `${field} already registered`,
      });
    }

    res.status(500).json({
      error: "Registration failed",
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/login
// ─────────────────────────────────────────────────────────────────────────────

exports.login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      error: "Credentials required",
    });
  }

  try {
    const { rows } = await pool.query(
      `SELECT u.*, tp.is_approved AS teacher_approved
       FROM users u
       LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE u.email = $1`,
      [email],
    );

    if (!rows.length) {
      return res.status(401).json({
        error: "Invalid credentials",
      });
    }

    const user = rows[0];

    const match = await bcrypt.compare(password, user.password_hash || "");

    if (!match) {
      return res.status(401).json({
        error: "Invalid credentials",
      });
    }

    res.json(await issueTokens(user));
  } catch (err) {
    console.error(err);

    res.status(500).json({
      error: "Login failed",
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/otp/send
// ─────────────────────────────────────────────────────────────────────────────

exports.sendOtp = async (req, res) => {
  const { target, type } = req.body;

  if (!target || !["email", "sms"].includes(type)) {
    return res.status(400).json({
      error: "target and type required",
    });
  }

  try {
    if (type === "sms") {
      await otpSvc.sendSmsOtp(target);
    } else {
      await otpSvc.sendEmailOtp(target);
    }

    res.json({
      message: "OTP sent",
    });
  } catch (err) {
    console.error(err);

    res.status(500).json({
      error: "Failed to send OTP",
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/otp/verify
// ─────────────────────────────────────────────────────────────────────────────

exports.verifyOtp = async (req, res) => {
  const { target, code, type } = req.body;

  if (!target || !code) {
    return res.status(400).json({
      error: "target and code required",
    });
  }

  try {
    const valid = await otpSvc.verifyOtp(target, code);

    if (!valid) {
      return res.status(401).json({
        error: "Invalid or expired OTP",
      });
    }

    // Look the user up by whichever field the OTP was sent to.
    const column = type === "sms" ? "phone" : "email";

    const { rows } = await pool.query(
      `SELECT u.*, tp.is_approved AS teacher_approved
       FROM users u
       LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE u.${column} = $1`,
      [target],
    );

    if (!rows.length) {
      return res.status(404).json({
        error: "No account found. Please register first.",
      });
    }

    res.json(await issueTokens(rows[0]));
  } catch (err) {
    console.error(err);

    res.status(500).json({
      error: "OTP verification failed",
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/refresh
// ─────────────────────────────────────────────────────────────────────────────

exports.refresh = async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({
      error: "refreshToken required",
    });
  }

  try {
    const result = await jwtSvc.rotateRefreshToken(refreshToken);
    res.json(result);
  } catch (err) {
    res.status(401).json({
      error: err.message,
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/logout
// ─────────────────────────────────────────────────────────────────────────────

exports.logout = async (req, res) => {
  const { refreshToken } = req.body;

  if (refreshToken) {
    await pool.query(`DELETE FROM refresh_tokens WHERE token = $1`, [
      refreshToken,
    ]);
  }

  res.json({
    message: "Logged out",
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /auth/me
// ─────────────────────────────────────────────────────────────────────────────

exports.me = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      SELECT
        u.*,

        COALESCE(credits.total, 0)::int AS credits,
        COALESCE(points.total, 0)::int AS points,

        tp.bio,
        tp.subjects,
        tp.availability,
        tp.credits_per_session,
        tp.is_approved AS teacher_approved,
        tp.rating,
        tp.total_sessions

      FROM users u

      LEFT JOIN teacher_profiles tp
        ON tp.user_id = u.id

      LEFT JOIN (
        SELECT
          user_id,
          SUM(amount)::int AS total
        FROM credits_ledger
        WHERE currency = 'credits'
        GROUP BY user_id
      ) credits
        ON credits.user_id = u.id

      LEFT JOIN (
        SELECT
          user_id,
          SUM(amount)::int AS total
        FROM credits_ledger
        WHERE currency = 'points'
        GROUP BY user_id
      ) points
        ON points.user_id = u.id

      WHERE u.id = $1
      `,
      [req.user.sub],
    );

    if (!rows.length) {
      return res.status(404).json({
        error: "User not found",
      });
    }

    res.json(userPublic(rows[0]));
  } catch (err) {
    console.error(err);

    res.status(500).json({
      error: "Failed to fetch profile",
    });
  }
};
