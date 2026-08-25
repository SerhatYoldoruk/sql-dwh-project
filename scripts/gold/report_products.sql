/*
===============================================================================
Report: gold.report_products
===============================================================================
Purpose:
    Product-level report mart (grain: one row per product). Consolidates
    product identity with aggregated sales behavior and derived KPIs/segments.

Highlights:
    - Base metrics: total orders, sales, quantity, distinct customers
    - Dates: first/last sale, lifespan (months)
    - Segment: product_segment (High-Performer / Mid-Range / Low-Performer)
    - KPIs: avg_order_revenue, avg_monthly_revenue

Depends on: gold.fact_sales, gold.dim_products, gold.dim_date
===============================================================================
*/

DROP VIEW IF EXISTS gold.report_products;

CREATE VIEW gold.report_products AS
WITH base_query AS (
	SELECT
		p.product_key,
		p.product_number,
		p.product_name,
		p.category,
		p.subcategory,
		p.product_cost,
		p.maintenance,
		p.product_line,
		f.order_number,
		f.quantity,
		f.sales_amount,
		f.customer_key,
		dd.full_date
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
	LEFT JOIN gold.dim_date dd ON f.order_date_key = dd.date_key
),
product_aggregation AS (
	SELECT
		product_key,
		product_number,
		product_name,
		category,
		subcategory,
		product_cost,
		maintenance,
		product_line,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(DISTINCT customer_key) AS total_customers,
		MIN(full_date) AS first_sale,
		MAX(full_date) AS last_sale
	FROM base_query
	GROUP BY
		product_key,
		product_number,
		product_name,
		category,
		subcategory,
		product_cost,
		maintenance,
		product_line
),
product_metrics AS (
	SELECT
		*,
		EXTRACT(YEAR FROM AGE(last_sale, first_sale)) * 12
			+ EXTRACT(MONTH FROM AGE(last_sale, first_sale)) AS lifespan,
		CASE
			WHEN total_sales > 50000 THEN 'High-Performer'
			WHEN total_sales >= 10000 THEN 'Mid-Range'
			ELSE 'Low-Performer'
		END AS product_segment
	FROM product_aggregation
)
SELECT
	*,
	total_sales / total_orders AS avg_order_revenue,
	ROUND(total_sales / NULLIF(lifespan, 0)) AS avg_monthly_revenue
FROM product_metrics;
