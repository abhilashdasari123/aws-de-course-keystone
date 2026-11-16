-- =============================================================================
-- Week 1 Day 5: Window Functions — practice tables + queries
-- Athena: pick your workgroup and a database (default or de_keystone_shared).
-- STEP 0 — Run EACH statement below ONCE to create tables (CTAS → Glue + S3).
-- Labs — Run one lab query at a time (reads from day05_* tables).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 0a — practice_trips (6 rows · Hyderabad & Bengaluru)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS day05_practice_trips;

CREATE TABLE day05_practice_trips
AS
SELECT *
FROM (
    VALUES
        ('T1', 'Hyderabad',  120.00),
        ('T2', 'Hyderabad',   90.00),
        ('T3', 'Hyderabad',   85.00),
        ('T4', 'Bengaluru',  200.00),
        ('T5', 'Bengaluru',  150.00),
        ('T6', 'Bengaluru',   40.00)
) AS t(trip_id, city, fare_amount);

-- -----------------------------------------------------------------------------
-- STEP 0b — daily_revenue (5 days · toy totals)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS day05_daily_revenue;

CREATE TABLE day05_daily_revenue
AS
SELECT *
FROM (
    VALUES
        (DATE '2025-01-01', 100.0),
        (DATE '2025-01-02', 150.0),
        (DATE '2025-01-03', 120.0),
        (DATE '2025-01-04', 180.0),
        (DATE '2025-01-05',  90.0)
) AS d(sale_day, daily_revenue);

-- -----------------------------------------------------------------------------
-- STEP 0c — employees (3 rows · mini org)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS day05_employees;

CREATE TABLE day05_employees
AS
SELECT *
FROM (
    VALUES
        (1, 'Anita', 'CEO',     CAST(NULL AS INTEGER)),
        (2, 'Rahul', 'Manager', 1),
        (3, 'Priya', 'Analyst', 2)
) AS e(emp_id, emp_name, role, manager_id);

-- -----------------------------------------------------------------------------
-- STEP 0d — visits_per_day (5 days · challenge data)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS day05_visits_per_day;

CREATE TABLE day05_visits_per_day
AS
SELECT *
FROM (
    VALUES
        (DATE '2025-01-01', 10),
        (DATE '2025-01-02', 25),
        (DATE '2025-01-03', 18),
        (DATE '2025-01-04', 12),
        (DATE '2025-01-05',  8)
) AS v(visit_day, visit_count);

-- -----------------------------------------------------------------------------
-- Verify (optional) — SELECT * FROM each day05_* table
-- -----------------------------------------------------------------------------
SELECT 'practice_trips' AS tbl, COUNT(*) AS rows FROM day05_practice_trips
UNION ALL
SELECT 'daily_revenue', COUNT(*) FROM day05_daily_revenue
UNION ALL
SELECT 'employees', COUNT(*) FROM day05_employees
UNION ALL
SELECT 'visits_per_day', COUNT(*) FROM day05_visits_per_day;

-- -----------------------------------------------------------------------------
-- Demo — LAG / LEAD on day05_daily_revenue
-- -----------------------------------------------------------------------------
SELECT
    sale_day,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY sale_day) AS prev_day_revenue,
    LEAD(daily_revenue, 1) OVER (ORDER BY sale_day) AS next_day_revenue
FROM day05_daily_revenue
ORDER BY sale_day;

-- -----------------------------------------------------------------------------
-- Lab 1 — Highest fare per city (expect Hyderabad 120, Bengaluru 200)
-- -----------------------------------------------------------------------------
WITH ranked AS (
    SELECT
        trip_id,
        city,
        fare_amount,
        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY fare_amount DESC
        ) AS trip_rank
    FROM day05_practice_trips
)
SELECT city, trip_id, fare_amount, trip_rank
FROM ranked
WHERE trip_rank = 1
ORDER BY city;

-- -----------------------------------------------------------------------------
-- Lab 2 — Yesterday revenue (LAG) on day05_daily_revenue
-- -----------------------------------------------------------------------------
SELECT
    sale_day,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY sale_day) AS yesterday_revenue
FROM day05_daily_revenue
ORDER BY sale_day;

-- -----------------------------------------------------------------------------
-- Lab 3 — Recursive levels on day05_employees
-- -----------------------------------------------------------------------------
WITH RECURSIVE org_tree AS (
    SELECT emp_id, emp_name, role, 1 AS lvl
    FROM day05_employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.role, t.lvl + 1
    FROM day05_employees e
    INNER JOIN org_tree t
        ON e.manager_id = t.emp_id
    WHERE t.lvl < 5
)
SELECT emp_id, emp_name, role, lvl
FROM org_tree
ORDER BY lvl, emp_id;

-- -----------------------------------------------------------------------------
-- Challenge — 2nd busiest day (expect 2025-01-03, 18 visits)
-- -----------------------------------------------------------------------------
WITH ranked_days AS (
    SELECT
        visit_day,
        visit_count,
        RANK() OVER (ORDER BY visit_count DESC) AS day_rank
    FROM day05_visits_per_day
)
SELECT visit_day, visit_count
FROM ranked_days
WHERE day_rank = 2;

-- -----------------------------------------------------------------------------
-- Cleanup (optional end of session)
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS day05_practice_trips;
-- DROP TABLE IF EXISTS day05_daily_revenue;
-- DROP TABLE IF EXISTS day05_employees;
-- DROP TABLE IF EXISTS day05_visits_per_day;