CREATE TABLE IF NOT EXISTS modules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title           TEXT NOT NULL,
    subject         TEXT NOT NULL,
    description     TEXT,

    file_url        TEXT NOT NULL,
    file_name       TEXT NOT NULL,
    file_type       TEXT,

    uploaded_by     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_modules_uploaded_by ON modules(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_modules_subject ON modules(subject);

CREATE OR REPLACE FUNCTION set_modules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_modules_updated_at ON modules;
CREATE TRIGGER trg_modules_updated_at
    BEFORE UPDATE ON modules
    FOR EACH ROW
    EXECUTE FUNCTION set_modules_updated_at();