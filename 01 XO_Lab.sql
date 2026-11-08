--- SALES (Revenue, AOV, Order Volume)

-- Overall sales performance
SELECT
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(SUM(usd_price), 2) AS total_revenue,
    ROUND(AVG(usd_price), 2) AS aov,
    ROUND(MIN(usd_price), 2) AS min_order_value,
    ROUND(MAX(usd_price), 2) AS max_order_value
FROM orders;

-- Annual sales performance
SELECT
    EXTRACT(YEAR FROM purchase_ts) AS purchase_year,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(SUM(usd_price), 2) AS total_revenue,
    ROUND(AVG(usd_price), 2) AS aov
FROM orders
GROUP BY purchase_year
ORDER BY purchase_year;

-- Year-over-year revenue growth
WITH annual_revenue AS (
    SELECT
        EXTRACT(YEAR FROM purchase_ts) AS purchase_year,
        SUM(usd_price) AS total_revenue
    FROM orders
    GROUP BY purchase_year
),

revenue_growth AS (
    SELECT
        purchase_year,
        total_revenue,
        LAG(total_revenue) OVER (
            ORDER BY purchase_year
        ) AS previous_year_revenue
    FROM annual_revenue
)

SELECT
    purchase_year,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(previous_year_revenue, 2) AS previous_year_revenue,
    ROUND(
        (total_revenue - previous_year_revenue)
        / NULLIF(previous_year_revenue, 0) * 100,
        2
    ) AS revenue_growth_pct
FROM revenue_growth
ORDER BY purchase_year;

-- Monthly sales performance
SELECT
    DATE_TRUNC('month', purchase_ts)::DATE AS purchase_month,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(usd_price), 2) AS total_revenue,
    ROUND(AVG(usd_price), 2) AS aov
FROM orders
GROUP BY purchase_month
ORDER BY purchase_month;

-- Month-over-month revenue growth
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', purchase_ts)::DATE AS purchase_month,
        SUM(usd_price) AS total_revenue
    FROM orders
    GROUP BY purchase_month
),

revenue_trend AS (
    SELECT
        purchase_month,
        total_revenue,
        LAG(total_revenue) OVER (
            ORDER BY purchase_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    purchase_month,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        (total_revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0) * 100,
        2
    ) AS mom_growth_pct
FROM revenue_trend
ORDER BY purchase_month;

-- Quarterly sales performance
SELECT
    DATE_TRUNC('quarter', purchase_ts)::DATE AS purchase_quarter,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(usd_price), 2) AS total_revenue,
    ROUND(AVG(usd_price), 2) AS aov
FROM orders
GROUP BY purchase_quarter
ORDER BY purchase_quarter;

-- Quarterly revenue contribution by year
WITH quarterly_revenue AS (
    SELECT
        EXTRACT(YEAR FROM purchase_ts) AS purchase_year,
        EXTRACT(QUARTER FROM purchase_ts) AS purchase_quarter,
        SUM(usd_price) AS total_revenue
    FROM orders
    GROUP BY purchase_year, purchase_quarter
)

SELECT
    purchase_year,
    purchase_quarter,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        total_revenue /
        SUM(total_revenue) OVER (
            PARTITION BY purchase_year
        ) * 100,
        2
    ) AS annual_revenue_contribution_pct
FROM quarterly_revenue
ORDER BY purchase_year, purchase_quarter;

--- PRODUCTS
-- Overall product performance
SELECT
    product_name,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(usd_price), 2) AS total_revenue,
    ROUND(AVG(usd_price), 2) AS aov
FROM orders
GROUP BY product_name
ORDER BY total_revenue DESC;

--  Product revenue contribution
WITH product_revenue AS (
    SELECT
        product_name,
        ROUND(AVG(usd_price), 2) AS aov,
        COUNT(order_id) AS total_orders,
        SUM(usd_price) AS total_revenue
    FROM orders
    GROUP BY product_name
)

SELECT
    product_name,
    total_orders,
    aov,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        total_revenue /
        SUM(total_revenue) OVER () * 100,
        2
    ) AS revenue_contribution_pct
FROM product_revenue
ORDER BY total_revenue DESC;

-- Top 3 products by revenue
WITH product_ranking AS (
    SELECT
        product_name,
        SUM(usd_price) AS total_revenue,
        RANK() OVER (
            ORDER BY SUM(usd_price) DESC
        ) AS revenue_rank,
        COUNT(order_id) AS total_orders,
         ROUND(AVG(usd_price), 2) AS aov
    FROM orders
    GROUP BY product_name
)

SELECT
    revenue_rank,
    product_name,
    ROUND(total_revenue, 2) AS total_revenue,
    total_orders,
    aov
FROM product_ranking
WHERE revenue_rank <= 3
ORDER BY revenue_rank;

