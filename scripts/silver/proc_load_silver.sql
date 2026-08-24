/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure cleans and loads data into the 'silver' schema from
    the 'bronze' schema. It performs the following actions:
    - Truncates the silver tables before loading data.
    - Deduplicates, trims, standardizes, and validates data from bronze tables,
      then inserts the cleaned data into silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL silver.load_silver();
===============================================================================
*/
CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
	start_time TIMESTAMP;
	end_time TIMESTAMP;
	batch_start_time TIMESTAMP;
	batch_end_time TIMESTAMP;
BEGIN

	batch_start_time := clock_timestamp();
	RAISE NOTICE '=========================';
	RAISE NOTICE 'Loading Silver Layer';
	RAISE NOTICE '=========================';

	RAISE NOTICE '-------------------------';
	RAISE NOTICE 'Loading CRM Tables';
	RAISE NOTICE '-------------------------';

	-- silver.crm_cust_info
	start_time := clock_timestamp();
	RAISE NOTICE 'Truncating Table: silver.crm_cust_info';
	TRUNCATE TABLE silver.crm_cust_info;

	RAISE NOTICE 'Inserting Data Into: silver.crm_cust_info';
	INSERT INTO silver.crm_cust_info (
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date
	)
	SELECT
		cst_id,
		cst_key,
		TRIM(cst_firstname) AS cst_firstname, -- Remove unwanted spaces
		TRIM(cst_lastname) AS cst_lastname, -- Remove unwanted spaces
		CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
			 WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
			 ELSE 'n/a'
		END AS cst_marital_status, -- Normalize marital status codes
		CASE WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
			 WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
			 ELSE 'n/a'
		END AS cst_gndr, -- Normalize gender codes
		cst_create_date
	FROM
		(SELECT
			*,
			ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL) t
	WHERE flag_last = 1;
	end_time := clock_timestamp();
	RAISE NOTICE 'Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));

	-- silver.crm_prd_info
	start_time := clock_timestamp();
	RAISE NOTICE 'Truncating Table: silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;

	RAISE NOTICE 'Inserting Data Into: silver.crm_prd_info';
	INSERT INTO silver.crm_prd_info (
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)
	SELECT
		prd_id,
		REPLACE(LEFT(prd_key,5), '-', '_') AS cat_id, -- Extract category ID
		SUBSTRING(prd_key,7, LENGTH(prd_key)) AS prd_key, -- Extract product key
		prd_nm,
		COALESCE(prd_cost, 0) AS prd_cost, -- Handle missing cost
		CASE UPPER(TRIM(prd_line))
			 WHEN 'M' THEN 'Mountain'
			 WHEN 'R' THEN 'Road'
			 WHEN 'S' THEN 'Other Sales'
			 WHEN 'T' THEN 'Touring'
			 ELSE 'n/a'
		END AS prd_line, -- Map product line codes to descriptive values
		prd_start_dt::date,
		(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt ASC) - INTERVAL '1 day')::date AS prd_end_dt -- Calculate end date as one day before the next start date
	FROM bronze.crm_prd_info;
	end_time := clock_timestamp();
	RAISE NOTICE 'Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));

	-- silver.crm_sales_details
	start_time := clock_timestamp();
	RAISE NOTICE 'Truncating Table: silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;

	RAISE NOTICE 'Inserting Data Into: silver.crm_sales_details';
	INSERT INTO silver.crm_sales_details (
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price
	)
	SELECT
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		CASE WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::TEXT) != 8 THEN NULL
			 ELSE (sls_order_dt::TEXT)::DATE
		END AS sls_order_dt, -- Handle invalid order dates
		CASE WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::TEXT) != 8 THEN NULL
			 ELSE (sls_ship_dt::TEXT)::DATE
		END AS sls_ship_dt, -- Handle invalid ship dates
		CASE WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::TEXT) != 8 THEN NULL
			 ELSE (sls_due_dt::TEXT)::DATE
		END AS sls_due_dt, -- Handle invalid due dates
		CASE WHEN sls_sales <= 0 OR sls_sales IS NULL OR sls_sales != sls_quantity*ABS(sls_price)
			 THEN sls_quantity*ABS(sls_price)
			 ELSE sls_sales
		END AS sls_sales, -- Recalculate sales if original value is missing or incorrect
		sls_quantity,
		CASE WHEN sls_price IS NULL OR sls_price <= 0
			 THEN sls_sales / NULLIF(sls_quantity,0)
			 ELSE sls_price
		END AS sls_price -- Derive price if original value is invalid
	FROM bronze.crm_sales_details;
	end_time := clock_timestamp();
	RAISE NOTICE 'Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));

	RAISE NOTICE '-------------------------';
	RAISE NOTICE 'Loading ERP Tables';
	RAISE NOTICE '-------------------------';

	-- silver.erp_cust_az12
	start_time := clock_timestamp();
	RAISE NOTICE 'Truncating Table: silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;

	RAISE NOTICE 'Inserting Data Into: silver.erp_cust_az12';
	INSERT INTO silver.erp_cust_az12 (
		cid,
		bdate,
		gen
	)
	SELECT
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
			 ELSE cid
		END AS cid, -- Remove 'NAS' prefix if present
		CASE WHEN bdate > CURRENT_DATE THEN NULL
			 ELSE bdate
		END AS bdate, -- Set future birthdates to NULL
		CASE WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
			 WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			 ELSE 'n/a'
		END AS gen -- Normalize gender values and handle unknown cases
	FROM bronze.erp_cust_az12;
	end_time := clock_timestamp();
	RAISE NOTICE 'Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));

	-- silver.erp_loc_a101
	start_time := clock_timestamp();
	RAISE NOTICE 'Truncating Table: silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;

	RAISE NOTICE 'Inserting Data Into: silver.erp_loc_a101';
	INSERT INTO silver.erp_loc_a101 (
		cid,
		cntry
	)
	SELECT
		REPLACE(cid, '-', '') AS cid, -- Remove '-' to match crm_cust_info.cst_key format
		CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
			 WHEN TRIM(cntry) IN('USA','US') THEN 'United States'
			 WHEN TRIM(cntry) ='' OR cntry IS NULL THEN 'n/a'
			 ELSE TRIM(cntry)
		END AS cntry -- Normalize country codes and handle missing values
	FROM bronze.erp_loc_a101;
	end_time := clock_timestamp();
	RAISE NOTICE 'Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));

	-- silver.erp_px_cat_g1v2
	start_time := clock_timestamp();
	RAISE NOTICE 'Truncating Table: silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;

	RAISE NOTICE 'Inserting Data Into: silver.erp_px_cat_g1v2';
	INSERT INTO silver.erp_px_cat_g1v2 (
		id,
		cat,
		subcat,
		maintenance
	)
	SELECT
		id,
		cat,
		subcat,
		maintenance
	FROM bronze.erp_px_cat_g1v2;
	end_time := clock_timestamp();
	RAISE NOTICE 'Load Duration: % seconds', EXTRACT(EPOCH FROM (end_time - start_time));

	batch_end_time := clock_timestamp();
	RAISE NOTICE '=========================';
	RAISE NOTICE 'Loading Silver Layer is Completed';
	RAISE NOTICE 'Total Load Duration: % seconds', EXTRACT(EPOCH FROM (batch_end_time - batch_start_time));
	RAISE NOTICE '=========================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '========================================';
        RAISE NOTICE 'ERROR OCCURED DURING LOADING SILVER LAYER';
        RAISE NOTICE 'Error Message: %', SQLERRM;
        RAISE NOTICE 'Error Number (SQLSTATE): %', SQLSTATE;
        RAISE NOTICE '========================================';

END;
$$;
