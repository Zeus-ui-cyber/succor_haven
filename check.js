// check.js — run with: node check.js
// Temporary diagnostic script. Delete after use.

const pool = require("./src/db/pool");

async function main() {
  try {
    const dbInfo = await pool.query(
      "SELECT current_database() AS db, current_schema() AS schema"
    );
    console.log("Connected to:", dbInfo.rows[0]);

    const cols = await pool.query(
      `SELECT column_name, data_type
       FROM information_schema.columns
       WHERE table_name = 'users'
       ORDER BY ordinal_position`
    );
    console.log("users table columns:");
    console.table(cols.rows);

    if (!cols.rows.length) {
      console.log("⚠️  No 'users' table found in this database/schema at all.");
    }
  } catch (err) {
    console.error("Diagnostic query failed:", err);
  } finally {
    await pool.end();
  }
}

main();