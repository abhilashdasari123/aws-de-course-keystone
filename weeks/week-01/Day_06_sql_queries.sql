-- =============================================================================
-- Week 1 Day 6: WITH RECURSIVE (hands-on) — DuckDB / Athena
-- Run setup statements once, then each example separately.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Setup — employees (org chart) and daily_sales (sparse dates)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS day06_employees;
DROP TABLE IF EXISTS day06_daily_sales;

CREATE TABLE day06_employees AS
SELECT * FROM (
    VALUES
        (1, 'Aarav', 'CEO',  CAST(NULL AS INT)),
        (2, 'Diya',  'VP',   1),
        (3, 'Kabir', 'Lead', 2),
        (4, 'Meera', 'Eng',  3)
) AS t(emp_id, name, role, mgr_id);

CREATE TABLE day06_daily_sales AS
SELECT * FROM (
    VALUES
        (DATE '2026-11-01', 1200.00),
        (DATE '2026-11-03', 800.00),
        (DATE '2026-11-06', 1500.00)
) AS t(sale_date, revenue);

-- -----------------------------------------------------------------------------
-- Example 1 — Org hierarchy + reporting chain
-- -----------------------------------------------------------------------------
WITH RECURSIVE org_tree AS (
    SELECT
        emp_id,
        name,
        role,
        mgr_id,
        1 AS depth,
        CAST(name AS VARCHAR) AS reporting_chain
    FROM day06_employees
    WHERE mgr_id IS NULL

    UNION ALL

    SELECT
        e.emp_id,
        e.name,
        e.role,
        e.mgr_id,
        t.depth + 1,
        t.reporting_chain || ' -> ' || e.name
    FROM day06_employees e
    INNER JOIN org_tree t ON e.mgr_id = t.emp_id
    WHERE t.depth < 10
)
SELECT emp_id, name, role, depth, reporting_chain
FROM org_tree
ORDER BY depth, emp_id;

-- -----------------------------------------------------------------------------
-- Example 2 — Date spine + LEFT JOIN (zero-sale days visible)
-- -----------------------------------------------------------------------------
WITH RECURSIVE date_spine AS (
    SELECT DATE '2026-11-01' AS sale_date
    UNION ALL
    SELECT sale_date + INTERVAL '1' DAY
    FROM date_spine
    WHERE sale_date < DATE '2026-11-07'
)
SELECT
    s.sale_date,
    COALESCE(d.revenue, 0) AS revenue
FROM date_spine s
LEFT JOIN day06_daily_sales d ON d.sale_date = s.sale_date
ORDER BY s.sale_date;

-- Athena alternative for date increment in spine:
-- SELECT date_add('day', 1, sale_date) FROM date_spine WHERE sale_date < DATE '2026-11-07'