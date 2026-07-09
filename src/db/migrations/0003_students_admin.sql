-- 0003_students_admin.sql
-- Adds the fields needed for the Admin > Students List feature.
-- Safe to run multiple times (IF NOT EXISTS guards).
--
-- ⚠️ CORRECTED (per live pgAdmin schema check): there is no
-- student_profiles table in this database. course, year_level, and
-- phone_verified already live directly on `users`. The original version
-- of this migration tried to ALTER TABLE student_profiles, which does
-- not exist, and would fail with "relation does not exist" if re-run.
-- This version targets `users` directly and is a no-op if those columns
-- are already present (which they are).

-- "Course" and "Year Level" per your decision: since Succor Haven is
-- subject-based (not a school with formal courses), these are just
-- free-text fields the admin sets manually per student, not derived
-- from bookings/subjects.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS course VARCHAR(120),
  ADD COLUMN IF NOT EXISTS year_level VARCHAR(50);

-- "Verified/Unverified" filter maps to phone verification, since
-- Succor Haven already has an OTP-based phone verification flow
-- (see auth.controller.js sendOtp/verifyOtp). Already present on users,
-- so this is a no-op guard.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_users_course ON users(course);
CREATE INDEX IF NOT EXISTS idx_users_year_level ON users(year_level);

-- NOTE: bookings.teacher_notes and a dedicated activity_log table are
-- intentionally NOT included here — you asked to build the rest first.
-- The "Session History" teacher remarks will show as null, and the
-- "Activity Timeline" is synthesized from existing data (account
-- creation + booking events) instead of a real audit log. Add a follow-up
-- migration later if you want those:
--
--   ALTER TABLE bookings ADD COLUMN IF NOT EXISTS teacher_notes TEXT;
--
--   CREATE TABLE IF NOT EXISTS activity_log (
--     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
--     user_id INTEGER REFERENCES users(id),
--     type VARCHAR(50) NOT NULL,
--     description TEXT,
--     created_at TIMESTAMPTZ NOT NULL DEFAULT now()
--   );