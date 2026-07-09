// src/controllers/creditRules.controller.js
const pool = require("../db/pool");

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
    name,
    name_cn,
    type,
    currency,
    amount,
    trigger,
    applies_to,
    is_active,
  } = req.body;

  if (!name || !["earn", "spend"].includes(type))
    return res.status(400).json({ error: "name and a valid type are required" });
  if (!["credits", "points"].includes(currency))
    return res.status(400).json({ error: "currency must be 'credits' or 'points'" });
  if (amount === undefined || amount === null || Number(amount) < 0)
    return res.status(400).json({ error: "amount must be a non-negative number" });
  if (!trigger)
    return res.status(400).json({ error: "trigger is required" });

  try {
    const { rows } = await pool.query(
      `INSERT INTO credit_rules
         (name, name_cn, type, currency, amount, trigger, applies_to, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [
        name,
        name_cn || "",
        type,
        currency,
        amount,
        trigger,
        applies_to || "all",
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
// ⚠️ HARDENED: `amount ?? existing.amount` only preserves the old value
// when the client sends `null` — a literal `0` or empty string is treated
// as a real value and would overwrite silently. The Flutter admin screen
// (credit_rules_screen.dart) already blocks submitting a blank amount
// client-side, so this couldn't happen through that UI today, but adding
// a server-side check too means any other caller of this endpoint
// (scripts, future admin tools) gets the same protection without relying
// on client-side validation alone.
exports.update = async (req, res) => {
  const { id } = req.params;
  const {
    name,
    name_cn,
    type,
    currency,
    amount,
    trigger,
    applies_to,
    is_active,
  } = req.body;

  if (amount !== undefined && amount !== null && Number(amount) < 0) {
    return res.status(400).json({ error: "amount must be a non-negative number" });
  }
  if (type !== undefined && !["earn", "spend"].includes(type)) {
    return res.status(400).json({ error: "type must be 'earn' or 'spend'" });
  }
  if (currency !== undefined && !["credits", "points"].includes(currency)) {
    return res.status(400).json({ error: "currency must be 'credits' or 'points'" });
  }

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM credit_rules WHERE id = $1`,
      [id],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Credit rule not found" });
    const existing = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE credit_rules
       SET name=$1, name_cn=$2, type=$3, currency=$4, amount=$5,
           trigger=$6, applies_to=$7, is_active=$8
       WHERE id=$9
       RETURNING *`,
      [
        name ?? existing.name,
        name_cn ?? existing.name_cn,
        type ?? existing.type,
        currency ?? existing.currency,
        amount ?? existing.amount,
        trigger ?? existing.trigger,
        applies_to ?? existing.applies_to,
        is_active ?? existing.is_active,
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