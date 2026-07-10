// check_schema.js
// Run with: node check_schema.js
// Dumps the real column list for every table this app touches, straight
// from the live database, so we stop guessing/relying on stale comments.

const { Pool } = require("pg");

// Uses the same DATABASE_URL your app already uses.
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // Neon requires SSL
});

const TABLES_OF_INTEREST = [
  "users",
  "teacher_profiles",
  "student_profiles", // may not exist — that's what we're checking
  "bookings",
  "credits_ledger",
  "points_ledger", // may not exist
  "credit_rules",
  "pricing",
  "courses",
  "rewards",
  "refresh_tokens",
  "support_concerns",
  "milestones",
];

async function main() {
  console.log(
    `Connected to: ${process.env.DATABASE_URL?.split("@")[1] ?? "(no DATABASE_URL set)"}\n`,
  );

  const { rows: allTables } = await pool.query(
    `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name`,
  );
  console.log("== All tables in public schema ==");
  console.log(allTables.map((r) => r.table_name).join(", "));
  console.log();

  for (const table of TABLES_OF_INTEREST) {
    const exists = allTables.some((r) => r.table_name === table);
    if (!exists) {
      console.log(`❌ ${table} — DOES NOT EXIST\n`);
      continue;
    }

    const { rows: cols } = await pool.query(
      `SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = $1
       ORDER BY ordinal_position`,
      [table],
    );
    console.log(`✅ ${table}`);
    for (const c of cols) {
      console.log(
        `   - ${c.column_name} (${c.data_type})${c.is_nullable === "NO" ? " NOT NULL" : ""}${c.column_default ? ` DEFAULT ${c.column_default}` : ""}`,
      );
    }
    console.log();
  }

  await pool.end();
}

main().catch((err) => {
  console.error("Schema check failed:", err);
  process.exit(1);
});
