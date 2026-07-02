-- src/db/migrations/0001_credit_rules_and_pricing.sql
--
-- Run this once against your database (e.g. `psql $DATABASE_URL -f this_file.sql`,
-- or via whatever migration runner you use). No existing tables are touched.

-- ── credit_rules ───────────────────────────────────────────────────────────
-- Defines how credits/points are earned or spent across the app
-- (matches the contract documented in lib/.../admin/credit_rules_screen.dart)
CREATE TABLE IF NOT EXISTS credit_rules (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  name_cn       TEXT NOT NULL DEFAULT '',
  type          TEXT NOT NULL CHECK (type IN ('earn', 'spend')),
  currency      TEXT NOT NULL CHECK (currency IN ('credits', 'points')),
  amount        INTEGER NOT NULL CHECK (amount >= 0),
  trigger       TEXT NOT NULL,
  applies_to    TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('student', 'teacher', 'all')),
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── pricing ────────────────────────────────────────────────────────────────
-- Session pricing tiers / packages
-- (matches the contract documented in lib/.../admin/session_pricing_screen.dart)
CREATE TABLE IF NOT EXISTS pricing (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  TEXT NOT NULL,
  name_cn               TEXT NOT NULL DEFAULT '',
  session_type          TEXT NOT NULL CHECK (session_type IN ('standard', 'trial', 'group', 'intensive')),
  credits_per_session   INTEGER NOT NULL CHECK (credits_per_session >= 0),
  sessions_in_package   INTEGER NOT NULL DEFAULT 1 CHECK (sessions_in_package >= 1),
  total_credits         INTEGER NOT NULL CHECK (total_credits >= 0),
  discount_pct          NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_pct >= 0 AND discount_pct <= 100),
  applies_to            TEXT NOT NULL DEFAULT 'all' CHECK (applies_to IN ('student', 'teacher', 'all')),
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Keep updated_at fresh on edit (mirrors how you'd want it for both tables)
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_credit_rules_updated_at ON credit_rules;
CREATE TRIGGER trg_credit_rules_updated_at
  BEFORE UPDATE ON credit_rules
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_pricing_updated_at ON pricing;
CREATE TRIGGER trg_pricing_updated_at
  BEFORE UPDATE ON pricing
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();