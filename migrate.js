const { Pool } = require("pg");
require("dotenv").config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

const sql = `
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT UNIQUE,
  phone         TEXT UNIQUE,
  password_hash TEXT,
  first_name    TEXT NOT NULL,
  last_name     TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('student','teacher','admin')),
  avatar_url    TEXT,
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS student_profiles (
  user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  credits         INT DEFAULT 0,
  points          INT DEFAULT 0,
  native_language TEXT DEFAULT '',
  learning_goals  TEXT[] DEFAULT '{}',
  level           TEXT DEFAULT ''
);

CREATE TABLE IF NOT EXISTS teacher_profiles (
  user_id             UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  bio                 TEXT DEFAULT '',
  subjects            TEXT[] DEFAULT '{}',
  availability        TEXT[] DEFAULT '{}',
  credits_per_session INT DEFAULT 6,
  is_approved         BOOLEAN DEFAULT false,
  rating              NUMERIC(3,2) DEFAULT 0,
  total_sessions      INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS bookings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID REFERENCES users(id),
  teacher_id    UUID REFERENCES users(id),
  scheduled_at  TIMESTAMPTZ NOT NULL,
  duration_mins INT DEFAULT 30,
  credits_cost  INT NOT NULL,
  status        TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','completed','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  token      TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS otps (
  target     TEXT PRIMARY KEY,
  code       TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts   INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS points_ledger (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id),
  booking_id UUID REFERENCES bookings(id),
  points     INT NOT NULL,
  reason     TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rewards (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  description TEXT,
  points_cost INT NOT NULL,
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO users (email, password_hash, first_name, last_name, role)
VALUES (
  'admin@succorhaven.com',
  '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  'Admin', 'User', 'admin'
) ON CONFLICT DO NOTHING;
`;

pool.query(sql)
  .then(() => { console.log("✅ Schema applied successfully!"); process.exit(0); })
  .catch(err => { console.error("❌ Error:", err.message); process.exit(1); });
