-- Credit top-up system: admin-managed packages + payment transaction ledger.
-- users.id confirmed UUID via live schema query (Neon console, Jul 13 2026) —
-- unlike appointments' users.id assumption, this one is correct as UUID.

CREATE TABLE IF NOT EXISTS credit_packages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    credits_amount  INTEGER NOT NULL CHECK (credits_amount > 0),
    price_cents     INTEGER NOT NULL CHECK (price_cents > 0),
    currency        TEXT NOT NULL DEFAULT 'PHP',
    is_active       BOOLEAN NOT NULL DEFAULT true,
    display_order   INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credit_package_id       UUID REFERENCES credit_packages(id) ON DELETE SET NULL,
    amount_cents            INTEGER NOT NULL,
    currency                TEXT NOT NULL DEFAULT 'PHP',
    provider                TEXT,                 -- e.g. '2c2p' — nullable until Phase 2
    provider_transaction_id TEXT,
    payment_method          TEXT CHECK (payment_method IN ('gcash','maya','card','alipay','wechat')),
    status                  TEXT NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending','succeeded','failed','refunded')),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at                 TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
-- Idempotency guard for webhook delivery (Phase 2) — a given provider txn id
-- can only ever map to one payment row.
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_provider_txn
    ON payments(provider, provider_transaction_id)
    WHERE provider_transaction_id IS NOT NULL;

CREATE OR REPLACE FUNCTION set_credit_packages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_credit_packages_updated_at ON credit_packages;
CREATE TRIGGER trg_credit_packages_updated_at
    BEFORE UPDATE ON credit_packages
    FOR EACH ROW
    EXECUTE FUNCTION set_credit_packages_updated_at();

-- Seed placeholder tiers — admin can retune anytime via the CRUD endpoints.
INSERT INTO credit_packages (name, credits_amount, price_cents, display_order) VALUES
    ('Starter', 20, 20000, 1),
    ('Popular', 50, 50000, 2),
    ('Value', 120, 100000, 3),
    ('Bulk', 260, 200000, 4)
ON CONFLICT DO NOTHING;