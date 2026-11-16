-- =============================================================================
-- Week 1 Day 5: Window Functions — practice labs (inline tiny datasets)
-- Run each block alone in Athena (engine v3). No S3 / Glue tables required.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Lab 0 warm-up — see the 6 practice trips (optional)
-- -----------------------------------------------------------------------------
SELECT *
FROM (
    VALUES
        ('T1', 'Hyderabad',  120.00),
        ('T2', 'Hyderabad',   90.00),
        ('T3', 'Hyderabad',   85.00),
        ('T4', 'Bengaluru',  200.00),
        ('T5', 'Bengaluru',  150.00),
        ('T6', 'Bengaluru',   40.00)
) AS practice_trips(trip_id, city, fare_amount);

-- -----------------------------------------------------------------------------
-- Demo — LAG / LEAD on 5 daily revenue rows (pre-aggregated toy data)
-- -----------------------------------------------------------------------------
WITH daily_revenue AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2025-01-01', 100.0),
            (DATE '2025-01-02', 150.0),
            (DATE '2025-01-03', 120.0),
            (DATE '2025-01-04', 180.0),
            (DATE '2025-01-05',  90.0)
    ) AS d(sale_day, daily_revenue)
)
SELECT
    sale_day,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY sale_day) AS prev_day_revenue,
    LEAD(daily_revenue, 1) OVER (ORDER BY sale_day) AS next_day_revenue
FROM daily_revenue
ORDER BY sale_day;

-- -----------------------------------------------------------------------------
-- Lab 1 — Highest fare in each city (Hyderabad vs Bengaluru · 6 trips)
-- Expected winners: Hyderabad 120, Bengaluru 200
-- -----------------------------------------------------------------------------
WITH practice_trips AS (
    SELECT *
    FROM (
        VALUES
            ('T1', 'Hyderabad',  120.00),
            ('T2', 'Hyderabad',   90.00),
            ('T3', 'Hyderabad',   85.00),
            ('T4', 'Bengaluru',  200.00),
            ('T5', 'Bengaluru',  150.00),
            ('T6', 'Bengaluru',   40.00)
    ) AS t(trip_id, city, fare_amount)
),
ranked AS (
    SELECT
        trip_id,
        city,
        fare_amount,
        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY fare_amount DESC
        ) AS trip_rank
    FROM practice_trips
)
SELECT city, trip_id, fare_amount, trip_rank
FROM ranked
WHERE trip_rank = 1
ORDER BY city;

-- -----------------------------------------------------------------------------
-- Lab 2 — Daily revenue + yesterday (LAG) on toy 5-day series
-- -----------------------------------------------------------------------------
WITH daily_revenue AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2025-01-01', 100.0),
            (DATE '2025-01-02', 150.0),
            (DATE '2025-01-03', 120.0),
            (DATE '2025-01-04', 180.0),
            (DATE '2025-01-05',  90.0)
    ) AS d(sale_day, daily_revenue)
)
SELECT
    sale_day,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY sale_day) AS yesterday_revenue
FROM daily_revenue
ORDER BY sale_day;

-- -----------------------------------------------------------------------------
-- Lab 3 — Tiny org chart (3 people) · RECURSIVE depth levels
-- Anita -> Rahul -> Priya
-- -----------------------------------------------------------------------------
WITH
employees AS (
    SELECT *
    FROM (
        VALUES
            (1, 'Anita', 'CEO',     CAST(NULL AS INTEGER)),
            (2, 'Rahul', 'Manager', 1),
            (3, 'Priya', 'Analyst', 2)
    ) AS e(emp_id, emp_name, role, manager_id)
),
RECURSIVE org_tree AS (
    SELECT emp_id, emp_name, role, 1 AS lvl
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.role, t.lvl + 1
    FROM employees e
    INNER JOIN org_tree t
        ON e.manager_id = t.emp_id
    WHERE t.lvl < 5
)
SELECT emp_id, emp_name, role, lvl
FROM org_tree
ORDER BY lvl, emp_id;

-- -----------------------------------------------------------------------------
-- Challenge — 2nd busiest day by visit_count (Hyderabad · 5 days)
-- Expected: 2025-01-03 with 18 visits (rank 2 after Jan 2 with 25)
-- -----------------------------------------------------------------------------
WITH visits_per_day AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2025-01-01', 10),
            (DATE '2025-01-02', 25),
            (DATE '2025-01-03', 18),
            (DATE '2025-01-04', 12),
            (DATE '2025-01-05',  8)
    ) AS v(visit_day, visit_count)
),
ranked_days AS (
    SELECT
        visit_day,
        visit_count,
        RANK() OVER (ORDER BY visit_count DESC) AS day_rank
    FROM visits_per_day
)
SELECT visit_day, visit_count
FROM ranked_days
WHERE day_rank = 2;