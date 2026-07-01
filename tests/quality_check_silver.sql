/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- Check Duplicate
-- Expectation : No Result
SELECT 
prd_id,
COUNT(*)
FROM Silver_Bara_Project.crm_prd_info
GROUP BY prd_id
Having COUNT(*)>1 OR prd_id IS Null;

-- Check unwanted space
-- Expectation : No Result
SELECT *
FROM Silver_Bara_Project.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check for Null or any Negative value
-- Expectation : No Result
SELECT *
FROM Silver_Bara_Project.crm_prd_info
WHERE prd_cost < 0 or prd_cost IS NULL;

-- Data Standardization and Consistency
-- Expectation : No Result
SELECT DISTINCT prd_line
FROM Silver_Bara_Project.crm_prd_info;

-- Check invalid date orders
-- Check for Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results
SELECT * 
FROM Silver_Bara_Project.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

SELECT 
NULLIF(sls_due_dt,0) sls_due_dt
FROM Bronze_Bara_Project.crm_sales_details
WHERE sls_due_dt <= 0 
OR LENGTH(sls_due_dt)!=8
OR sls_due_dt > 20500101
OR sls_due_dt < 19000101;

-- Check for Invalid Date Orders (Order Date > Shipping/Due Dates)
-- Expectation: No Results
SELECT * FROM
Silver_Bara_Project.crm_sales_details
WHERE sls_order_dt > sls_ship_dt or sls_order_dt > sls_due_dt;

-- Check Data consistancy between sales , quantity and price
-- >> Sales = quantity * price
-- >> values must not be null, zero or negative
SELECT DISTINCT
sls_sales, 
sls_quantity,
sls_price
FROM Silver_Bara_Project.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity,sls_price;

-- ====================================================================
-- Checking 'silver.erp_cust_az12'
-- ====================================================================
-- Identify Out-of-Range Dates
-- Expectation: Birthdates between 1924-01-01 and Today

SELECT bdate
FROM Silver_Bara_Project.erp_cust_az12
WHERE bdate > NOW();

SELECT DISTINCT gen,
CASE
	WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
    WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
    ELSE 'n/a'
END AS new_gen
FROM Silver_Bara_Project.erp_cust_az12;

SELECT DISTINCT cntry,
CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
	 WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
     WHEN TRIM(cntry) IS NULL or TRIM(cntry) = '' THEN 'n/a'
     ELSE TRIM(cntry)
END as new_cntry
FROM Bronze_Bara_Project.erp_loc_a101
ORDER BY cntry;

SELECT * FROM Bronze_Bara_Project.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

SELECT DISTINCT maintenance FROM Bronze_Bara_Project.erp_px_cat_g1v2;






















