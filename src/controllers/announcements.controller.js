// src/controllers/announcements.controller.js
//
// Admin Announcement & Information Center.
//
// Visibility model: an announcement's `visibility` column determines who
// sees it — 'everyone' | 'students' | 'teachers' | 'year_level' | 'section'
// | 'subject' | 'individual_teacher'. For the latter four, `target_value`
// holds the specific match (a year_level string, section string, subject
// string, or a teacher's user id as text). Filtering happens server-side
// in list() based on the requesting user's role and (for students)
// course/year_level columns on `users` — confirmed to exist there this
// session (studentsAdmin.controller.js already reads u.course, u.year_level).
//
// req.user.sub is the authenticated user's id. users.id is UUID —
// confirmed directly against the live Neon database (`SELECT data_type
// FROM information_schema.columns WHERE table_name = 'users' AND
// column_name = 'id'` returned `uuid`). Every prior claim in this
// codebase that it was INTEGER (0005_modules.sql, modules.controller.js,
// lib/models/module.dart, and this file's own original comment) was
// wrong and had never actually been checked against a real database.
// created_by / user_id columns here are UUID to match.

const fs = require("fs");
const path = require("path");
const pool = require("../db/pool");

const CATEGORIES = [
  "announcement", "event", "activity", "resource", "achievement",
  "teacher_update", "student_update", "module", "emergency", "tip",
];
const PRIORITIES = ["normal", "important", "critical"];
const VISIBILITIES = [
  "everyone", "students", "teachers", "year_level",
  "section", "subject", "individual_teacher",
];

function validateBody(body, { partial = false } = {}) {
  const { title, description, category, priority, visibility } = body;

  if (!partial || title !== undefined) {
    if (!title || !String(title).trim()) return "title is required.";
  }
  if (!partial || description !== undefined) {
    if (!description || !String(description).trim()) return "description is required.";
  }
  if (category !== undefined && !CATEGORIES.includes(category)) {
    return `category must be one of: ${CATEGORIES.join(", ")}.`;
  }
  if (priority !== undefined && !PRIORITIES.includes(priority)) {
    return `priority must be one of: ${PRIORITIES.join(", ")}.`;
  }
  if (visibility !== undefined && !VISIBILITIES.includes(visibility)) {
    return `visibility must be one of: ${VISIBILITIES.join(", ")}.`;
  }
  if (
    visibility &&
    ["year_level", "section", "subject", "individual_teacher"].includes(visibility) &&
    !body.targetValue
  ) {
    return `targetValue is required when visibility is "${visibility}".`;
  }
  return null;
}

// Builds the WHERE clause + params restricting an announcement list to
// what the requesting user is actually allowed to see. Admins bypass this
// entirely (they see everything, including archived, via adminList).
function buildVisibilityFilter(user, params) {
  const clauses = [`a.visibility = 'everyone'`];

  if (user.role === "student") {
    clauses.push(`a.visibility = 'students'`);
    if (user.course) {
      params.push(user.course);
      clauses.push(`(a.visibility = 'subject' AND a.target_value = $${params.length})`);
    }
    if (user.year_level) {
      params.push(user.year_level);
      clauses.push(`(a.visibility = 'year_level' AND a.target_value = $${params.length})`);
    }
    // 'section' has no confirmed column on users yet — omitted rather
    // than guessing at a field name. Add once confirmed.
  }

  if (user.role === "teacher") {
    clauses.push(`a.visibility = 'teachers'`);
    params.push(String(user.id));
    clauses.push(`(a.visibility = 'individual_teacher' AND a.target_value = $${params.length})`);
  }

  return `(${clauses.join(" OR ")})`;
}

const ADMIN_JOIN_SELECT = `
  a.*,
  (u.first_name || ' ' || u.last_name) AS created_by_name,
  (SELECT COUNT(*) FROM announcement_comments cc WHERE cc.announcement_id = a.id)::int AS comment_count
`;

