-- Required partial unique index: one active contract per freelancer.
CREATE UNIQUE INDEX IF NOT EXISTS idx_active_gig
ON contracts (freelancer_id)
WHERE status = 'IN PROGRESS';

-- Useful foreign-key / analytics indexes.
CREATE INDEX IF NOT EXISTS idx_contracts_client
ON contracts (client_id);

CREATE INDEX IF NOT EXISTS idx_contracts_freelancer_created
ON contracts (freelancer_id, created_at);

CREATE INDEX IF NOT EXISTS idx_contracts_completed_created
ON contracts (created_at, freelancer_id)
WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_wallet_audit_client_created
ON wallet_audit_logs (client_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_freelancers_available
ON freelancers (id)
WHERE is_available = TRUE;

-- Covering partial index for recent completed-contract analytics.
CREATE INDEX IF NOT EXISTS idx_completed_contracts_analytics
ON contracts (created_at, freelancer_id)
INCLUDE (budget)
WHERE status = 'COMPLETED';
