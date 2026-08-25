/*
===============================================================================
Report: gold.report_customers
===============================================================================
Purpose:
    Customer-level report mart (grain: one row per customer). Consolidates
    identity fields with aggregated behavior and derived KPIs/segments.

Highlights:
    - Base metrics: total orders, sales, quantity, distinct products
    - Dates: first/last order, lifespan (months), recency (months)
    - Segments: age_group and customer_segment (VIP / Regular / New)

Depends on: gold.fact_sales, gold.dim_customers, gold.dim_date
===============================================================================
*/

DROP VIEW IF EXISTS gold.report_customers;

CREATE VIEW gold.report_customers AS
WITH base_query AS (
	SELECT
		c.customer_key,
		c.customer_number,
		c.first_name,
		c.last_name,
		c.birthdate,
		f.order_number,
		f.product_key,
		f.sales_amount,
		f.quantity,
		dd.full_date
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
	LEFT JOIN gold.dim_date dd ON f.order_date_key = dd.date_key
),
customer_aggregation AS (
	SELECT
		customer_key,
		customer_number,
		first_name,
		last_name,
		birthdate,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(DISTINCT product_key) AS total_products,
		MIN(full_date) AS first_order,
		MAX(full_date) AS last_order
	FROM base_query
	GROUP BY
		customer_key,
		customer_number,
		first_name,
		last_name,
		birthdate
),
customer_metrics AS (
	SELECT
		*,
		EXTRACT(YEAR FROM AGE(birthdate))::INT AS age,
		EXTRACT(YEAR FROM AGE(last_order, first_order)) * 12
			+ EXTRACT(MONTH FROM AGE(last_order, first_order)) AS lifespan,
		EXTRACT(YEAR FROM AGE(last_order)) * 12
			+ EXTRACT(MONTH FROM AGE(last_order)) AS recency
	FROM customer_aggregation
)
SELECT
	*,
	CASE
		WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN '20-29'
		WHEN age BETWEEN 30 AND 39 THEN '30-39'
		WHEN age BETWEEN 40 AND 49 THEN '40-49'
		ELSE '50 and above'
	END AS age_group,
	CASE
		WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END AS customer_segment
FROM customer_metrics;
