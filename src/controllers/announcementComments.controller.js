// src/controllers/announcementComments.controller.js
//
// Threaded comments/replies on announcements. Only usable when the parent
// announcement has comments_enabled = true (admin toggles this per
// announcement in announcements.controller.js's create/update). One level
// of nesting: a comment's parent_comment_id points at a top-level comment;
// replies-to-replies collapse under the original top-level comment on the
// client rather than growing a deeper tree, same as most lightweight
// comment UIs (Instagram, YouTube).
//
// user_id is UUID — same users.id convention as every other controller
// touching announcements (see announcements.controller.js's header note,
// confirmed directly against the live Neon database).

const pool = require("../db/pool");

const COMMENT_JOIN_SELECT = `
  c.*,
  (u.first_name || ' ' || u.last_name) AS user_name,
  u.role AS user_role
`;

// ── GET /announcements/:id/comments ─────────────────────────────────────────
exports.list = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT ${COMMENT_JOIN_SELECT}
       FROM announcement_comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.announcement_id = $1
       ORDER BY c.created_at ASC`,
      [req.params.id],
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch comments" });
  }
};

// ── POST /announcements/:id/comments ────────────────────────────────────────
// body: { body: string, parentCommentId?: uuid }
exports.create = async (req, res) => {
  const { id: announcementId } = req.params;
  const { body, parentCommentId } = req.body;

  if (!body || !String(body).trim()) {
    return res.status(400).json({ error: "Comment body is required." });
  }

  try {
    const { rows: annRows } = await pool.query(
      `SELECT comments_enabled FROM announcements WHERE id = $1`,
      [announcementId],
    );
    if (!annRows.length) return res.status(404).json({ error: "Announcement not found" });
    if (!annRows[0].comments_enabled) {
      return res.status(403).json({ error: "Comments are disabled for this announcement." });
    }

    if (parentCommentId) {
      const { rows: parentRows } = await pool.query(
        `SELECT id FROM announcement_comments WHERE id = $1 AND announcement_id = $2`,
        [parentCommentId, announcementId],
      );
      if (!parentRows.length) {
        return res.status(400).json({ error: "parentCommentId does not belong to this announcement." });
      }
    }

    const { rows } = await pool.query(
      `INSERT INTO announcement_comments (announcement_id, user_id, parent_comment_id, body)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [announcementId, req.user.sub, parentCommentId || null, String(body).trim()],
    );

    const { rows: joined } = await pool.query(
      `SELECT ${COMMENT_JOIN_SELECT}
       FROM announcement_comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.id = $1`,
      [rows[0].id],
    );

    res.status(201).json(joined[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to post comment" });
  }
};

// ── DELETE /announcements/comments/:commentId — author or admin only ───────
exports.remove = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM announcement_comments WHERE id = $1`,
      [req.params.commentId],
    );
    if (!rows.length) return res.status(404).json({ error: "Comment not found" });
    const comment = rows[0];

    const isOwner = String(comment.user_id) === String(req.user.sub);
    if (!isOwner && req.user.role !== "admin") {
      return res.status(403).json({ error: "You can only delete your own comments." });
    }

    await pool.query(`DELETE FROM announcement_comments WHERE id = $1`, [req.params.commentId]);
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete comment" });
  }
};