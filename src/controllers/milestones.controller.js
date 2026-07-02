// src/controllers/creditRules.controller.js
const pool = require("../db/pool");

const VALID_ACTIONS = ["purchase", "referral", "bonus", "session_reward", "other"];

// ── GET /admin/credit-rules ───────────────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM credit_rules ORDER BY created_at DESC`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch credit rules" });
  }
};

// ── POST /admin/credit-rules ──────────────────────────────────────────────────
exports.create = async (req, res) => {
  const {
    label,
    label_cn,
    description,
    action,
    credits_awarded,
    multiplier,
    is_active,
  } = req.body;

  if (!label)
    return res.status(400).json({ error: "label is required" });
  if (!credits_awarded || Number(credits_awarded) <= 0)
    return res.status(400).json({ error: "credits_awarded must be a positive number" });
  if (action && !VALID_ACTIONS.includes(action))
    return res.status(400).json({ error: "Invalid action type" });

  try {
    const { rows } = await pool.query(
      `INSERT INTO credit_rules
         (label, label_cn, description, action, credits_awarded, multiplier, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [
        label,
        label_cn || "",
        description || "",
        action || "other",
        credits_awarded,
        multiplier ?? 1,
        is_active ?? true,
      ],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create credit rule" });
  }
};

// ── PATCH /admin/credit-rules/:id ─────────────────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;
  const {
    label,
    label_cn,
    description,
    action,
    credits_awarded,
    multiplier,
    is_active,
  } = req.body;

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM credit_rules WHERE id = $1`,
      [id],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Credit rule not found" });
    const e = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE credit_rules
       SET label=$1, label_cn=$2, description=$3, action=$4,
           credits_awarded=$5, multiplier=$6, is_active=$7
       WHERE id=$8
       RETURNING *`,
      [
        label         ?? e.label,
        label_cn      ?? e.label_cn,
        description   ?? e.description,
        action        ?? e.action,
        credits_awarded ?? e.credits_awarded,
        multiplier    ?? e.multiplier,
        is_active     ?? e.is_active,
        id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update credit rule" });
  }
};

// ── DELETE /admin/credit-rules/:id ────────────────────────────────────────────
exports.remove = async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM credit_rules WHERE id = $1`,
      [req.params.id],
    );
    if (!rowCount) return res.status(404).json({ error: "Credit rule not found" });
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete credit rule" });
  }
};