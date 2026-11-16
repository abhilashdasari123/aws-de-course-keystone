-- =============================================================================
-- Week 1 Day 4: Basic SQL & Relational Refresher — Olist E-Commerce on S3
-- Bucket: s3://aws-de-keystone-datasets/olist/
-- Target: Amazon Athena (Glue Data Catalog)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Lab 1 — Join warmup (run ONE query at a time in Athena)
-- -----------------------------------------------------------------------------
-- (1) INNER JOIN — orders with at least one line item
SELECT o.order_id, o.order_status, oi.product_id, oi.price
FROM de_keystone_shared.olist_orders o
INNER JOIN de_keystone_shared.olist_order_items oi
    ON o.order_id = oi.order_id
LIMIT 5;

-- (2) LEFT JOIN — delivered orders, review columns NULL when missing
SELECT o.order_id, o.order_status, r.review_id, r.review_score
FROM de_keystone_shared.olist_orders o
LEFT JOIN de_keystone_shared.olist_order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
LIMIT 5;

-- (3) Anti-join pattern — delivered, no review row
SELECT o.order_id, o.order_status
FROM de_keystone_shared.olist_orders o
LEFT JOIN de_keystone_shared.olist_order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND r.review_id IS NULL
LIMIT 5;

-- (4) INNER chain — order → item → product (row multiply)
SELECT o.order_id, oi.order_item_id, p.product_category_name
FROM de_keystone_shared.olist_orders o
INNER JOIN de_keystone_shared.olist_order_items oi ON o.order_id = oi.order_id
INNER JOIN de_keystone_shared.olist_products p ON oi.product_id = p.product_id
LIMIT 8;

-- (5) LEFT JOIN — Parquet category + CSV English label
SELECT p.product_category_name, cat.product_category_name_english
FROM de_keystone_shared.olist_products p
LEFT JOIN de_keystone_shared.olist_category_translation cat
    ON p.product_category_name = cat.product_category_name
LIMIT 5;

-- -----------------------------------------------------------------------------
-- Lab 2 — NULL handling, COALESCE, CASE WHEN (delivery SLA on orders)
-- -----------------------------------------------------------------------------
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    -- Fallback timestamp: use actual delivery, else estimated (still NULL if both missing)
    COALESCE(
        order_delivered_customer_date,
        order_estimated_delivery_date
    ) AS effective_delivery_ts,
    -- Label bucket for ops — evaluate status/NULL before comparing dates
    CASE
        WHEN order_status IN ('canceled', 'unavailable') THEN 'In Transit / Canceled'
        WHEN order_delivered_customer_date IS NULL THEN 'In Transit / Canceled'
        WHEN order_delivered_customer_date < order_estimated_delivery_date THEN 'Delivered Early'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time'
    END AS delivery_sla
FROM de_keystone_shared.olist_orders
WHERE order_purchase_timestamp >= TIMESTAMP '2017-01-01'  -- row filter (pre-aggregate)
ORDER BY order_purchase_timestamp
-- sample for inspection, not full report (LIMIT below)
LIMIT 20;

-- -----------------------------------------------------------------------------
-- Lab 3 — Cross-format join chain + anti-join (unreviewed delivered orders)
-- -----------------------------------------------------------------------------
SELECT
    o.order_id,
    o.order_status,
    COUNT(DISTINCT oi.order_item_id) AS item_count,   -- line items per order (not COUNT(*))
    ROUND(SUM(oi.price), 2) AS order_gmv,              -- revenue at order grain after GROUP BY
    cat.product_category_name_english,                 -- from CSV dimension (may be NULL)
    r.review_score                                     -- always NULL here, in GROUP BY for SQL rules
FROM de_keystone_shared.olist_orders o
INNER JOIN de_keystone_shared.olist_order_items oi    -- must have line items
    ON o.order_id = oi.order_id
INNER JOIN de_keystone_shared.olist_products p
    ON oi.product_id = p.product_id
LEFT JOIN de_keystone_shared.olist_category_translation cat  -- Parquet → CSV
    ON p.product_category_name = cat.product_category_name
LEFT JOIN de_keystone_shared.olist_order_reviews r           -- keep all orders
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'                  -- row filter before grouping
  AND r.review_id IS NULL                          -- anti-join: no review row on the right
GROUP BY
    o.order_id,
    o.order_status,
    cat.product_category_name_english,
    r.review_score
ORDER BY order_gmv DESC                            -- highest-value outreach queue first
LIMIT 25;

-- -----------------------------------------------------------------------------
-- Lab 4 — GROUP BY product category + HAVING on revenue
-- -----------------------------------------------------------------------------
SELECT
    cat.product_category_name_english AS category,     -- grain: one row per English category
    COUNT(DISTINCT o.order_id) AS distinct_orders,   -- orders, not multiplied line items
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight    -- avg per line item in category
FROM de_keystone_shared.olist_orders o
INNER JOIN de_keystone_shared.olist_order_items oi    -- same join chain as Lab 3
    ON o.order_id = oi.order_id
INNER JOIN de_keystone_shared.olist_products p
    ON oi.product_id = p.product_id
LEFT JOIN de_keystone_shared.olist_category_translation cat
    ON p.product_category_name = cat.product_category_name
GROUP BY cat.product_category_name_english           -- collapse to category buckets
HAVING SUM(oi.price) > 10000                         -- filter groups (cannot go in WHERE)
ORDER BY total_revenue DESC;

-- -----------------------------------------------------------------------------
-- Challenge — Top 5 sellers: ≥20 delivered orders, avg review < 3.5
-- -----------------------------------------------------------------------------
WITH seller_order_stats AS (
    SELECT
        oi.seller_id,
        o.order_id,
        AVG(r.review_score) AS order_avg_review
    FROM de_keystone_shared.olist_order_items oi
    INNER JOIN de_keystone_shared.olist_orders o
        ON oi.order_id = o.order_id
    LEFT JOIN de_keystone_shared.olist_order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, o.order_id
),
seller_agg AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS delivered_orders,
        AVG(order_avg_review) AS avg_review_score
    FROM seller_order_stats
    GROUP BY seller_id
    HAVING COUNT(DISTINCT order_id) >= 20
       AND AVG(order_avg_review) < 3.5
)
SELECT seller_id, delivered_orders, ROUND(avg_review_score, 2) AS avg_review_score
FROM seller_agg
ORDER BY avg_review_score ASC, delivered_orders DESC
LIMIT 5;