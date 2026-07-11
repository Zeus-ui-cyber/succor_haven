-- 0004_appointments.sql
-- Standalone Teacher Appointment Request & Approval system.
-- Deliberately separate from `bookings` (no credits involved here).
--
-- NOTE: This assumes a `users` table with a uuid `id` primary key, the
-- same one referenced elsewhere (teachers.controller.js, bookings, etc.)
-- If your student/teacher accounts live in a different table, swap the
-- REFERENCES targets below.

CREATE TABLE IF NOT EXISTS appointments (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    student_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    teacher_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Request form fields
    title             TEXT NOT NULL,
    purpose           TEXT NOT NULL,          -- e.g. "Academic Consultation", "Exam Review"
    subject           TEXT NOT NULL,
    preferred_date    DATE NOT NULL,
    preferred_time    TIME NOT NULL,
    description       TEXT,
    attachment_url    TEXT,                   -- nullable; set once file upload is wired up

    -- Workflow
    status            TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                            'pending', 'approved', 'declined',
                            'completed', 'cancelled', 'rescheduled'
                        )),

    -- Teacher actions
    teacher_notes     TEXT,                   -- general note/message to student
    decline_reason    TEXT,
    proposed_date     DATE,                   -- set when teacher suggests a new schedule
    proposed_time     TIME,

    request_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_appointments_student ON appointments(student_id);
CREATE INDEX IF NOT EXISTS idx_appointments_teacher ON appointments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_appointments_status  ON appointments(status);

-- Feedback, one per completed appointment (enforced by UNIQUE on appointment_id)
CREATE TABLE IF NOT EXISTS appointment_feedback (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id    UUID NOT NULL UNIQUE REFERENCES appointments(id) ON DELETE CASCADE,
    student_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    teacher_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating            SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment           TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- keep updated_at fresh
CREATE OR REPLACE FUNCTION set_appointments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at
    BEFORE UPDATE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION set_appointments_updated_at();