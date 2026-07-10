// src/controllers/milestones.controller.js
//
// ⚠️ REPLACES a previous version of this file that was an accidental
// duplicate of creditRules.controller.js — it read/wrote the credit_rules
// table under the milestones.* export names. Nothing in the app currently
// calls GET/POST/PATCH/DELETE /admin/milestones except the admin-only
// Milestone Rewards screen (lib/features/dashboard/admin/
// milestone_rewards_screen.dart), so that bug never surfaced as a visible
// crash — but every call would have been silently reading/writing
// credit_rules instead of milestones. Rewritten from scratch to match the
// milestone JSON shape defined in that screen's header comment, backed by
// migration_002.sql's real `milestones` table.

const pool = require("../db/pool");

const VALID_METRICS = [
  "sessions_completed",
  "sessions_booked",
  "referrals",
  "streak_days",
  "credits_spent",
];
const VALID_APPLIES_TO = ["student", "teacher", "all"];

function validateMilestoneBody(body, { partial = false } = {}) {
  const {
    title,
    threshold,
    metric,
    reward_credits,
    reward_points,
    applies_to,
  } = body;

  if (!partial || title !== undefined) {
    if (!title || !String(title).trim()) return "title is required.";
  }
  if (!partial || threshold !== undefined) {
    if (!Number.isInteger(Number(threshold)) || Number(threshold) <= 0)
      return "threshold must be a positive integer.";
  }
  if (metric !== undefined && !VALID_METRICS.includes(metric)) {
    return `metric must be one of: ${VALID_METRICS.join(", ")}.`;
  }
  if (
    reward_credits !== undefined &&
    (!Number.isInteger(Number(reward_credits)) || Number(reward_credits) < 0)
  ) {
    return "reward_credits must be a non-negative integer.";
  }
  if (
    reward_points !== undefined &&
    (!Number.isInteger(Number(reward_points)) || Number(reward_points) < 0)
  ) {
    return "reward_points must be a non-negative integer.";
  }
  if (applies_to !== undefined && !VALID_APPLIES_TO.includes(applies_to)) {
    return `applies_to must be one of: ${VALID_APPLIES_TO.join(", ")}.`;
  }
  return null;
}

// ── GET /admin/milestones ─────────────────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM milestones ORDER BY threshold ASC, created_at DESC`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch milestones" });
  }
};

// ── POST /admin/milestones ────────────────────────────────────────────────────
exports.create = async (req, res) => {
  const validationError = validateMilestoneBody(req.body);
  if (validationError) return res.status(400).json({ error: validationError });

  const {
    title,
    title_cn,
    description,
    emoji,
    threshold,
    metric = "sessions_completed",
    reward_credits = 0,
    reward_points = 0,
    applies_to = "all",
    is_active = true,
  } = req.body;

  try {
    const { rows } = await pool.query(
      `INSERT INTO milestones
         (title, title_cn, description, emoji, threshold, metric,
          reward_credits, reward_points, applies_to, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        title.trim(),
        title_cn || "",
        description || "",
        emoji || "🏅",
        threshold,
        metric,
        reward_credits,
        reward_points,
        applies_to,
        is_active,
      ],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create milestone" });
  }
};

// ── PATCH /admin/milestones/:id ───────────────────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;

  const validationError = validateMilestoneBody(req.body, { partial: true });
  if (validationError) return res.status(400).json({ error: validationError });

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM milestones WHERE id = $1`,
      [id],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Milestone not found" });
    const e = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE milestones
       SET title=$1, title_cn=$2, description=$3, emoji=$4, threshold=$5,
           metric=$6, reward_credits=$7, reward_points=$8, applies_to=$9,
           is_active=$10, updated_at=now()
       WHERE id=$11
       RETURNING *`,
      [
        req.body.title ?? e.title,
        req.body.title_cn ?? e.title_cn,
        req.body.description ?? e.description,
        req.body.emoji ?? e.emoji,
        req.body.threshold ?? e.threshold,
        req.body.metric ?? e.metric,
        req.body.reward_credits ?? e.reward_credits,
        req.body.reward_points ?? e.reward_points,
        req.body.applies_to ?? e.applies_to,
        req.body.is_active ?? e.is_active,
        id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update milestone" });
  }
};

// ── DELETE /admin/milestones/:id ──────────────────────────────────────────────
exports.remove = async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM milestones WHERE id = $1`,
      [req.params.id],
    );
    if (!rowCount)
      return res.status(404).json({ error: "Milestone not found" });
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete milestone" });
  }
};