// Reverse of buildVisibilityFilter — given a just-published announcement's
// visibility/target_value, finds which users should be notified. Mirrors
// the same role/course/year_level rules so a user is notified if and only
// if they'd actually see the announcement in list().
async function getEligibleUserIds(visibility, targetValue) {
  switch (visibility) {
    case "everyone":
      return pool.query(`SELECT id, role FROM users WHERE role IN ('student', 'teacher')`);
    case "students":
      return pool.query(`SELECT id, role FROM users WHERE role = 'student'`);
    case "teachers":
      return pool.query(`SELECT id, role FROM users WHERE role = 'teacher'`);
    case "year_level":
      return pool.query(
        `SELECT id, role FROM users WHERE role = 'student' AND year_level = $1`,
        [targetValue],
      );
    case "subject":
      return pool.query(
        `SELECT id, role FROM users WHERE role = 'student' AND course = $1`,
        [targetValue],
      );
    case "individual_teacher":
      // users.id is UUID, not INTEGER — Number(targetValue) here used to
      // silently produce NaN and match no one. targetValue is already the
      // teacher's UUID as text (see buildVisibilityFilter's matching
      // String(user.id) comparison above), so pass it through as-is.
      return pool.query(
        `SELECT id, role FROM users WHERE role = 'teacher' AND id = $1`,
        [targetValue],
      );
    default:
      // 'section' has no confirmed column on users yet, same omission as
      // buildVisibilityFilter above — no one gets notified rather than
      // guessing at a field name.
      return { rows: [] };
  }
}

