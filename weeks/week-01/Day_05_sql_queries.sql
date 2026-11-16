-- =============================================================================
-- Week 1 Day 5: Window Functions — NYC Taxi + HR (simplified labs)
-- Database: de_keystone_shared
-- Note: TLC zone file column is Borough — we alias it AS city in query results.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Sanity check — Jan 2025 trips with city name from lookup (run once)
-- -----------------------------------------------------------------------------
SELECT
    z.Borough AS city,
    COUNT(*) AS trips
FROM de_keystone_shared.nyc_yellow_trips t
INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
    ON t.PULocationID = z.LocationID
WHERE t.year = '2025'
  AND t.month = '01'
  AND z.Borough IN ('Manhattan', 'Queens')
GROUP BY 1
ORDER BY trips DESC;

-- -----------------------------------------------------------------------------
-- Demo — LAG on daily revenue (Manhattan · Jan 1–5 2025 · one statement)
-- -----------------------------------------------------------------------------
WITH daily_revenue AS (
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
          BETWEEN DATE '2025-01-01' AND DATE '2025-01-05'
    GROUP BY 1
)
SELECT
    trip_day,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY trip_day) AS prev_day_revenue,
    LEAD(daily_revenue, 1) OVER (ORDER BY trip_day) AS next_day_revenue
FROM daily_revenue
ORDER BY trip_day;

-- -----------------------------------------------------------------------------
-- Lab 1 — Highest-fare trip per city (Manhattan & Queens · Jan 2025)
-- -----------------------------------------------------------------------------
WITH trips_with_city AS (
    SELECT
        z.Borough AS city,
        t.fare_amount,
        t.tpep_pickup_datetime
    FROM de_keystone_shared.nyc_yellow_trips t
    INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
        ON t.PULocationID = z.LocationID
    WHERE t.year = '2025'
      AND t.month = '01'
      AND z.Borough IN ('Manhattan', 'Queens')
),
ranked AS (
    SELECT
        city,
        fare_amount,
        tpep_pickup_datetime,
        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY fare_amount DESC
        ) AS trip_rank
    FROM trips_with_city
)
SELECT
    city,
    fare_amount,
    tpep_pickup_datetime,
    trip_rank
FROM ranked
WHERE trip_rank = 1
ORDER BY city;

-- -----------------------------------------------------------------------------
-- Lab 2 — Manhattan daily revenue + yesterday (LAG) · Jan 1–5 2025
-- -----------------------------------------------------------------------------
WITH daily_revenue AS (
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
          BETWEEN DATE '2025-01-01' AND DATE '2025-01-05'
    GROUP BY 1
)
SELECT
    trip_day,
    daily_revenue,
    LAG(daily_revenue, 1) OVER (ORDER BY trip_day) AS yesterday_revenue
FROM daily_revenue
ORDER BY trip_day;

-- -----------------------------------------------------------------------------
-- Lab 3 — Org levels from CEO (simplified: name, role, level only)
-- Replace employees_hierarchy with hr_employees if needed
-- -----------------------------------------------------------------------------
WITH RECURSIVE org_tree AS (
    SELECT
        emp_id,
        emp_name,
        role,
        1 AS lvl
    FROM de_keystone_shared.employees_hierarchy
    WHERE manager_id IS NULL
       OR TRIM(CAST(manager_id AS varchar)) = ''
    UNION ALL
    SELECT
        e.emp_id,
        e.emp_name,
        e.role,
        t.lvl + 1
    FROM de_keystone_shared.employees_hierarchy e
    INNER JOIN org_tree t
        ON e.manager_id = t.emp_id
    WHERE t.lvl < 6
)
SELECT emp_id, emp_name, role, lvl
FROM org_tree
ORDER BY lvl, emp_id;

-- -----------------------------------------------------------------------------
-- Challenge — Manhattan: which day was 2nd-busiest by trip count (Jan 2025)
-- -----------------------------------------------------------------------------
WITH trips_per_day AS (
    SELECT
        CAST(DATE(t.tpep_pickup_datetime) AS date) AS trip_day,
        COUNT(*) AS trip_count
    FROM de_keystone_shared.nyc_yellow_trips t
    INNER JOIN de_keystone_shared.nyc_taxi_zone_lookup z
        ON t.PULocationID = z.LocationID
    WHERE t.year = '2025'
      AND t.month = '01'
      AND z.Borough = 'Manhattan'
    GROUP BY 1
),
ranked_days AS (
    SELECT
        trip_day,
        trip_count,
        RANK() OVER (ORDER BY trip_count DESC) AS day_rank
    FROM trips_per_day
)
SELECT trip_day, trip_count
FROM ranked_days
WHERE day_rank = 2;