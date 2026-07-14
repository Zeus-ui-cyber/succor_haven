// run_appointment_timezone_migration.js
// Run with: node run_appointment_timezone_migration.js
//
// Same one-off-runner situation as the other migrations in this repo —
// migrate.js doesn't know about src/db/migrations/, so this applies
// 0008_appointment_timezone.sql directly.

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
  "0008_appointment_timezone.sql",
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
  console.log("✅ 0008_appointment_timezone.sql applied successfully!");

  const { rows } = await pool.query(
    `SELECT column_name, data_type, column_default
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'appointments'
       AND column_name = 'timezone_offset_minutes'`,
  );
  console.log("\nConfirmed column now present:", rows);

  await pool.end();
}

main().catch((err) => {
  console.error("❌ Migration failed:", err.message);
  process.exit(1);
});
