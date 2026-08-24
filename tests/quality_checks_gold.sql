/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Script Purpose:
    This script performs data quality checks on the 'gold' layer objects,
    verifying dimension uniqueness (grain integrity) and the correctness of
    the joins that build the star schema.
===============================================================================
*/

-- ====================================================================
-- gold.dim_customers
-- ====================================================================

-- Check for duplicates after joining CRM with the ERP customer tables.
-- If either ERP table has a duplicate cid, the LEFT JOIN would fan out
-- and a customer would appear on more than one row (broken grain).
-- Expectation: no results
SELECT
	cst_id,
	COUNT(*)
FROM (
	SELECT
		ci.cst_id,
		ci.cst_key,
		ci.cst_firstname,
		ci.cst_lastname,
		ci.cst_marital_status,
		ci.cst_gndr,
		ci.cst_create_date,
		ca.bdate,
		ca.gen,
		la.cntry
	FROM silver.crm_cust_info ci
	LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101  la ON ci.cst_key = la.cid
) t
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- ====================================================================
-- gold.dim_products
-- ====================================================================

-- Check that each product appears only once after the current-product
-- filter (prd_end_dt IS NULL). If a product_number shows up more than
-- once, the SCD end-date logic left more than one "current" version.
-- Expectation: no results
SELECT
	product_number,
	COUNT(*)
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- ====================================================================
-- gold.fact_sales
-- ====================================================================

-- Check that every sales record resolved to a customer and a product
-- (i.e. no lookup fell through to NULL). A NULL key means the business
-- key had no match in the dimension - a broken star-schema connection.
-- Expectation: no results
SELECT
	*
FROM gold.fact_sales
WHERE customer_key IS NULL
	OR product_key IS NULL;
