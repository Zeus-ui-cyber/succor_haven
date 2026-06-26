// src/services/jwt.service.js
require("dotenv").config();
const jwt = require("jsonwebtoken");
const pool = require("../db/pool");
const crypto = require("crypto");

const SECRET = process.env.JWT_ACCESS_SECRET;
const ACCESS_EXPIRY = process.env.JWT_EXPIRES_IN || "15m";
const REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRES_IN || "7d";

function signAccess(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email },
    SECRET,
    { expiresIn: ACCESS_EXPIRY },
  );
}

async function issueRefreshToken(userId) {
  const token = crypto.randomBytes(64).toString("hex");
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
  await pool.query(
    `INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)`,
    [userId, token, expiresAt],
  );
  return token;
}

async function rotateRefreshToken(oldToken) {
  const { rows } = await pool.query(
    `SELECT * FROM refresh_tokens
     WHERE token = $1 AND expires_at > NOW()`,
    [oldToken],
  );
  if (!rows.length) throw new Error("Invalid or expired refresh token");

  // Delete old token (rotation — one-time use)
  await pool.query(`DELETE FROM refresh_tokens WHERE id = $1`, [rows[0].id]);

  // Fetch user
  const { rows: users } = await pool.query(
    `SELECT id, role, email FROM users WHERE id = $1`,
    [rows[0].user_id],
  );
  if (!users.length) throw new Error("User not found");

  const accessToken = signAccess(users[0]);
  const refreshToken = await issueRefreshToken(users[0].id);
  return { accessToken, refreshToken, user: users[0] };
}

function verifyAccess(token) {
  return jwt.verify(token, SECRET);
}

module.exports = {
  signAccess,
  issueRefreshToken,
  rotateRefreshToken,
  verifyAccess,
};
