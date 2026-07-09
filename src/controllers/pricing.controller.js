// src/controllers/pricing.controller.js
//
// ⚠️ REWRITTEN: this previously queried a table called `session_pricing`
// with columns (label, label_cn, duration_mins, credits_cost) — a
// completely different schema from the one the rest of the app actually
// uses. The real table, created by 0001_credit_rules_and_pricing.sql and
// already relied on by bookings.controller.js and
// session_pricing_screen.dart, is `pricing` with columns (name, name_cn,
// session_type, credits_per_session, sessions_in_package, total_credits,
// discount_pct, applies_to, is_active). This file was never connected to
// that table — every request here would either 500 or return the wrong
// shape entirely. Rewritten to match.
//
// Pricing model confirmed as TIER-based, not per-teacher: cost and
// point-earn rate come from the pricing tier (session_type), not from
// which teacher taught the session. See bookings.controller.js create()
// and complete().
//
// ⚠️ NUMERIC CAST: discount_pct is NUMERIC(5,2) in Postgres. node-postgres
// returns NUMERIC columns as strings by default (to avoid float precision
// loss), not JS numbers. Cast to float8 in every query below so the JSON
// response actually contains a number — otherwise Flutter's
// `t['discount_pct'] as num?` throws a runtime cast error the moment any
// tier has a non-null discount.

const pool = require("../db/pool");

const SESSION_TYPES = ["standard", "trial", "group", "intensive"];
const APPLIES_TO = ["student", "teacher", "all"];

function validatePricingBody(body, { partial = false } = {}) {
  const {
    name,
    session_type,
    credits_per_session,
    sessions_in_package,
    discount_pct,
    applies_to,
  } = body;

  if (!partial || name !== undefined) {
    if (!name || !String(name).trim())
      return "name is required.";
  }
  if (!partial || session_type !== undefined) {
    if (!SESSION_TYPES.includes(session_type))
      return `session_type must be one of: ${SESSION_TYPES.join(", ")}.`;
  }
  if (!partial || credits_per_session !== undefined) {
    if (!Number.isInteger(Number(credits_per_session)) || Number(credits_per_session) < 0)
      return "credits_per_session must be a non-negative integer.";
  }
  if (sessions_in_package !== undefined) {
    if (!Number.isInteger(Number(sessions_in_package)) || Number(sessions_in_package) < 1)
      return "sessions_in_package must be a positive integer.";
  }
  if (discount_pct !== undefined) {
    const d = Number(discount_pct);
    if (!Number.isFinite(d) || d < 0 || d > 100)
      return "discount_pct must be between 0 and 100.";
  }
  if (!partial || applies_to !== undefined) {
    if (!APPLIES_TO.includes(applies_to))
      return `applies_to must be one of: ${APPLIES_TO.join(", ")}.`;
  }
  return null;
}

// Falls back to computing total_credits server-side if the client didn't
// send a sane value — same formula the Flutter sheet's _autoTotal() uses,
// kept in sync here as a safety net rather than trusting the client blindly.
function computeTotalCredits({ credits_per_session, sessions_in_package = 1, discount_pct = 0, total_credits }) {
  if (Number.isInteger(Number(total_credits)) && Number(total_credits) >= 0) {
    return Number(total_credits);
  }
  const raw = Number(credits_per_session) * Number(sessions_in_package);
  return Math.round(raw * (1 - Number(discount_pct) / 100));
}

// ── GET /admin/pricing ────────────────────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, name_cn, session_type, credits_per_session,
              sessions_in_package, total_credits,
              discount_pct::float8 AS discount_pct,
              applies_to, is_active, created_at, updated_at
       FROM pricing
       ORDER BY session_type ASC, credits_per_session ASC`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch pricing" });
  }
};

// ── POST /admin/pricing ───────────────────────────────────────────────────────
exports.create = async (req, res) => {
  const validationError = validatePricingBody(req.body);
  if (validationError) return res.status(400).json({ error: validationError });

  const {
    name,
    name_cn,
    session_type,
    credits_per_session,
    sessions_in_package = 1,
    discount_pct = 0,
    applies_to = "all",
    is_active = true,
  } = req.body;

  const total_credits = computeTotalCredits({
    credits_per_session,
    sessions_in_package,
    discount_pct,
    total_credits: req.body.total_credits,
  });

  try {
    const { rows } = await pool.query(
      `INSERT INTO pricing
         (name, name_cn, session_type, credits_per_session,
          sessions_in_package, total_credits, discount_pct, applies_to, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING id, name, name_cn, session_type, credits_per_session,
                 sessions_in_package, total_credits,
                 discount_pct::float8 AS discount_pct,
                 applies_to, is_active, created_at, updated_at`,
      [
        name.trim(),
        name_cn || "",
        session_type,
        credits_per_session,
        sessions_in_package,
        total_credits,
        discount_pct,
        applies_to,
        is_active,
      ],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create pricing tier" });
  }
};

// ── PATCH /admin/pricing/:id ──────────────────────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;

  const validationError = validatePricingBody(req.body, { partial: true });
  if (validationError) return res.status(400).json({ error: validationError });

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM pricing WHERE id = $1`,
      [id],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Pricing tier not found" });
    const e = existingRows[0];

    const merged = {
      name: req.body.name ?? e.name,
      name_cn: req.body.name_cn ?? e.name_cn,
      session_type: req.body.session_type ?? e.session_type,
      credits_per_session: req.body.credits_per_session ?? e.credits_per_session,
      sessions_in_package: req.body.sessions_in_package ?? e.sessions_in_package,
      discount_pct: req.body.discount_pct ?? e.discount_pct,
      applies_to: req.body.applies_to ?? e.applies_to,
      is_active: req.body.is_active ?? e.is_active,
    };

    const total_credits = computeTotalCredits({
      ...merged,
      total_credits: req.body.total_credits,
    });

    const { rows } = await pool.query(
      `UPDATE pricing
       SET name=$1, name_cn=$2, session_type=$3, credits_per_session=$4,
           sessions_in_package=$5, total_credits=$6, discount_pct=$7,
           applies_to=$8, is_active=$9, updated_at=now()
       WHERE id=$10
       RETURNING id, name, name_cn, session_type, credits_per_session,
                 sessions_in_package, total_credits,
                 discount_pct::float8 AS discount_pct,
                 applies_to, is_active, created_at, updated_at`,
      [
        merged.name,
        merged.name_cn,
        merged.session_type,
        merged.credits_per_session,
        merged.sessions_in_package,
        total_credits,
        merged.discount_pct,
        merged.applies_to,
        merged.is_active,
        id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update pricing tier" });
  }
};

// ── DELETE /admin/pricing/:id ─────────────────────────────────────────────────
// ⚠️ NOTE: no guard against deleting a tier that existing bookings still
// reference via bookings.pricing_id. bookings.controller.js's create()
// checks is_active at booking time, but historical bookings keep pointing
// at pricing_id after deletion — that FK isn't enforced with ON DELETE
// here (check your migration for pricing_id's foreign key behavior). If
// it's a plain FK with no ON DELETE clause, deleting a tier with existing
// bookings will throw a foreign-key-violation (code 23503) instead of a
// clean error message. Not fixed here since I don't have that FK
// definition in front of me — flagging in case you hit it.
exports.remove = async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM pricing WHERE id = $1`,
      [req.params.id],
    );
    if (!rowCount) return res.status(404).json({ error: "Pricing tier not found" });
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    if (err.code === "23503") {
      return res.status(409).json({
        error: "This tier is referenced by existing bookings and cannot be deleted.",
      });
    }
    res.status(500).json({ error: "Failed to delete pricing tier" });
  }
};