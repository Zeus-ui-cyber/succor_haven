-- src/db/migrations/0002_settings_additions.sql
--
-- Run this once against your database (e.g. `psql $DATABASE_URL -f this_file.sql`).
-- Adds settings-related columns to the users table and creates the support_concerns table.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS full_name TEXT,
  ADD COLUMN IF NOT EXISTS profile_picture_url TEXT,
  ADD COLUMN IF NOT EXISTS backup_phone TEXT,
  ADD COLUMN IF NOT EXISTS language_pref TEXT NOT NULL DEFAULT 'en',
  ADD COLUMN IF NOT EXISTS notify_upcoming_session BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_session_reminder BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_student_booking BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS notify_general_announcement BOOLEAN NOT NULL DEFAULT true;

UPDATE users
   SET full_name = CONCAT_WS(' ', first_name, last_name)
 WHERE full_name IS NULL;

CREATE TABLE IF NOT EXISTS support_concerns (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  subject     TEXT NOT NULL,
  message     TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
