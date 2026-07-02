// src/services/otp.service.js
// Sends OTP via Twilio (SMS) or Nodemailer (email) and stores in DB.

const pool = require("../db/pool");
const nodemailer = require("nodemailer");
const twilio = require("twilio");
const crypto = require("crypto");

const EXPIRY_MINS = parseInt(process.env.OTP_EXPIRY_MINUTES || "10");

// ── Generate a 6-digit code ───────────────────────────────────────────────────
function generateCode() {
  return String(crypto.randomInt(100000, 999999));
}

// ── Save OTP to DB ────────────────────────────────────────────────────────────
async function saveOtp(target, code, type) {
  const expiresAt = new Date(Date.now() + EXPIRY_MINS * 60 * 1000);
  // Invalidate previous unused codes for this target
  await pool.query(
    `UPDATE otp_codes SET used = true WHERE target = $1 AND used = false`,
    [target],
  );
  await pool.query(
    `INSERT INTO otp_codes (target, code, type, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [target, code, type, expiresAt],
  );
}

// ── Verify OTP from DB ────────────────────────────────────────────────────────
async function verifyOtp(target, code) {
  const { rows } = await pool.query(
    `SELECT * FROM otp_codes
     WHERE target = $1 AND code = $2 AND used = false AND expires_at > NOW()
     ORDER BY created_at DESC LIMIT 1`,
    [target, code],
  );
  if (!rows.length) return false;
  await pool.query(`UPDATE otp_codes SET used = true WHERE id = $1`, [
    rows[0].id,
  ]);
  return true;
}

// ── Send SMS via Twilio ───────────────────────────────────────────────────────
async function sendSmsOtp(phone) {
  const code = generateCode();
  await saveOtp(phone, code, "sms");

  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER } =
    process.env;

  // Dev fallback: if Twilio isn't configured yet, log the code instead of
  // sending a real SMS. This branch becomes a no-op the moment all three
  // env vars are filled in with real Twilio credentials — safe to leave in.
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
    console.log(
      `📱 [DEV] SMS OTP for ${phone}: ${code} (Twilio not configured — code was not actually sent)`,
    );
    return true;
  }

  const client = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
  await client.messages.create({
    body: `Your Succor Haven verification code is: ${code}. Valid for ${EXPIRY_MINS} minutes.`,
    from: TWILIO_PHONE_NUMBER,
    to: phone,
  });
  return true;
}

// ── Send email OTP via Nodemailer ─────────────────────────────────────────────
async function sendEmailOtp(email) {
  const code = generateCode();
  await saveOtp(email, code, "email");

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || "587"),
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });

  await transporter.sendMail({
    from: `"Succor Haven" <${process.env.SMTP_USER}>`,
    to: email,
    subject: "Your Succor Haven verification code",
    html: `
      <div style="font-family:sans-serif;max-width:400px;margin:auto">
        <h2 style="color:#D64577">Succor Haven · 学习平台</h2>
        <p>Your one-time verification code is:</p>
        <h1 style="letter-spacing:8px;color:#7D002B">${code}</h1>
        <p style="color:#888">Valid for ${EXPIRY_MINS} minutes. Do not share this code.</p>
      </div>`,
  });
  return true;
}

module.exports = { sendSmsOtp, sendEmailOtp, verifyOtp };