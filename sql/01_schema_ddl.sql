DROP TABLE IF EXISTS contracts CASCADE;
DROP TABLE IF EXISTS freelancers CASCADE;
DROP TABLE IF EXISTS wallet_audit_logs CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

CREATE TABLE clients (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    escrow_balance  NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT clients_escrow_nonnegative CHECK (escrow_balance >= 0.00)
);

CREATE TABLE freelancers (
    id           BIGSERIAL PRIMARY KEY,
    name         VARCHAR(120) NOT NULL,
    latitude     DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude    DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    is_available BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE contracts (
    id            BIGSERIAL PRIMARY KEY,
    client_id     BIGINT NOT NULL REFERENCES clients(id),
    freelancer_id BIGINT NOT NULL REFERENCES freelancers(id),
    budget        NUMERIC(12,2) NOT NULL CHECK (budget > 0.00),
    status        VARCHAR(20) NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT contracts_status_chk
        CHECK (status IN ('FUNDED', 'IN PROGRESS', 'COMPLETED'))
);

CREATE TABLE wallet_audit_logs (
    id             BIGSERIAL PRIMARY KEY,
    client_id      BIGINT NOT NULL REFERENCES clients(id),
    amount_changed NUMERIC(12,2) NOT NULL,
    action_type    VARCHAR(10) NOT NULL,
    balance_after  NUMERIC(12,2) NOT NULL CHECK (balance_after >= 0.00),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT wallet_audit_action_chk
        CHECK (action_type IN ('DEBIT', 'CREDIT'))
);