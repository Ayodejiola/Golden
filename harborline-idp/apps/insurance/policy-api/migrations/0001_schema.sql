-- 0001: core insurance schema. Restricted data (insured PII) lives only in quotes.insured / policies.insured.
CREATE TABLE IF NOT EXISTS quotes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product         text NOT NULL CHECK (product IN ('auto', 'home')),
    status          text NOT NULL CHECK (status IN ('quoted', 'referred', 'declined', 'bound')),
    insured         jsonb NOT NULL,
    risk            jsonb NOT NULL,
    deductible      integer NOT NULL CHECK (deductible IN (500, 1000, 2500)),
    effective_date  date NOT NULL,
    annual_premium  numeric(12, 2),
    currency        char(3) NOT NULL DEFAULT 'CAD',
    breakdown       jsonb,
    reasons         jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_by      text NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    expires_at      timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS quotes_created_by_idx ON quotes (created_by, created_at DESC);

CREATE SEQUENCE IF NOT EXISTS policy_number_seq START 100000;
CREATE TABLE IF NOT EXISTS policies (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_number   text NOT NULL UNIQUE,
    quote_id        uuid NOT NULL UNIQUE REFERENCES quotes (id),
    product         text NOT NULL CHECK (product IN ('auto', 'home')),
    status          text NOT NULL CHECK (status IN ('active', 'cancelled')),
    effective_date  date NOT NULL,
    expiry_date     date NOT NULL CHECK (expiry_date > effective_date),
    annual_premium  numeric(12, 2) NOT NULL CHECK (annual_premium >= 0),
    insured         jsonb NOT NULL,
    created_by      text NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS policies_created_by_idx ON policies (created_by, created_at DESC);

CREATE SEQUENCE IF NOT EXISTS claim_number_seq START 1000000;
CREATE TABLE IF NOT EXISTS claims (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_number     text NOT NULL UNIQUE,
    policy_id        uuid NOT NULL REFERENCES policies (id),
    loss_date        date NOT NULL,
    loss_type        text NOT NULL CHECK (loss_type IN ('collision', 'theft', 'fire', 'water', 'weather', 'liability')),
    description      text NOT NULL CHECK (length(description) BETWEEN 10 AND 2000),
    estimated_amount numeric(12, 2) NOT NULL CHECK (estimated_amount >= 0),
    status           text NOT NULL CHECK (status IN ('submitted', 'triaged', 'rejected')),
    triage_score     integer,
    triage_outcome   text CHECK (triage_outcome IN ('fast_track', 'adjuster_review', 'siu_review')),
    triage_reasons   jsonb,
    created_by       text NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS claims_policy_idx ON claims (policy_id);
