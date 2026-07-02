// src/controllers/courses.controller.js
const pool = require("../db/pool");

// ── GET /courses — browse, filterable by category/search ──────────────────────
exports.browse = async (req, res) => {
  const { category, search, page = 1, limit = 20 } = req.query;
  const offset = (Number(page) - 1) * Number(limit);
  const params = [];
  let where = `c.is_active = true`;

  if (category && category !== "All") {
    params.push(category);
    where += ` AND c.category = $${params.length}`;
  }
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (c.title ILIKE $${params.length} OR c.description ILIKE $${params.length})`;
  }

  params.push(limit, offset);
  try {
    const { rows } = await pool.query(
      `SELECT c.id, c.title, c.title_cn, c.category, c.age_group, c.difficulty,
              c.description, c.thumbnail_url, c.features,
              p.id AS pricing_id, p.name AS pricing_name,
              p.credits_per_session, p.session_type
       FROM courses c
       LEFT JOIN pricing p ON p.id = c.pricing_id
       WHERE ${where}
       ORDER BY c.title ASC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch courses" });
  }
};

// ── GET /courses/categories — distinct category list for the filter row ───────
exports.categories = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT category FROM courses WHERE is_active = true ORDER BY category`,
    );
    res.json(rows.map((r) => r.category));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch categories" });
  }
};

// ── GET /courses/:id — single course detail ────────────────────────────────────
exports.getOne = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT c.*,
              p.id AS pricing_id, p.name AS pricing_name,
              p.credits_per_session, p.session_type
       FROM courses c
       LEFT JOIN pricing p ON p.id = c.pricing_id
       WHERE c.id = $1 AND c.is_active = true`,
      [req.params.id],
    );
    if (!rows.length) return res.status(404).json({ error: "Course not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch course" });
  }
};

// ── POST /admin/courses — admin creates a course ────────────────────────────────
exports.create = async (req, res) => {
  const {
    title, titleCn, category, ageGroup, difficulty,
    description, thumbnailUrl, features, pricingId, isActive,
  } = req.body;

  if (!title || !category)
    return res.status(400).json({ error: "title and category are required" });

  try {
    const { rows } = await pool.query(
      `INSERT INTO courses
         (title, title_cn, category, age_group, difficulty, description,
          thumbnail_url, features, pricing_id, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        title, titleCn || "", category, ageGroup || null, difficulty || null,
        description || null, thumbnailUrl || null, features || [],
        pricingId || null, isActive ?? true,
      ],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create course" });
  }
};

// ── PATCH /admin/courses/:id ─────────────────────────────────────────────────
exports.update = async (req, res) => {
  const { id } = req.params;
  const {
    title, titleCn, category, ageGroup, difficulty,
    description, thumbnailUrl, features, pricingId, isActive,
  } = req.body;

  try {
    const { rows: existingRows } = await pool.query(
      `SELECT * FROM courses WHERE id = $1`,
      [id],
    );
    if (!existingRows.length)
      return res.status(404).json({ error: "Course not found" });
    const e = existingRows[0];

    const { rows } = await pool.query(
      `UPDATE courses
       SET title=$1, title_cn=$2, category=$3, age_group=$4, difficulty=$5,
           description=$6, thumbnail_url=$7, features=$8, pricing_id=$9,
           is_active=$10, updated_at=now()
       WHERE id=$11
       RETURNING *`,
      [
        title ?? e.title, titleCn ?? e.title_cn, category ?? e.category,
        ageGroup ?? e.age_group, difficulty ?? e.difficulty,
        description ?? e.description, thumbnailUrl ?? e.thumbnail_url,
        features ?? e.features, pricingId ?? e.pricing_id,
        isActive ?? e.is_active, id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update course" });
  }
};

// ── DELETE /admin/courses/:id ─────────────────────────────────────────────────
exports.remove = async (req, res) => {
  try {
    const { rowCount } = await pool.query(`DELETE FROM courses WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rowCount) return res.status(404).json({ error: "Course not found" });
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to delete course" });
  }
};