-- Annual product performance
SELECT
    EXTRACT(YEAR FROM purchase_ts) AS purchase_year,
    product_name,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(usd_price), 2) AS total_revenue,
    ROUND(AVG(usd_price), 2) AS aov
FROM orders
GROUP BY purchase_year, product_name
ORDER BY purchase_year, total_revenue DESC;

-- Top 3 products by revenue for each year
WITH annual_product_sales AS (
    SELECT
        EXTRACT(YEAR FROM purchase_ts) AS purchase_year,
        product_name,
        COUNT(order_id) AS total_orders,
        ROUND(AVG(usd_price), 2) AS aov,
        SUM(usd_price) AS total_revenue
    FROM orders
    GROUP BY purchase_year, product_name
),

product_ranking AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY purchase_year
            ORDER BY total_revenue DESC
        ) AS revenue_rank
    FROM annual_product_sales
)

SELECT
    purchase_year,
    revenue_rank,
    product_name,
    total_orders,
    aov,
    ROUND(total_revenue, 2) AS total_revenue
FROM product_ranking
WHERE revenue_rank <= 3
ORDER BY purchase_year, revenue_rank;

-- Overall refund performance
SELECT
    COUNT(o.order_id) AS total_orders,
    COUNT(os.order_id) FILTER (
        WHERE os.is_refund IS TRUE
    ) AS refund_count,
    ROUND(
        COUNT(os.order_id) FILTER (
            WHERE os.is_refund IS TRUE
        )::NUMERIC
        / NULLIF(COUNT(o.order_id), 0) * 100,
        2
    ) AS refund_rate_pct
FROM orders o
LEFT JOIN order_status os
    ON o.order_id = os.order_id;

-- Annual refund performance
SELECT
    EXTRACT(YEAR FROM o.purchase_ts) AS purchase_year,
    COUNT(o.order_id) AS total_orders,
    COUNT(os.order_id) FILTER (
        WHERE os.is_refund IS TRUE
    ) AS refund_count,
    ROUND(
        COUNT(os.order_id) FILTER (
            WHERE os.is_refund IS TRUE
        )::NUMERIC
        / NULLIF(COUNT(o.order_id), 0) * 100,
        2
    ) AS refund_rate_pct
FROM orders o
LEFT JOIN order_status os
    ON o.order_id = os.order_id
GROUP BY purchase_year
ORDER BY purchase_year;

-- Refund rate by product
SELECT
    o.product_name,
    COUNT(o.order_id) AS total_orders,
    COUNT(os.order_id) FILTER (
        WHERE os.is_refund IS TRUE
    ) AS refund_count,
    ROUND(
        COUNT(os.order_id) FILTER (
            WHERE os.is_refund IS TRUE
        )::NUMERIC
        / NULLIF(COUNT(o.order_id), 0) * 100,
        2
    ) AS refund_rate_pct
FROM orders o
LEFT JOIN order_status os
    ON o.order_id = os.order_id
GROUP BY o.product_name
ORDER BY refund_rate_pct DESC;

-- Annual refund rate by product
SELECT
    EXTRACT(YEAR FROM o.purchase_ts) AS purchase_year,
    o.product_name,
    COUNT(o.order_id) AS total_orders,
    COUNT(os.order_id) FILTER (
        WHERE os.is_refund IS TRUE
    ) AS refund_count,
    ROUND(
        COUNT(os.order_id) FILTER (
            WHERE os.is_refund IS TRUE
        )::NUMERIC
        / NULLIF(COUNT(o.order_id), 0) * 100,
        2
    ) AS refund_rate_pct
FROM orders o
LEFT JOIN order_status os
    ON o.order_id = os.order_id
GROUP BY purchase_year, o.product_name
ORDER BY purchase_year, refund_rate_pct DESC;

-- SHIPPING COURIER
-- Average delivery time by region
SELECT
    g.region,
    COUNT(os.order_id) AS delivered_orders,
    ROUND(AVG(os.delivery_days), 2) AS avg_delivery_days,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY os.delivery_days
        )::NUMERIC,
        2
    ) AS median_delivery_days,
    COUNT(os.order_id) FILTER (
        WHERE os.is_weird_deliver IS TRUE
    ) AS unusual_delivery_count
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
JOIN geo_lookup g
    ON c.country_code = g.country_code
JOIN order_status os
    ON o.order_id = os.order_id
GROUP BY g.region
ORDER BY avg_delivery_days ASC;

-- Delivery performance by shipping carrier
SELECT
    o.shipping_carrier,
    COUNT(os.order_id) AS delivered_orders,
    ROUND(AVG(os.delivery_days), 2) AS avg_delivery_days,
    COUNT(os.order_id) FILTER (
        WHERE os.is_weird_deliver IS TRUE
    ) AS unusual_delivery_count
