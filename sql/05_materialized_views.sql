DROP MATERIALIZED VIEW IF EXISTS freelancer_lifetime_summary;

CREATE MATERIALIZED VIEW freelancer_lifetime_summary AS
SELECT
    f.id AS freelancer_id,
    f.name,
    COUNT(c.id) FILTER (WHERE c.status = 'COMPLETED') AS completed_contracts,
    COALESCE(
        SUM(c.budget) FILTER (WHERE c.status = 'COMPLETED'),
        0.00
    )::NUMERIC(14,2) AS total_earnings
FROM freelancers f
LEFT JOIN contracts c
       ON c.freelancer_id = f.id
GROUP BY f.id, f.name;

-- Required for REFRESH MATERIALIZED VIEW CONCURRENTLY.
CREATE UNIQUE INDEX IF NOT EXISTS ux_freelancer_lifetime_summary
ON freelancer_lifetime_summary (freelancer_id);

CREATE OR REPLACE FUNCTION refresh_freelancer_lifetime_summary()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY freelancer_lifetime_summary;
END;
$$;

-- Refresh:
-- SELECT refresh_freelancer_lifetime_summary();
