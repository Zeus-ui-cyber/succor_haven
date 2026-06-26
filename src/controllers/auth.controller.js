// src/controllers/auth.controller.js
const bcrypt = require("bcrypt");
const pool = require("../db/pool");
const otpSvc = require("../services/otp.service");
const jwtSvc = require("../services/jwt.service");

// ── helpers ───────────────────────────────────────────────────────────────────
function userPublic(u) {
  const { password_hash, ...pub } = u;
  return pub;
}

async function issueTokens(user) {
  const accessToken = jwtSvc.signAccess(user);
  const refreshToken = await jwtSvc.issueRefreshToken(user.id);
  return { accessToken, refreshToken, user: userPublic(user) };
}

// ── POST /auth/register ───────────────────────────────────────────────────────
exports.register = async (req, res) => {
  const {
    email,
    phone,
    password,
    firstName,
    lastName,
    role,
    // teacher fields
    bio,
    subjects,
    creditsPerSession,
    availability,
    // student fields
    nativeLanguage,
    learningGoals,
    level,
  } = req.body;

  if (!["student", "teacher"].includes(role))
    return res.status(400).json({ error: "Invalid role" });
  if (!email && !phone)
    return res.status(400).json({ error: "Email or phone required" });
  if (!password) return res.status(400).json({ error: "Password required" });

  try {
    const hash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      `INSERT INTO users (email, phone, password_hash, first_name, last_name, role)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [email || null, phone || null, hash, firstName, lastName, role],
    );
    const user = rows[0];

    // Create role profile
    if (role === "teacher") {
      await pool.query(
        `INSERT INTO teacher_profiles
           (user_id, bio, subjects, availability, credits_per_session)
         VALUES ($1,$2,$3,$4,$5)`,
        [
          user.id,
          bio || "",
          subjects || [],
          availability || [],
          creditsPerSession || 6,
        ],
      );
    } else {
      await pool.query(
        `INSERT INTO student_profiles
           (user_id, native_language, learning_goals, level)
         VALUES ($1,$2,$3,$4)`,
        [user.id, nativeLanguage || "", learningGoals || [], level || ""],
      );
    }

    res.status(201).json(await issueTokens(user));
  } catch (err) {
    if (err.code === "23505")
      // unique violation
      return res
        .status(409)
        .json({ error: "Email or phone already registered" });
    console.error(err);
    res.status(500).json({ error: "Registration failed" });
  }
};

// ── POST /auth/login ──────────────────────────────────────────────────────────
exports.login = async (req, res) => {
  const { email, phone, password } = req.body;
  if ((!email && !phone) || !password)
    return res.status(400).json({ error: "Credentials required" });

  try {
    const field = email ? "email" : "phone";
    const value = email || phone;
    const { rows } = await pool.query(
      `SELECT * FROM users WHERE ${field} = $1 AND is_active = true`,
      [value],
    );
    if (!rows.length)
      return res.status(401).json({ error: "Invalid credentials" });

    const user = rows[0];
    const match = await bcrypt.compare(password, user.password_hash || "");
    if (!match) return res.status(401).json({ error: "Invalid credentials" });

    res.json(await issueTokens(user));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Login failed" });
  }
};

// ── POST /auth/otp/send ───────────────────────────────────────────────────────
exports.sendOtp = async (req, res) => {
  const { target, type } = req.body; // type: 'email' | 'sms'
  if (!target || !["email", "sms"].includes(type))
    return res.status(400).json({ error: "target and type required" });

  try {
    if (type === "sms") await otpSvc.sendSmsOtp(target);
    else await otpSvc.sendEmailOtp(target);
    res.json({ message: "OTP sent" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to send OTP" });
  }
};

// ── POST /auth/otp/verify ─────────────────────────────────────────────────────
exports.verifyOtp = async (req, res) => {
  const { target, code, type } = req.body;
  if (!target || !code)
    return res.status(400).json({ error: "target and code required" });

  try {
    const valid = await otpSvc.verifyOtp(target, code);
    if (!valid)
      return res.status(401).json({ error: "Invalid or expired OTP" });

    // Find or auto-create user
    const field = type === "sms" ? "phone" : "email";
    let { rows } = await pool.query(
      `SELECT * FROM users WHERE ${field} = $1 AND is_active = true`,
      [target],
    );
    if (!rows.length)
      return res
        .status(404)
        .json({ error: "No account found. Please register first." });

    res.json(await issueTokens(rows[0]));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "OTP verification failed" });
  }
};

// ── POST /auth/refresh ────────────────────────────────────────────────────────
exports.refresh = async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken)
    return res.status(400).json({ error: "refreshToken required" });
  try {
    const result = await jwtSvc.rotateRefreshToken(refreshToken);
    res.json(result);
  } catch (err) {
    res.status(401).json({ error: err.message });
  }
};

// ── POST /auth/logout ─────────────────────────────────────────────────────────
exports.logout = async (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) {
    await pool.query(`DELETE FROM refresh_tokens WHERE token = $1`, [
      refreshToken,
    ]);
  }
  res.json({ message: "Logged out" });
};

// ── GET /auth/me ──────────────────────────────────────────────────────────────
exports.me = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT u.*,
         sp.credits, sp.points, sp.native_language, sp.learning_goals, sp.level,
         tp.bio, tp.subjects, tp.availability, tp.credits_per_session,
         tp.is_approved, tp.rating, tp.total_sessions
       FROM users u
       LEFT JOIN student_profiles sp ON sp.user_id = u.id
       LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
       WHERE u.id = $1`,
      [req.user.sub],
    );
    if (!rows.length) return res.status(404).json({ error: "User not found" });
    res.json(userPublic(rows[0]));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch profile" });
  }
};