FROM orders o
JOIN order_status os
    ON o.order_id = os.order_id
WHERE os.delivery_days IS NOT NULL
GROUP BY o.shipping_carrier
ORDER BY avg_delivery_days ASC;

--- CUSTOMER & COMMERCIAL PERFORMANCE
-- Annual sales performance by loyalty status
SELECT
    EXTRACT(YEAR FROM o.purchase_ts) AS purchase_year,
    c.loyalty_program,
    COUNT(o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    ROUND(SUM(o.usd_price), 2) AS total_revenue,
    ROUND(AVG(o.usd_price), 2) AS aov
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
GROUP BY purchase_year, c.loyalty_program
ORDER BY purchase_year, c.loyalty_program;

-- Loyalty revenue contribution by year
WITH loyalty_revenue AS (
    SELECT
        EXTRACT(YEAR FROM o.purchase_ts) AS purchase_year,
        c.loyalty_program,
        SUM(o.usd_price) AS total_revenue
    FROM orders o
    JOIN customer c
        ON o.customer_id = c.customer_id
    GROUP BY purchase_year, c.loyalty_program
)

SELECT
    purchase_year,
    loyalty_program,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        total_revenue /
        SUM(total_revenue) OVER (
            PARTITION BY purchase_year
        ) * 100,
        2
    ) AS revenue_contribution_pct
FROM loyalty_revenue
ORDER BY purchase_year, loyalty_program;

-- Purchase frequency by loyalty status
WITH customer_orders AS (
    SELECT
        o.customer_id,
        c.loyalty_program,
        COUNT(o.order_id) AS total_orders,
        SUM(o.usd_price) AS total_spending
    FROM orders o
    JOIN customer c
        ON o.customer_id = c.customer_id
    GROUP BY o.customer_id, c.loyalty_program
)

SELECT
    loyalty_program,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(total_spending), 2) AS avg_customer_spending
FROM customer_orders
GROUP BY loyalty_program
ORDER BY avg_orders_per_customer DESC;

-- Sales performance by region
SELECT
    g.region,
    COUNT(o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    ROUND(SUM(o.usd_price), 2) AS total_revenue,
    ROUND(AVG(o.usd_price), 2) AS aov
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
JOIN geo_lookup g
    ON c.country_code = g.country_code
GROUP BY g.region
ORDER BY total_revenue DESC;

-- Annual sales performance by region
SELECT
    EXTRACT(YEAR FROM o.purchase_ts) AS purchase_year,
    g.region,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.usd_price), 2) AS total_revenue,
    ROUND(AVG(o.usd_price), 2) AS aov
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
JOIN geo_lookup g
    ON c.country_code = g.country_code
GROUP BY purchase_year, g.region
ORDER BY purchase_year, total_revenue DESC;

-- Sales performance by marketing channel
SELECT
    c.marketing_channel,
    COUNT(o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    ROUND(SUM(o.usd_price), 2) AS total_revenue,
    ROUND(AVG(o.usd_price), 2) AS aov
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
GROUP BY c.marketing_channel
ORDER BY total_revenue DESC;

-- Annual marketing channel performance
SELECT
    EXTRACT(YEAR FROM o.purchase_ts) AS purchase_year,
    c.marketing_channel,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.usd_price), 2) AS total_revenue,
    ROUND(AVG(o.usd_price), 2) AS aov
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
GROUP BY purchase_year, c.marketing_channel
ORDER BY purchase_year, total_revenue DESC;

-- Regional sales performance by marketing channel
SELECT
    g.region,
    c.marketing_channel,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.usd_price), 2) AS total_revenue,
    ROUND(AVG(o.usd_price), 2) AS aov
FROM orders o
JOIN customer c
    ON o.customer_id = c.customer_id
JOIN geo_lookup g
    ON c.country_code = g.country_code
GROUP BY g.region, c.marketing_channel
ORDER BY g.region, total_revenue DESC;

-- Top 15 Customer purchase frequency
SELECT
    customer_id,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(usd_price), 2) AS total_spending,
    ROUND(AVG(usd_price), 2) AS avg_order_value
FROM orders
GROUP BY customer_id
ORDER BY total_orders DESC, total_spending DESC LIMIT 15;

-- Repeat customer distribution
WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(order_id) AS total_orders
    FROM orders
    GROUP BY customer_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        WHEN total_orders BETWEEN 2 AND 3 THEN 'Occasional Customer'
        WHEN total_orders BETWEEN 4 AND 5 THEN 'Frequent Customer'
        ELSE 'High-frequency Customer'
    END AS customer_segment,
    COUNT(customer_id) AS total_customers
FROM customer_orders
GROUP BY customer_segment
ORDER BY total_customers DESC;

