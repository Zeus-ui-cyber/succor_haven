// run_appointments_migration.js
// Run with: node run_appointments_migration.js
//
// migrate.js in this project is a leftover one-time setup script from the
// original schema (users/bookings/etc.) — it does NOT know about the
// files in db/migrations/, so 0004_appointments.sql was never actually
// executed even though `node migrate.js` printed "success". This script
// reads and runs that specific file directly against the real database
// (via DATABASE_URL from .env, same as db/pool.js).

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
  "0004_appointments.sql",
);

async function main() {
  console.log(
    `Connected to: ${process.env.DATABASE_URL?.split("@")[1] ?? "(no DATABASE_URL set)"}\n`,
  );

  if (!fs.existsSync(MIGRATION_FILE)) {
    console.error(`❌ Could not find migration file at: ${MIGRATION_FILE}`);
    console.error(
      "   If your migrations live in a different folder, edit MIGRATION_FILE at the top of this script.",
    );
    process.exit(1);
  }

  const sql = fs.readFileSync(MIGRATION_FILE, "utf8");
  console.log(`Running ${MIGRATION_FILE} ...\n`);

  await pool.query(sql);
  console.log("✅ 0004_appointments.sql applied successfully!");

  // Confirm it's really there now.
  const { rows } = await pool.query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name IN ('appointments', 'appointment_feedback')
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
