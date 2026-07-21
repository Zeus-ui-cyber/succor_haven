require('dotenv').config();
const pool = require('./src/db/pool');

async function testInsert() {
  const title = "test";
  const subtitle = "";
  const description = "test comming";
  const category = "event";
  const priority = "normal";
  const visibility = "everyone";
  const targetValue = null;
  const coverImageUrl = null;
  const galleryUrls = [];
  const attachmentUrl = null;
  const attachmentName = null;
  const externalLink = "";
  const publishAt = "2026-07-21T01:19:00.000Z";
  const expiresAt = "2026-07-21T02:00:00.000Z";
  const isPinned = true;
  const commentsEnabled = true;
  // We need a valid UUID for created_by, let's fetch an admin user
  const adminRes = await pool.query("SELECT id FROM users WHERE role = 'admin' LIMIT 1");
  const adminId = adminRes.rows[0].id;

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
        adminId,
      ],
    );
    console.log("Success:", rows[0]);
    // Cleanup
    await pool.query("DELETE FROM announcements WHERE id = $1", [rows[0].id]);
  } catch (err) {
    console.error("DB Error:", err.message);
  } finally {
    pool.end();
  }
}
testInsert();
