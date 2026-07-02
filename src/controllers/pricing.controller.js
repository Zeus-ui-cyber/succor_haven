// src/controllers/pricing.controller.js
const pool = require("../db/pool");

// ── GET /admin/pricing ────────────────────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM session_pricing ORDER BY duration_mins ASC`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch session pricing" });
  }
};

// ── POST /admin/pricing ───────────────────────────────────────────────────────
exports.create = async (req, res) => {
  const { label, label_cn, duration_mins, credits_cost, is_active } = req.body;

  if (!duration_mins || Number(duration_mins) <= 0)
    return res.status(400).json({ error: "duration_mins must be a positive number" });
  if (!credits_cost || Number(credits_cost) <= 0)
    return res.status(400).json({ error: "credits_cost must be a positive number" });

  try {
    const { rows } = await pool.query(
      `INSERT INTO session_pricing
         (label, label_cn, duration_mins, credits_cost, is_active)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING *`,
      [
        label     || `${duration_mins} min`,
        label_cn  || "",
        duration_mins,
        credits_cost,
        is_active ?? true,
      ],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create session pricing" });
  }
};

// ── PATCH /admin/pricing/:id ──────────────────────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;
  const { label, label_cn, duration_mins, credits_cost, is_active } = req.body;

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM session_pricing WHERE id = $1`,
      [id],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Pricing not found" });
    const e = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE session_pricing
       SET label=$1, label_cn=$2, duration_mins=$3, credits_cost=$4, is_active=$5
       WHERE id=$6
       RETURNING *`,
      [
        label         ?? e.label,
        label_cn      ?? e.label_cn,
        duration_mins ?? e.duration_mins,
        credits_cost  ?? e.credits_cost,
        is_active     ?? e.is_active,
        id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update session pricing" });
  }
};

// ── DELETE /admin/pricing/:id ─────────────────────────────────────────────────
exports.remove = async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM session_pricing WHERE id = $1`,
      [req.params.id],
    );
    if (!rowCount) return res.status(404).json({ error: "Pricing not found" });
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete session pricing" });
  }
};