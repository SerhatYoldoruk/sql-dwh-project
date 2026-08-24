/*
===============================================================================
Quality Checks: Silver Layer
===============================================================================
Script Purpose:
    This script performs data quality checks on the 'silver' schema tables,
    verifying primary key integrity, unwanted whitespace, and data
    standardization/consistency after cleaning from the bronze layer.
===============================================================================
*/

-- ====================================================================
-- silver.crm_cust_info
-- ====================================================================

-- Check for nulls or duplicates in primary key
-- Expectation: no results
SELECT
	cst_id,
	COUNT(*)
FROM
	silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check firstname for unwanted spaces
-- Expectation: no results
SELECT
	cst_firstname,
	TRIM(cst_firstname)
FROM
	silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Check lastname for unwanted spaces
-- Expectation: no results
SELECT
	cst_lastname,
	TRIM(cst_lastname)
FROM
	silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- Data Standardization & Consistency: gender
SELECT DISTINCT
	cst_gndr
FROM
	silver.crm_cust_info;

-- Data Standardization & Consistency: marital status
SELECT DISTINCT
	cst_marital_status
FROM
	silver.crm_cust_info;

SELECT * FROM silver.crm_cust_info;

-- ====================================================================
-- silver.crm_prd_info
-- ====================================================================

-- Check for nulls or duplicates in primary key
-- Expectation: no results
SELECT
	prd_id,
	COUNT(*)
FROM
	silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check that cat_id matches an existing category in erp_px_cat_g1v2
-- Expectation: no results
SELECT DISTINCT
	cat_id
FROM
	silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM bronze.erp_px_cat_g1v2);

-- Check prd_key for unwanted spaces
-- Expectation: no results
SELECT
	prd_key,
	TRIM(prd_key)
FROM
	silver.crm_prd_info
WHERE prd_key != TRIM(prd_key);

-- Check for negative or null costs
-- Expectation: no results
SELECT
	prd_cost
FROM
	silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization & Consistency: product line
SELECT DISTINCT
	prd_line
FROM
	silver.crm_prd_info;

-- Check for invalid date orders (end date before start date)
-- Expectation: no results
SELECT
	*
FROM
	silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

SELECT * FROM silver.crm_prd_info;

-- ====================================================================
-- silver.crm_sales_details
-- ====================================================================

-- Check for invalid date order (order date after ship/due date)
-- Expectation: no results
SELECT
	*
FROM
	silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- Check sales = quantity * price, and for nulls/negatives/zeros
-- Expectation: no results
SELECT
	sls_sales,
	sls_quantity,
	sls_price
FROM
	silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
	OR sls_sales IS NULL OR sls_sales <= 0
	OR sls_quantity IS NULL OR sls_quantity <= 0
	OR sls_price IS NULL OR sls_price <= 0;

-- Check sls_prd_key and sls_cust_id reference existing records
-- Expectation: no results
SELECT
	*
FROM
	silver.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)
	OR sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

SELECT * FROM silver.crm_sales_details;

-- ====================================================================
-- silver.erp_cust_az12
-- ====================================================================

-- Check cid still has a leftover 'NAS' prefix
-- Expectation: no results
SELECT
	cid
FROM
	silver.erp_cust_az12
WHERE cid LIKE 'NAS%';

-- Check for future birthdates
-- Expectation: no results
SELECT
	bdate
FROM
	silver.erp_cust_az12
WHERE bdate > CURRENT_DATE;

-- Data Standardization & Consistency: gender
SELECT DISTINCT
	gen
FROM
	silver.erp_cust_az12;

SELECT * FROM silver.erp_cust_az12;

-- ====================================================================
-- silver.erp_loc_a101
-- ====================================================================

-- Check cid still has a leftover '-'
-- Expectation: no results
SELECT
	cid
FROM
	silver.erp_loc_a101
WHERE cid LIKE '%-%';

-- Data Standardization & Consistency: country
SELECT DISTINCT
	cntry
FROM
	silver.erp_loc_a101;

SELECT * FROM silver.erp_loc_a101;

-- ====================================================================
-- silver.erp_px_cat_g1v2
-- ====================================================================

-- Check for nulls or duplicates in primary key
-- Expectation: no results
SELECT
	id,
	COUNT(*)
FROM
	silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL;

-- Check cat/subcat/maintenance for unwanted spaces
-- Expectation: no results
SELECT
	*
FROM
	silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

-- Data Standardization & Consistency: maintenance
SELECT DISTINCT
	maintenance
FROM
	silver.erp_px_cat_g1v2;

SELECT * FROM silver.erp_px_cat_g1v2;
