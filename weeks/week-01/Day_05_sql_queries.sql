-- =============================================================================
-- Week 1 Day 5: Window Functions & Modular CTEs — NYC Taxi + HR on Athena
-- Database: de_keystone_shared
-- Tables: nyc_yellow_trips, nyc_taxi_zone_lookup, employees_hierarchy (or hr_employees)
-- Engine: Athena engine v3 (WITH RECURSIVE supported)
-- =============================================================================
-- Table-name note: if SHOW TABLES lists hr_employees instead of employees_hierarchy,
-- replace the table name in Lab 3 / recursive demos only.
-- Zone lookup columns: LocationID, Borough, Zone (standard NYC TLC lookup file).

-- -----------------------------------------------------------------------------
-- Sanity check — confirm January 2025 partitions & borough join (run once)
-- -----------------------------------------------------------------------------
SELECT t.year, t.month, z.Borough, COUNT(*) AS trips
FROM de_keystone_shared.nyc_yellow_trips t
INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
    ON t.PULocationID = z.LocationID
WHERE t.year = '2025'
  AND t.month = '01'
  AND z.Borough IN ('Manhattan', 'Queens', 'Brooklyn')
GROUP BY 1, 2, 3
ORDER BY trips DESC;

-- -----------------------------------------------------------------------------
-- Module 2 demo — LAG / LEAD / 3-day rolling average (Manhattan, Jan 1–10 2025)
-- Run as ONE statement in Athena
-- -----------------------------------------------------------------------------
WITH daily_manhattan AS (
    SELECT
        CAST(DATE(t.tpep_pickup_datetime) AS date) AS trip_day,
        ROUND(SUM(t.fare_amount), 2) AS daily_revenue
    FROM de_keystone_shared.nyc_yellow_trips t
    INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
        ON t.PULocationID = z.LocationID
    WHERE t.year = '2025'
      AND t.month = '01'
      AND z.Borough = 'Manhattan'
      AND CAST(DATE(t.tpep_pickup_datetime) AS date)
          BETWEEN DATE '2025-01-01' AND DATE '2025-01-10'
    GROUP BY 1
),
with_windows AS (
    SELECT
        trip_day,
        daily_revenue,
        LAG(daily_revenue, 1) OVER (ORDER BY trip_day) AS prev_day_revenue,
        LEAD(daily_revenue, 1) OVER (ORDER BY trip_day) AS next_day_revenue,
        daily_revenue
            - LAG(daily_revenue, 1) OVER (ORDER BY trip_day) AS dollar_change_from_yesterday,
        ROUND(
            AVG(daily_revenue) OVER (
                ORDER BY trip_day
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_avg_3day
    FROM daily_manhattan
)
SELECT *
FROM with_windows
ORDER BY trip_day;

-- -----------------------------------------------------------------------------
-- Lab 1 — Top 2 highest-fare trips per borough (Manhattan, Queens, Brooklyn)
-- January 2025 · DENSE_RANK · filter rank in outer query
-- -----------------------------------------------------------------------------
WITH trip_with_borough AS (
    SELECT
        t.tpep_pickup_datetime,
        t.fare_amount,
        t.total_amount,
        t.trip_distance,
        z.Borough,
        z.Zone,
        t.PULocationID
    FROM de_keystone_shared.nyc_yellow_trips t
    INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
        ON t.PULocationID = z.LocationID
    WHERE t.year = '2025'
      AND t.month = '01'
      AND z.Borough IN ('Manhattan', 'Queens', 'Brooklyn')
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY Borough
            ORDER BY fare_amount DESC
        ) AS fare_rnk
    FROM trip_with_borough
)
SELECT
    Borough,
    Zone,
    fare_amount,
    trip_distance,
    tpep_pickup_datetime,
    fare_rnk
FROM ranked
WHERE fare_rnk <= 2
ORDER BY Borough, fare_rnk, fare_amount DESC;

-- -----------------------------------------------------------------------------
-- Lab 2 — Manhattan daily revenue: LAG, change, 3-day rolling average (Jan 1–10)
-- -----------------------------------------------------------------------------
WITH daily_manhattan AS (
    SELECT
        CAST(DATE(t.tpep_pickup_datetime) AS date) AS trip_day,
        ROUND(SUM(t.fare_amount), 2) AS daily_revenue
    FROM de_keystone_shared.nyc_yellow_trips t
    INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
        ON t.PULocationID = z.LocationID
    WHERE t.year = '2025'
      AND t.month = '01'
      AND z.Borough = 'Manhattan'
      AND CAST(DATE(t.tpep_pickup_datetime) AS date)
          BETWEEN DATE '2025-01-01' AND DATE '2025-01-10'
    GROUP BY 1
),
windowed AS (
    SELECT
        trip_day,
        daily_revenue,
        LAG(daily_revenue, 1) OVER (ORDER BY trip_day) AS yesterday_revenue,
        daily_revenue
            - LAG(daily_revenue, 1) OVER (ORDER BY trip_day) AS dollar_change_from_yesterday,
        ROUND(
            AVG(daily_revenue) OVER (
                ORDER BY trip_day
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS rolling_avg_3day
    FROM daily_manhattan
)
SELECT *
FROM windowed
ORDER BY trip_day;

-- -----------------------------------------------------------------------------
-- Lab 3 — Org chart from root (manager_id IS NULL): level + reporting path
-- Depth guard for Athena: lvl < 10
-- -----------------------------------------------------------------------------
WITH RECURSIVE org_tree AS (
    SELECT
        emp_id,
        emp_name,
        role,
        manager_id,
        1 AS lvl,
        CAST(emp_name AS varchar) AS reporting_path
    FROM de_keystone_shared.employees_hierarchy
    WHERE manager_id IS NULL
       OR TRIM(CAST(manager_id AS varchar)) = ''
    UNION ALL
    SELECT
        e.emp_id,
        e.emp_name,
        e.role,
        e.manager_id,
        t.lvl + 1,
        t.reporting_path || ' -> ' || e.emp_name
    FROM de_keystone_shared.employees_hierarchy e
    INNER JOIN org_tree t
        ON e.manager_id = t.emp_id
    WHERE t.lvl < 10
)
SELECT
    emp_id,
    emp_name,
    role,
    lvl,
    reporting_path
FROM org_tree
ORDER BY lvl, emp_id;

-- -----------------------------------------------------------------------------
-- Challenge — 2nd busiest pickup day per borough (Jan 2025) vs #1 day trip count
-- -----------------------------------------------------------------------------
WITH trip_days AS (
    SELECT
        z.Borough,
        CAST(DATE(t.tpep_pickup_datetime) AS date) AS trip_day,
        COUNT(*) AS trip_count
    FROM de_keystone_shared.nyc_yellow_trips t
    INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
        ON t.PULocationID = z.LocationID
    WHERE t.year = '2025'
      AND t.month = '01'
      AND z.Borough IN ('Manhattan', 'Queens', 'Brooklyn', 'Bronx', 'Staten Island')
    GROUP BY 1, 2
),
ranked_days AS (
    SELECT
        Borough,
        trip_day,
        trip_count,
        RANK() OVER (
            PARTITION BY Borough
            ORDER BY trip_count DESC
        ) AS day_rank,
        MAX(trip_count) OVER (PARTITION BY Borough) AS busiest_day_trips
    FROM trip_days
)
SELECT
    Borough,
    trip_day AS second_busiest_day,
    trip_count AS trips_on_that_day,
    busiest_day_trips - trip_count AS trips_below_busiest_day
FROM ranked_days
WHERE day_rank = 2
ORDER BY Borough;