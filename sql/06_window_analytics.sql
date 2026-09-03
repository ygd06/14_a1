-- Workflow 2: 7-day moving average of contract revenue per freelancer,
-- followed by DENSE_RANK() of freelancers by total revenue.
--
-- The calendar series fills missing days with zero revenue so that
-- ROWS BETWEEN 6 PRECEDING AND CURRENT ROW represents seven calendar days.

WITH bounds AS (
    SELECT
        COALESCE(MIN(created_at::date), CURRENT_DATE) AS min_day,
        COALESCE(MAX(created_at::date), CURRENT_DATE) AS max_day
    FROM contracts
    WHERE status = 'COMPLETED'
),
freelancer_days AS (
    SELECT
        f.id AS freelancer_id,
        f.name,
        gs.day::date AS day
    FROM freelancers f
    CROSS JOIN bounds b
    CROSS JOIN LATERAL generate_series(
        b.min_day,
        b.max_day,
        INTERVAL '1 day'
    ) AS gs(day)
),
daily_revenue AS (
    SELECT
        freelancer_id,
        created_at::date AS day,
        SUM(budget)::NUMERIC(14,2) AS revenue
    FROM contracts
    WHERE status = 'COMPLETED'
    GROUP BY freelancer_id, created_at::date
),
daily_filled AS (
    SELECT
        fd.freelancer_id,
        fd.name,
        fd.day,
        COALESCE(dr.revenue, 0.00)::NUMERIC(14,2) AS revenue
    FROM freelancer_days fd
    LEFT JOIN daily_revenue dr
      ON dr.freelancer_id = fd.freelancer_id
     AND dr.day = fd.day
),
moving_average AS (
    SELECT
        freelancer_id,
        name,
        day,
        revenue,
        AVG(revenue) OVER (
            PARTITION BY freelancer_id
            ORDER BY day
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS revenue_7_day_moving_avg
    FROM daily_filled
),
lifetime AS (
    SELECT
        freelancer_id,
        name,
        SUM(revenue) AS lifetime_revenue
    FROM daily_filled
    GROUP BY freelancer_id, name
),
ranked AS (
    SELECT
        freelancer_id,
        name,
        lifetime_revenue,
        DENSE_RANK() OVER (
            ORDER BY lifetime_revenue DESC
        ) AS revenue_rank
    FROM lifetime
)
SELECT
    ma.freelancer_id,
    ma.name,
    ma.day,
    ma.revenue,
    ROUND(ma.revenue_7_day_moving_avg, 2) AS revenue_7_day_moving_avg,
    r.lifetime_revenue,
    r.revenue_rank
FROM moving_average ma
JOIN ranked r USING (freelancer_id, name)
ORDER BY ma.day DESC, r.revenue_rank, ma.freelancer_id;
