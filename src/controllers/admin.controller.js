// src/controllers/admin.controller.js
const pool = require("../db/pool");

// ── GET /admin/dashboard ──────────────────────────────────────────────────────
exports.dashboard = async (req, res) => {
  try {
    const [users, bookings, revenue, pending] = await Promise.all([
      pool.query(`SELECT role, COUNT(*) FROM users GROUP BY role`),
      pool.query(`SELECT status, COUNT(*) FROM bookings GROUP BY status`),
      pool.query(
        `SELECT COALESCE(SUM(credits_cost),0) AS total FROM bookings WHERE status='completed'`,
      ),
      pool.query(
        `SELECT COUNT(*) FROM teacher_profiles WHERE is_approved = false`,
      ),
    ]);
    res.json({
      userCounts: users.rows,
      bookingCounts: bookings.rows,
      totalRevenueCents: Number(revenue.rows[0].total),
      pendingTeachers: Number(pending.rows[0].count),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Dashboard fetch failed" });
  }
};

// ── GET /admin/users ──────────────────────────────────────────────────────────
exports.listUsers = async (req, res) => {
  const { role, search, page = 1, limit = 30 } = req.query;
  const offset = (page - 1) * limit;
  const params = [];
  let where = "1=1";
  if (role) {
    params.push(role);
    where += ` AND u.role = $${params.length}`;
  }
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (u.first_name ILIKE $${params.length} OR u.last_name ILIKE $${params.length} OR u.email ILIKE $${params.length})`;
  }
  params.push(limit, offset);
  try {
    const { rows } = await pool.query(
      `SELECT u.id, u.email, u.phone, u.first_name, u.last_name,
              u.role, u.is_active, u.created_at,
              tp.is_approved AS teacher_approved,
              sp.credits, sp.points
       FROM users u
       LEFT JOIN teacher_profiles tp ON tp.user_id = u.id
       LEFT JOIN student_profiles sp ON sp.user_id = u.id
       WHERE ${where}
       ORDER BY u.created_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch users" });
  }
};

// ── PATCH /admin/teachers/:id/approve ────────────────────────────────────────
exports.approveTeacher = async (req, res) => {
  try {
    await pool.query(
      `UPDATE teacher_profiles SET is_approved = true WHERE user_id = $1`,
      [req.params.id],
    );
    res.json({ message: "Teacher approved" });
  } catch (err) {
    res.status(500).json({ error: "Approval failed" });
  }
};

// ── PATCH /admin/users/:id/toggle — activate / deactivate ─────────────────────
exports.toggleUser = async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE users SET is_active = NOT is_active WHERE id = $1 RETURNING is_active`,
      [req.params.id],
    );
    res.json({ isActive: rows[0].is_active });
  } catch (err) {
    res.status(500).json({ error: "Toggle failed" });
  }
};

// ── GET /admin/bookings ───────────────────────────────────────────────────────
exports.listBookings = async (req, res) => {
  const { status, page = 1, limit = 30 } = req.query;
  const offset = (page - 1) * limit;
  const params = [];
  let where = "1=1";
  if (status) {
    params.push(status);
    where += ` AND b.status = $${params.length}`;
  }
  params.push(limit, offset);
  try {
    const { rows } = await pool.query(
      `SELECT b.*,
         s.first_name AS student_first, s.last_name AS student_last,
         t.first_name AS teacher_first, t.last_name AS teacher_last
       FROM bookings b
       JOIN users s ON s.id = b.student_id
       JOIN users t ON t.id = b.teacher_id
       WHERE ${where}
       ORDER BY b.scheduled_at DESC
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch bookings" });
  }
};

// ── GET /admin/rewards ────────────────────────────────────────────────────────
exports.listRewards = async (req, res) => {
  const { rows } = await pool.query(
    `SELECT * FROM rewards ORDER BY points_cost`,
  );
  res.json(rows);
};

// ── POST /admin/rewards ───────────────────────────────────────────────────────
exports.createReward = async (req, res) => {
  const { name, description, pointsRequired, rewardType, rewardValue } =
    req.body;
  try {
    const { rows } = await pool.query(
      `INSERT INTO rewards (name, description, points_required, reward_type, reward_value)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [name, description, pointsRequired, rewardType, rewardValue],
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Failed to create reward" });
  }
};

// ── PATCH /admin/rewards/:id ──────────────────────────────────────────────────
exports.updateReward = async (req, res) => {
  const {
    name,
    description,
    pointsRequired,
    rewardType,
    rewardValue,
    isActive,
  } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE rewards SET name=$1, description=$2, points_required=$3,
         reward_type=$4, reward_value=$5, is_active=$6
       WHERE id=$7 RETURNING *`,
      [
        name,
        description,
        pointsRequired,
        rewardType,
        rewardValue,
        isActive,
        req.params.id,
      ],
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Update failed" });
  }
};
