/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the 'gold' layer in the data warehouse.
    The gold layer represents the final dimension and fact tables (star schema).

    Each view performs transformations and combines data from the silver layer
    to produce a clean, enriched, business-ready dataset.

Note on drop order:
    fact_sales depends on dim_customers and dim_products, so it must be dropped
    BEFORE them. All drops are grouped here in reverse-dependency order, and the
    views are then (re)created in forward-dependency order (dimensions first).
===============================================================================
*/

-- Drop existing gold views (dependents first)
DROP VIEW IF EXISTS gold.fact_sales;
DROP VIEW IF EXISTS gold.dim_customers;
DROP VIEW IF EXISTS gold.dim_products;
DROP VIEW IF EXISTS gold.dim_date;

-- ====================================================================
-- Create Dimension: gold.dim_customers
-- ====================================================================
CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER(ORDER BY cst_id ASC) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	ela.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE
		WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr   -- Master is CRM
		ELSE COALESCE(eca.gen, 'n/a')                -- ERP is sub source
	END AS gender,
	eca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 eca ON ci.cst_key = eca.cid
LEFT JOIN silver.erp_loc_a101  ela ON ci.cst_key = ela.cid;

-- ====================================================================
-- Create Dimension: gold.dim_products
-- ====================================================================
CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER(ORDER BY pn.prd_id ASC) AS product_key,
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	pn.prd_cost AS product_cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL; -- Filter out all historical data

-- ====================================================================
-- Create Dimension: gold.dim_date
-- ====================================================================
CREATE VIEW gold.dim_date AS
WITH date_series AS (
	SELECT generate_series(
		'2010-01-01'::date,   -- earliest date in fact_sales (order_date)
		'2014-12-31'::date,   -- latest date in fact_sales (due_date), rounded to full year
		'1 day'::interval
	)::date AS full_date
)
SELECT
	TO_CHAR(full_date, 'YYYYMMDD')::INT AS date_key,
	full_date,
	EXTRACT(YEAR FROM full_date)::INT AS year,
	EXTRACT(QUARTER FROM full_date)::INT AS quarter,
	EXTRACT(MONTH FROM full_date)::INT AS month,
	TRIM(TO_CHAR(full_date, 'Month')) AS month_name,
	EXTRACT(DAY FROM full_date)::INT AS day,
	EXTRACT(ISODOW FROM full_date)::INT AS day_of_week,   -- 1=Monday ... 7=Sunday
	TRIM(TO_CHAR(full_date, 'Day')) AS day_name,
	EXTRACT(WEEK FROM full_date)::INT AS week_of_year,
	CASE WHEN EXTRACT(ISODOW FROM full_date) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM date_series;

-- ====================================================================
-- Create Fact: gold.fact_sales
-- ====================================================================
CREATE VIEW gold.fact_sales AS
SELECT
	sd.sls_ord_num AS order_number,
	dp.product_key,
	dc.customer_key,
	TO_CHAR(sd.sls_order_dt, 'YYYYMMDD')::INT AS order_date_key,
	TO_CHAR(sd.sls_ship_dt,  'YYYYMMDD')::INT AS shipping_date_key,
	TO_CHAR(sd.sls_due_dt,   'YYYYMMDD')::INT AS due_date_key,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_customers dc ON sd.sls_cust_id = dc.customer_id
LEFT JOIN gold.dim_products  dp ON sd.sls_prd_key = dp.product_number;