// Best-effort — a notification fan-out failure should never fail the
// announcement creation itself, so this is never awaited from inside the
// same try/catch that responds to the admin's POST.
async function notifyEligibleUsers(announcement) {
  try {
    const { rows: recipients } = await getEligibleUserIds(
      announcement.visibility,
      announcement.target_value,
    );
    if (!recipients.length) return;

    const params = [];
    const values = recipients.map((r, i) => {
      const isStudent = r.role === "student";
      params.push(
        r.id,
        isStudent ? "announcement_student" : "announcement_teacher",
        isStudent ? "🔔 New School Announcement" : "🔔 New Faculty Update",
        announcement.title,
        announcement.id,
      );
      const base = i * 5;
      return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`;
    });

    await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, announcement_id)
       VALUES ${values.join(", ")}`,
      params,
    );
  } catch (err) {
    console.error("notifyEligibleUsers failed:", err);
  }
}

// ── GET /announcements — visibility-filtered list for students/teachers ────
exports.list = async (req, res) => {
  const { category, priority, search, filter, page = 1, limit = 20 } = req.query;
  const userId = req.user.sub;
  const role = req.user.role;

  try {
    let userRow = { id: userId, role };
    if (role === "student") {
      const { rows } = await pool.query(
        `SELECT course, year_level FROM users WHERE id = $1`,
        [userId],
      );
      userRow = { ...userRow, ...(rows[0] || {}) };
    }

    const params = [];
    let where = `a.is_archived = false AND a.publish_at <= now() AND (a.expires_at IS NULL OR a.expires_at > now())`;
    where += ` AND ${buildVisibilityFilter(userRow, params)}`;

    if (category) {
      params.push(category);
      where += ` AND a.category = $${params.length}`;
    }
    if (priority) {
      params.push(priority);
      where += ` AND a.priority = $${params.length}`;
    }
    if (search) {
      params.push(`%${search}%`);
      where += ` AND (a.title ILIKE $${params.length} OR a.description ILIKE $${params.length})`;
    }
    if (filter === "bookmarked") {
      params.push(userId);
      where += ` AND EXISTS (SELECT 1 FROM announcement_bookmarks ab WHERE ab.announcement_id = a.id AND ab.user_id = $${params.length})`;
    }
    if (filter === "unread") {
      params.push(userId);
      where += ` AND NOT EXISTS (SELECT 1 FROM announcement_reads ar WHERE ar.announcement_id = a.id AND ar.user_id = $${params.length})`;
    }

    const offset = (Number(page) - 1) * Number(limit);
    params.push(userId);
    const readParamIdx = params.length;
    params.push(userId);
    const likeParamIdx = params.length;
    params.push(userId);
    const bookmarkParamIdx = params.length;
    params.push(Number(limit), offset);

    const { rows } = await pool.query(
      `SELECT ${ADMIN_JOIN_SELECT},
              EXISTS(SELECT 1 FROM announcement_reads ar WHERE ar.announcement_id = a.id AND ar.user_id = $${readParamIdx}) AS is_read,
              EXISTS(SELECT 1 FROM announcement_likes al WHERE al.announcement_id = a.id AND al.user_id = $${likeParamIdx}) AS is_liked,
              EXISTS(SELECT 1 FROM announcement_bookmarks ab WHERE ab.announcement_id = a.id AND ab.user_id = $${bookmarkParamIdx}) AS is_bookmarked,
              (SELECT COUNT(*) FROM announcement_likes al2 WHERE al2.announcement_id = a.id)::int AS like_count
       FROM announcements a
       JOIN users u ON u.id = a.created_by
       WHERE ${where}
       ORDER BY a.is_pinned DESC, a.publish_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch announcements" });
  }
};

// ── GET /announcements/:id — detail, marks as read as a side effect ────────
exports.getOne = async (req, res) => {
  const { id } = req.params;
  const userId = req.user.sub;

  try {
    const { rows } = await pool.query(
      `SELECT ${ADMIN_JOIN_SELECT},
              EXISTS(SELECT 1 FROM announcement_likes al WHERE al.announcement_id = a.id AND al.user_id = $2) AS is_liked,
              EXISTS(SELECT 1 FROM announcement_bookmarks ab WHERE ab.announcement_id = a.id AND ab.user_id = $2) AS is_bookmarked,
              (SELECT COUNT(*) FROM announcement_likes al2 WHERE al2.announcement_id = a.id)::int AS like_count
       FROM announcements a
       JOIN users u ON u.id = a.created_by
       WHERE a.id = $1`,
      [id, userId],
    );
    if (!rows.length) return res.status(404).json({ error: "Announcement not found" });

    await pool.query(
      `INSERT INTO announcement_reads (announcement_id, user_id)
       VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [id, userId],
    );

    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch announcement" });
  }
};

// ── POST /announcements/upload — admin only, returns a URL to reference ────
// from create/update's coverImageUrl / attachmentUrl fields. Mirrors
// modules.controller.js's upload handling (multer config lives in
// routes/index.js), except this doesn't persist anything itself — the
// caller decides which field the returned URL belongs in.
exports.uploadAsset = async (req, res) => {
  if (!req.file) return res.status(400).json({ error: "A file is required." });
  res.status(201).json({
    url: `/uploads/announcements/${req.file.filename}`,
    name: req.file.originalname,
    type: req.file.mimetype,
  });
};

// ── POST /announcements — admin only ────────────────────────────────────────
exports.create = async (req, res) => {
  const err = validateBody(req.body);
  if (err) return res.status(400).json({ error: err });

  const {
    title, subtitle, description, category = "announcement",
    priority = "normal", visibility = "everyone", targetValue,
    coverImageUrl, galleryUrls, attachmentUrl, attachmentName,
    externalLink, publishAt, expiresAt, isPinned, commentsEnabled,
  } = req.body;

  try {
    const { rows } = await pool.query(
      `INSERT INTO announcements
        (title, subtitle, description, category, priority, visibility, target_value,
         cover_image_url, gallery_urls, attachment_url, attachment_name, external_link,
         publish_at, expires_at, is_pinned, comments_enabled, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
       RETURNING *`,
      [
        title.trim(), subtitle || null, description, category, priority,
        visibility, targetValue || null, coverImageUrl || null,
        galleryUrls || [], attachmentUrl || null, attachmentName || null,
        externalLink || null, publishAt || new Date().toISOString(),
        expiresAt || null, isPinned ?? false, commentsEnabled ?? false,
        req.user.sub,
      ],
    );
    res.status(201).json(rows[0]);

    // Fires after the response is sent — a slow or failing fan-out should
    // never delay or break the admin's "announcement created" response.
    notifyEligibleUsers(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create announcement" });
  }
};

// ── PATCH /announcements/:id — admin only ───────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;
  const err = validateBody(req.body, { partial: true });
  if (err) return res.status(400).json({ error: err });

  try {
    const { rows: existingRows } = await pool.query(`SELECT * FROM announcements WHERE id = $1`, [id]);
    if (!existingRows.length) return res.status(404).json({ error: "Announcement not found" });
    const e = existingRows[0];
    const b = req.body;

    const { rows } = await pool.query(
      `UPDATE announcements SET
         title=$1, subtitle=$2, description=$3, category=$4, priority=$5,
         visibility=$6, target_value=$7, cover_image_url=$8, gallery_urls=$9,
         attachment_url=$10, attachment_name=$11, external_link=$12,
         publish_at=$13, expires_at=$14, is_pinned=$15, comments_enabled=$16,
         updated_at=now()
       WHERE id=$17 RETURNING *`,
      [
        b.title ?? e.title, b.subtitle ?? e.subtitle, b.description ?? e.description,
        b.category ?? e.category, b.priority ?? e.priority, b.visibility ?? e.visibility,
        b.targetValue ?? e.target_value, b.coverImageUrl ?? e.cover_image_url,
        b.galleryUrls ?? e.gallery_urls, b.attachmentUrl ?? e.attachment_url,
        b.attachmentName ?? e.attachment_name, b.externalLink ?? e.external_link,
        b.publishAt ?? e.publish_at, b.expiresAt ?? e.expires_at,
        b.isPinned ?? e.is_pinned, b.commentsEnabled ?? e.comments_enabled,
        id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update announcement" });
  }
};

// ── DELETE /announcements/:id — admin only ──────────────────────────────────
exports.remove = async (req, res) => {
  try {
    const { rows } = await pool.query(`SELECT * FROM announcements WHERE id = $1`, [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: "Announcement not found" });
    const a = rows[0];

    await pool.query(`DELETE FROM announcements WHERE id = $1`, [req.params.id]);

    if (a.cover_image_url) fs.unlink(path.join(__dirname, "..", "..", a.cover_image_url), () => {});
    if (a.attachment_url) fs.unlink(path.join(__dirname, "..", "..", a.attachment_url), () => {});
    (a.gallery_urls || []).forEach((u) => fs.unlink(path.join(__dirname, "..", "..", u), () => {}));

    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete announcement" });
  }
};

// ── PATCH /announcements/:id/archive | /restore | /pin | /unpin ─────────────
exports.archive = (req, res) => setFlag(req, res, "is_archived", true);
exports.restore = (req, res) => setFlag(req, res, "is_archived", false);
exports.pin = (req, res) => setFlag(req, res, "is_pinned", true);
exports.unpin = (req, res) => setFlag(req, res, "is_pinned", false);

async function setFlag(req, res, column, value) {
  try {
    const { rows } = await pool.query(
      `UPDATE announcements SET ${column} = $1, updated_at = now() WHERE id = $2 RETURNING *`,
      [value, req.params.id],
    );
    if (!rows.length) return res.status(404).json({ error: "Announcement not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update announcement" });
  }
}

// ── GET /admin/announcements — admin list, unfiltered, includes archived ───
exports.adminList = async (req, res) => {
  const { includeArchived } = req.query;
  try {
    const { rows } = await pool.query(
      `SELECT ${ADMIN_JOIN_SELECT},
              (SELECT COUNT(*) FROM announcement_likes al WHERE al.announcement_id = a.id)::int AS like_count,
              (SELECT COUNT(*) FROM announcement_reads ar WHERE ar.announcement_id = a.id)::int AS read_count
       FROM announcements a
       JOIN users u ON u.id = a.created_by
       ${includeArchived === "true" ? "" : "WHERE a.is_archived = false"}
       ORDER BY a.is_pinned DESC, a.publish_at DESC`,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch announcements" });
  }
};

// ── POST /announcements/:id/like, DELETE /announcements/:id/like ───────────
exports.like = async (req, res) => {
  try {
    await pool.query(
      `INSERT INTO announcement_likes (announcement_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [req.params.id, req.user.sub],
    );
    res.json({ liked: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to like announcement" });
  }
};

exports.unlike = async (req, res) => {
  try {
    await pool.query(
      `DELETE FROM announcement_likes WHERE announcement_id = $1 AND user_id = $2`,
      [req.params.id, req.user.sub],
    );
    res.json({ liked: false });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to unlike announcement" });
  }
};

// ── POST /announcements/:id/bookmark, DELETE /announcements/:id/bookmark ───
exports.bookmark = async (req, res) => {
  try {
    await pool.query(
      `INSERT INTO announcement_bookmarks (announcement_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [req.params.id, req.user.sub],
    );
    res.json({ bookmarked: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to bookmark announcement" });
  }
};

exports.unbookmark = async (req, res) => {
  try {
    await pool.query(
      `DELETE FROM announcement_bookmarks WHERE announcement_id = $1 AND user_id = $2`,
      [req.params.id, req.user.sub],
    );
    res.json({ bookmarked: false });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to unbookmark announcement" });
  }
};