// src/controllers/notifications.controller.js
//
// In-app notification inbox (bell icon feed). Rows are inserted by
// announcements.controller.js's create() when an admin publishes — see
// notifyEligibleUsers() there. This controller only reads/acknowledges
// the authenticated user's own rows; nothing here writes notifications
// for another user, so no admin gate is needed on any of these routes.

const pool = require("../db/pool");

// ── GET /notifications ───────────────────────────────────────────────────
exports.list = async (req, res) => {
  const { limit = 30 } = req.query;
  try {
    const { rows } = await pool.query(
      `SELECT * FROM notifications
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [req.user.sub, Number(limit)],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch notifications" });
  }
};

// ── GET /notifications/unread-count ──────────────────────────────────────
exports.unreadCount = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND is_read = false`,
      [req.user.sub],
    );
    res.json({ count: rows[0].count });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch unread count" });
  }
};

// ── PATCH /notifications/:id/read ────────────────────────────────────────
exports.markRead = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE notifications SET is_read = true
       WHERE id = $1 AND user_id = $2
       RETURNING *`,
      [req.params.id, req.user.sub],
    );
    if (!rows.length) return res.status(404).json({ error: "Notification not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update notification" });
  }
};

// ── PATCH /notifications/read-all ────────────────────────────────────────
exports.markAllRead = async (req, res) => {
  try {
    await pool.query(
      `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
      [req.user.sub],
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update notifications" });
  }
};