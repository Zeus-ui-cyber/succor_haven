require('dotenv').config();
const { Pool } = require('pg');

const p = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const sql = `
CREATE TABLE credits_ledger (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount      INTEGER NOT NULL,
    currency    TEXT NOT NULL CHECK (currency IN ('credits', 'points')),
    reason      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_credits_ledger_user_id ON credits_ledger (user_id);
`;

p.query(sql)
  .then(() => {
    console.log('done');
    p.end();
  })
  .catch((e) => {
    console.error(e);
    p.end();
  });