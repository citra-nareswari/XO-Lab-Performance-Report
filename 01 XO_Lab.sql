-- 1. Earliest and latest order date
SELECT 
  MIN(purchase_ts) AS earliest_order,
  MAX(purchase_ts) AS latest_order
FROM orders;

-- 2. AOV for purchases made in USD in 2019
SELECT
  ROUND(AVG(usd_price)::NUMERIC, 2) AS usd_aov
FROM orders
WHERE currency = 'USD'
  AND EXTRACT(YEAR FROM purchase_ts) = 2019;

-- 3. Account creation (desktop & mobile)
SELECT 
  id AS customer_id,
  loyalty_program AS is_loyalty_customer,
  created_on AS account_created_on
FROM customer
WHERE account_creation_method IN ('desktop', 'mobile');

-- 4. Account creation with loyalty label
SELECT 
  id AS customer_id,
  created_on,
  CASE
    WHEN loyalty_program = 0 THEN 'Non_loyalty_member'
    ELSE 'Loyalty_member'
  END AS loyalty_program_status
FROM customer
WHERE account_creation_method IN ('desktop', 'mobile')
ORDER BY created_on;

-- 5. Unique products sold in AUD via mobile app
SELECT DISTINCT product_name
FROM orders
WHERE currency = 'AUD'
  AND purchase_platform = 'mobile app'
ORDER BY product_name;

-- 6. First 10 countries in North America
SELECT country_code
FROM geo_lookup
WHERE region = 'NA'
ORDER BY country_code DESC
LIMIT 10;

-- 7. Customers in North America
SELECT
  c.country_code,
  g.region
FROM customer c
JOIN geo_lookup g 
  ON c.country_code = g.country_code
WHERE g.region = 'NA'
ORDER BY c.country_code
LIMIT 10;

-- 8. Total number of orders by shipping month
SELECT
  DATE_TRUNC('month', ship_ts) AS ship_month,
  COUNT(order_id) AS order_count
FROM order_status
GROUP BY ship_month
ORDER BY ship_month DESC;

-- 9. Overall AOV
SELECT
  ROUND(AVG(usd_price)::NUMERIC, 2) AS aov
FROM orders;

-- 10. Refund flag
SELECT 
  *,
  (refund_ts IS NOT NULL) AS is_refund
FROM order_status
LIMIT 20;

-- 11. Razer laptop variants
SELECT DISTINCT product_id,
  product_name
FROM orders
WHERE LOWER(product_name) LIKE '%razer%'
  AND LOWER(product_name) LIKE '%laptop%';

-- 12. Days to ship
SELECT 
  *,
  (ship_ts::DATE - purchase_ts::DATE) AS days_to_ship
FROM order_status;

-- 13. Razer laptop performance in North America (quarterly)
SELECT 
  DATE_TRUNC('quarter', o.purchase_ts) AS purchase_quarter,
  COUNT(o.id) AS order_count,
  ROUND(SUM(o.usd_price)::NUMERIC, 2) AS total_sales,
  ROUND(AVG(o.usd_price)::NUMERIC, 2) AS aov
FROM orders o
LEFT JOIN customer c
  ON o.customer_id = c.id
LEFT JOIN geo_lookup g
  ON c.country_code = g.country_code
WHERE g.region = 'NA'
  AND LOWER(o.product_name) LIKE '%razer%'
  AND LOWER(o.product_name) LIKE '%laptop%'
GROUP BY purchase_quarter
ORDER BY purchase_quarter DESC;

-- 14. Average quarterly metrics for Razer laptops
WITH quarterly_metrics AS (
  SELECT
    DATE_TRUNC('quarter', o.purchase_ts) AS purchase_quarter,
    COUNT(DISTINCT o.id) AS order_count,
    SUM(o.usd_price) AS total_sales
  FROM orders o
  LEFT JOIN customer c
    ON o.customer_id = c.id
  LEFT JOIN geo_lookup g
    ON c.country_code = g.country_code
  WHERE LOWER(o.product_name) LIKE '%razer%'
    AND LOWER(o.product_name) LIKE '%laptop%'
    AND g.region = 'NA'
  GROUP BY purchase_quarter
)
SELECT
  ROUND(AVG(order_count), 2) AS avg_quarter_orders,
  ROUND(AVG(total_sales), 2) AS avg_quarter_sales
FROM quarterly_metrics;

-- 15. Avg delivery time (weeks) by region
SELECT 
  g.region,
  AVG(EXTRACT(DAY FROM (os.delivery_ts - os.purchase_ts)) / 7.0) AS weeks_to_deliver
FROM orders o
LEFT JOIN customer c
  ON o.customer_id = c.id
LEFT JOIN order_status os
  ON o.id = os.order_id
LEFT JOIN geo_lookup g
  ON c.country_code = g.country_code
WHERE  
  (
    o.purchase_platform = 'website'
    AND EXTRACT(YEAR FROM o.purchase_ts) = 2022
  )
  OR
  (
    o.purchase_platform = 'mobile app'
  )
GROUP BY g.region
ORDER BY weeks_to_deliver DESC;

-- 16. Refund rate & count per product
SELECT
  o.product_name,
  COUNT(o.id) AS total_orders,
  COUNT(os.refund_ts) AS refund_count,
  ROUND(
    COUNT(os.refund_ts)::NUMERIC / COUNT(o.id),
    4
  ) AS refund_rate
FROM orders o
LEFT JOIN order_status os
  ON o.id = os.order_id
GROUP BY o.product_name
ORDER BY refund_rate DESC;