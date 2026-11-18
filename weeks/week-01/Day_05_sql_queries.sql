-- =============================================================================
-- Week 1 Day 5: Window Functions — Live coding on day05_live_sales
-- Run DROP + CREATE once, then one lab query at a time in Athena.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Setup — day05_live_sales (14 rows, 6 columns)
-- Run DROP and CREATE as separate statements
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS day05_live_sales;

CREATE TABLE day05_live_sales AS
SELECT * FROM (
    VALUES
        (1, 'Anita',  'Enterprise', CAST(NULL AS INT), DATE '2026-01-01', 500),
        (1, 'Anita',  'Enterprise', CAST(NULL AS INT), DATE '2026-01-02', 700),
        (2, 'Rahul',  'Enterprise', 1,                 DATE '2026-01-01', 500),
        (2, 'Rahul',  'Enterprise', 1,                 DATE '2026-01-02', 400),
        (2, 'Rahul',  'Enterprise', 1,                 DATE '2026-01-03', 600),
        (3, 'Priya',  'Enterprise', 2,                 DATE '2026-01-01', 300),
        (3, 'Priya',  'Enterprise', 2,                 DATE '2026-01-02', 300),
        (4, 'Kabir',  'SMB',        1,                 DATE '2026-01-01', 450),
        (4, 'Kabir',  'SMB',        1,                 DATE '2026-01-02', 450),
        (4, 'Kabir',  'SMB',        1,                 DATE '2026-01-03', 800),
        (5, 'Meera',  'SMB',        4,                 DATE '2026-01-01', 200),
        (5, 'Meera',  'SMB',        4,                 DATE '2026-01-02', 350),
        (6, 'Vikram', 'SMB',        4,                 DATE '2026-01-02', 200),
        (6, 'Vikram', 'SMB',        4,                 DATE '2026-01-03', 250)
) AS t(emp_id, emp_name, dept, manager_id, sale_date, amount);

-- -----------------------------------------------------------------------------
-- Q1 — OVER() partition total
-- -----------------------------------------------------------------------------
SELECT
    emp_name,
    dept,
    amount,
    SUM(amount) OVER (PARTITION BY dept) AS dept_total
FROM day05_live_sales;

-- -----------------------------------------------------------------------------
-- Q2 — ROW_NUMBER vs RANK vs DENSE_RANK
-- -----------------------------------------------------------------------------
SELECT
    dept,
    emp_name,
    amount,
    ROW_NUMBER() OVER (PARTITION BY dept ORDER BY amount DESC) AS rn,
    RANK()       OVER (PARTITION BY dept ORDER BY amount DESC) AS rnk,
    DENSE_RANK() OVER (PARTITION BY dept ORDER BY amount DESC) AS dense_rnk
FROM day05_live_sales
ORDER BY dept, amount DESC;

-- -----------------------------------------------------------------------------
-- Q3 — CTE + ROW_NUMBER (top 1 per department)
-- -----------------------------------------------------------------------------
WITH ranked AS (
    SELECT
        dept,
        emp_name,
        amount,
        ROW_NUMBER() OVER (PARTITION BY dept ORDER BY amount DESC) AS rn
    FROM day05_live_sales
)
SELECT dept, emp_name, amount
FROM ranked
WHERE rn = 1;

-- -----------------------------------------------------------------------------
-- Q4 — CTE + DENSE_RANK (2nd highest per department)
-- -----------------------------------------------------------------------------
WITH ranked AS (
    SELECT
        dept,
        emp_name,
        amount,
        DENSE_RANK() OVER (PARTITION BY dept ORDER BY amount DESC) AS rnk
    FROM day05_live_sales
)
SELECT dept, emp_name, amount
FROM ranked
WHERE rnk = 2;

-- -----------------------------------------------------------------------------
-- Q5 — LAG (previous day) for Rahul and Kabir
-- -----------------------------------------------------------------------------
SELECT
    emp_name,
    sale_date,
    amount,
    LAG(amount, 1) OVER (PARTITION BY emp_name ORDER BY sale_date) AS yesterday_amount
FROM day05_live_sales
WHERE emp_name IN ('Rahul', 'Kabir')
ORDER BY emp_name, sale_date;

-- -----------------------------------------------------------------------------
-- Q6 — LEAD (next day) for Rahul and Kabir
-- -----------------------------------------------------------------------------
SELECT
    emp_name,
    sale_date,
    amount,
    LEAD(amount, 1) OVER (PARTITION BY emp_name ORDER BY sale_date) AS tomorrow_amount
FROM day05_live_sales
WHERE emp_name IN ('Rahul', 'Kabir')
ORDER BY emp_name, sale_date;

-- -----------------------------------------------------------------------------
-- Q7 — Running total (UNBOUNDED PRECEDING)
-- -----------------------------------------------------------------------------
SELECT
    emp_name,
    sale_date,
    amount,
    SUM(amount) OVER (
        PARTITION BY emp_name
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM day05_live_sales
WHERE emp_name IN ('Rahul', 'Kabir')
ORDER BY emp_name, sale_date;

-- -----------------------------------------------------------------------------
-- Q8 — Rolling 2-day average
-- -----------------------------------------------------------------------------
SELECT
    emp_name,
    sale_date,
    amount,
    AVG(amount) OVER (
        PARTITION BY emp_name
        ORDER BY sale_date
        ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
    ) AS rolling_2day_avg
FROM day05_live_sales
WHERE emp_name IN ('Rahul', 'Kabir')
ORDER BY emp_name, sale_date;

-- -----------------------------------------------------------------------------
-- Q9 — GROUP BY then rank employees
-- -----------------------------------------------------------------------------
WITH emp_totals AS (
    SELECT emp_name, dept, SUM(amount) AS total_sales
    FROM day05_live_sales
    GROUP BY emp_name, dept
)
SELECT
    emp_name,
    dept,
    total_sales,
    RANK() OVER (ORDER BY total_sales DESC) AS overall_rank
FROM emp_totals;

-- -----------------------------------------------------------------------------
-- Q10 — WITH RECURSIVE org chart from Anita
-- -----------------------------------------------------------------------------
WITH RECURSIVE
employees AS (
    SELECT DISTINCT emp_id, emp_name, dept, manager_id
    FROM day05_live_sales
),
org_tree AS (
    SELECT emp_id, emp_name, dept, 1 AS lvl
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.dept, t.lvl + 1
    FROM employees e
    JOIN org_tree t ON e.manager_id = t.emp_id
    WHERE t.lvl < 5
)
SELECT lvl, emp_name, dept
FROM org_tree
ORDER BY lvl, emp_id;