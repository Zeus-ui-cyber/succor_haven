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
// ⚠️ FIXED: the previous "audit" comment here claimed `users.full_name is
// the real column` — that was checked against the LOCAL succor_haven
// Postgres instance, not neondb (the database this app's DATABASE_URL
// actually points to). Confirmed via runtime error: every registration
// attempt was failing with `column "full_name" does not exist` against
// neondb. The real columns are first_name / last_name, same as every
// other table. Still accepts firstName/lastName from the client — no
// Flutter changes needed — but now inserts them as separate columns
// instead of concatenating into a full_name string that has nowhere to go.

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

    // accepted but NOT persisted — no student_profiles table exists to
    // hold these. If you want them stored, tell me where (e.g. new columns
    // on users) and I'll add a migration + wire it up.
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
      [email, hash, firstName.trim(), lastName.trim(), role, phone || null],
    );

    const user = rows[0];

    // No student_profiles table — students don't get a profile row here.
    // Their credits/points start at 0 implicitly (no credits_ledger rows
    // yet), same convention as everywhere else in the codebase.

    if (role === "teacher") {
      await pool.query(
        `
        INSERT INTO teacher_profiles
        (
          user_id,
          bio,
          subjects
        )
        VALUES ($1,$2,$3)
        `,
        [user.id, bio || "", subjects || []],
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
// avatar_url comes through via `SELECT u.*` above (it lives on `users`,
// not `teacher_profiles` — confirmed in teachers.controller.js).

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