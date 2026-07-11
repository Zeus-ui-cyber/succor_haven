// src/controllers/modules.controller.js
//
// Module Management. Admin has full control over all modules. Teachers
// can view everything, upload their own, and update/delete only what
// they uploaded — enforced by checking uploaded_by against req.user.sub
// (confirmed this session: req.user.sub is the correct field set by
// auth.middleware.js's verifyAccess(), not req.user.id — the appointments
// controller had this exact bug and every function silently operated on
// `undefined` until it was fixed).
//
// uploaded_by is INTEGER on the live schema (users.id is INTEGER, not
// UUID — confirmed while running 0004_appointments.sql, which originally
// assumed UUID and had to be corrected). 0005_modules.sql already
// reflects that.

const fs = require("fs");
const path = require("path");
const pool = require("../db/pool");

const MODULE_JOIN_SELECT = `
  m.*,
  (u.first_name || ' ' || u.last_name) AS uploaded_by_name,
  u.role AS uploaded_by_role
`;

// ── GET /modules — list all, filterable ────────────────────────────────────
exports.list = async (req, res) => {
  const { subject, search } = req.query;
  const params = [];
  let where = "1=1";

  if (subject) {
    params.push(subject);
    where += ` AND m.subject = $${params.length}`;
  }
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (m.title ILIKE $${params.length} OR m.description ILIKE $${params.length})`;
  }

  try {
    const { rows } = await pool.query(
      `SELECT ${MODULE_JOIN_SELECT}
       FROM modules m
       JOIN users u ON u.id = m.uploaded_by
       WHERE ${where}
       ORDER BY m.created_at DESC`,
      params,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch modules" });
  }
};

// ── GET /modules/:id ─────────────────────────────────────────────────────
exports.getOne = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT ${MODULE_JOIN_SELECT}
       FROM modules m
       JOIN users u ON u.id = m.uploaded_by
       WHERE m.id = $1`,
      [req.params.id],
    );
    if (!rows.length) return res.status(404).json({ error: "Module not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch module" });
  }
};

// ── POST /modules — admin or teacher uploads ────────────────────────────────
exports.create = async (req, res) => {
  const { title, subject, description } = req.body;
  const uploaderId = req.user.sub;

  if (!req.file) {
    return res.status(400).json({ error: "A file attachment is required." });
  }
  if (!title || !subject) {
    // Clean up the uploaded file if validation fails after multer already saved it
    fs.unlink(req.file.path, () => {});
    return res.status(400).json({ error: "title and subject are required" });
  }

  const relativeUrl = `/uploads/modules/${req.file.filename}`;

  try {
    const { rows } = await pool.query(
      `INSERT INTO modules (title, subject, description, file_url, file_name, file_type, uploaded_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [
        title,
        subject,
        description || null,
        relativeUrl,
        req.file.originalname,
        req.file.mimetype,
        uploaderId,
      ],
    );

    // Re-fetch with the joined uploader name/role so the response shape
    // matches list()/getOne() — the client's ModuleModel.fromJson expects
    // uploaded_by_name/uploaded_by_role to be present.
    const { rows: joined } = await pool.query(
      `SELECT ${MODULE_JOIN_SELECT}
       FROM modules m
       JOIN users u ON u.id = m.uploaded_by
       WHERE m.id = $1`,
      [rows[0].id],
    );

    res.status(201).json(joined[0]);
  } catch (err) {
    console.error(err);
    fs.unlink(req.file.path, () => {});
    res.status(500).json({ error: "Failed to create module" });
  }
};

// ── PATCH /modules/:id — admin: any module. teacher: own only ──────────────
// Body fields optional (title/subject/description), file replacement optional.
exports.update = async (req, res) => {
  const { id } = req.params;
  const { title, subject, description } = req.body;
  const isAdmin = req.user.role === "admin";

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM modules WHERE id = $1`,
      [id],
    );
    if (!existingRows.length) {
      if (req.file) fs.unlink(req.file.path, () => {});
      return res.status(404).json({ error: "Module not found" });
    }
    const existing = existingRows[0];

    if (!isAdmin && existing.uploaded_by !== req.user.sub) {
      if (req.file) fs.unlink(req.file.path, () => {});
      return res.status(403).json({ error: "You can only edit modules you uploaded." });
    }

    let fileUrl = existing.file_url;
    let fileName = existing.file_name;
    let fileType = existing.file_type;
    const oldFilePath = existing.file_url
      ? path.join(__dirname, "..", "..", existing.file_url)
      : null;

    if (req.file) {
      fileUrl = `/uploads/modules/${req.file.filename}`;
      fileName = req.file.originalname;
      fileType = req.file.mimetype;
    }

    const { rows } = await pool.query(
      `UPDATE modules
       SET title=$1, subject=$2, description=$3, file_url=$4, file_name=$5, file_type=$6, updated_at=now()
       WHERE id=$7
       RETURNING *`,
      [
        title ?? existing.title,
        subject ?? existing.subject,
        description ?? existing.description,
        fileUrl,
        fileName,
        fileType,
        id,
      ],
    );

    // Only delete the old file once the new row is safely committed, and
    // only if we actually swapped in a new file (don't delete a file that's
    // still in active use because req.file was absent this time).
    if (req.file && oldFilePath) {
      fs.unlink(oldFilePath, () => {});
    }

    // Re-fetch joined, same reasoning as create() above.
    const { rows: joined } = await pool.query(
      `SELECT ${MODULE_JOIN_SELECT}
       FROM modules m
       JOIN users u ON u.id = m.uploaded_by
       WHERE m.id = $1`,
      [rows[0].id],
    );

    res.json(joined[0]);
  } catch (err) {
    console.error(err);
    if (req.file) fs.unlink(req.file.path, () => {});
    res.status(500).json({ error: "Failed to update module" });
  }
};

// ── DELETE /modules/:id — admin: any module. teacher: own only ─────────────
exports.remove = async (req, res) => {
  const { id } = req.params;
  const isAdmin = req.user.role === "admin";

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM modules WHERE id = $1`,
      [id],
    );
    if (!existingRows.length) return res.status(404).json({ error: "Module not found" });
    const existing = existingRows[0];

    if (!isAdmin && existing.uploaded_by !== req.user.sub) {
      return res.status(403).json({ error: "You can only delete modules you uploaded." });
    }

    await pool.query(`DELETE FROM modules WHERE id = $1`, [id]);

    if (existing.file_url) {
      const filePath = path.join(__dirname, "..", "..", existing.file_url);
      fs.unlink(filePath, () => {});
    }

    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete module" });
  }
};