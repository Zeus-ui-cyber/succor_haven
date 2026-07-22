-- src/db/migrations/0009_points_and_credits_overhaul.sql

-- Add credits balance to teacher profiles so they can earn what students spend
ALTER TABLE teacher_profiles ADD COLUMN IF NOT EXISTS credits INTEGER DEFAULT 0;

-- Freeze the credit cost on appointments at the time of request
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS credits_cost INTEGER DEFAULT 0;
