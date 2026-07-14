// run_session_room_migration.js
// Run with: node run_session_room_migration.js

const fs = require("fs");
const path = require("path");
const { Pool } = require("pg");
require("dotenv").config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // Neon requires SSL
});

const MIGRATION_FILE = path.join(
  __dirname,
  "src",
  "db",
  "migrations",
  "0009_session_room.sql",
);

async function main() {
  console.log(
    `Connected to: ${process.env.DATABASE_URL?.split("@")[1] ?? "(no DATABASE_URL set)"}\n`,
  );

  if (!fs.existsSync(MIGRATION_FILE)) {
    console.error(`❌ Could not find migration file at: ${MIGRATION_FILE}`);
    process.exit(1);
  }

  const sql = fs.readFileSync(MIGRATION_FILE, "utf8");
  console.log(`Running ${MIGRATION_FILE} ...\n`);

  await pool.query(sql);
  console.log("✅ 0009_session_room.sql applied successfully!");

  const { rows } = await pool.query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_name IN ('session_chat_messages', 'session_notes', 'session_files')
     ORDER BY table_name`,
  );
  console.log(
    "\nConfirmed tables now present:",
    rows.map((r) => r.table_name),
  );

  await pool.end();
}

main().catch((err) => {
  console.error("❌ Migration failed:", err.message);
  process.exit(1);
});
