// run_sessions_migration.js
// Run with: node run_sessions_migration.js
//
// Same situation as run_appointments_migration.js: migrate.js doesn't know
// about src/db/migrations/, so new migration files never run just by
// existing in the repo. This applies 0007_sessions.sql directly against
// DATABASE_URL from .env.
//
// ⚠️ Read the type-warning comment at the top of 0007_sessions.sql first —
// confirm users.id's real live column type with check_schema.js before
// running this.

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
  "0007_sessions.sql",
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
  console.log("✅ 0007_sessions.sql applied successfully!");

  const { rows } = await pool.query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name IN ('sessions', 'session_attendance')
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
