-- 0010_teacher_subject_prices.sql
-- Creates a table to store per-subject base rates for teachers.
-- The rate is defined as credits per 30-minute interval.

CREATE TABLE IF NOT EXISTS teacher_subject_prices (
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    credits_per_half_hour INTEGER NOT NULL DEFAULT 3,
    PRIMARY KEY (teacher_id, subject)
);

-- Index for quick lookup of a teacher's subjects
CREATE INDEX IF NOT EXISTS idx_teacher_subject_prices_teacher 
    ON teacher_subject_prices(teacher_id);
