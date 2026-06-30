/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL load_Silver();
===============================================================================
*/

DELIMITER //

DROP PROCEDURE IF EXISTS load_Silver //

CREATE PROCEDURE load_Silver()
BEGIN
DECLARE starttime DATETIME;
DECLARE endtime DATETIME;
DECLARE batch_start_time DATETIME;
DECLARE batch_end_time DATETIME;
-- Exception Handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        

        SELECT 'Error occurred while loading Silver Layer' AS Message;
    END;

    START TRANSACTION;

    SET batch_start_time = NOW();
       
	-- Data Cleaning and Loading
	-- Check and Remove Duplicates from table
	-- ========================================================
	-- 1st Table crm_cust_info
	-- ========================================================
	SET starttime = Now();
    SELECT 'Truncating the Silver_Bara_Project.crm_cust_info table' AS Message;
    TRUNCATE TABLE Silver_Bara_Project.crm_cust_info;
	SELECT 'Loading Silver_Bara_Project.crm_cust_info table' AS Message;
	INSERT INTO Silver_Bara_Project.crm_cust_info(
	cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_marital_status,
	cst_gender,
	cst_create_date
	) -- Data loading into silver layer

	SELECT 
	cst_id,
	cst_key,
	TRIM(cst_firstname) as cst_firstname,
	TRIM(cst_lastname) as cst_lastname, -- Removing unwanted spaces from string columns
	CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		 WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		 ELSE 'N/A'
	END as cst_marital_status, -- Normalize the marrital status column from coded value to more descriptive and user friendly value. 
	CASE WHEN UPPER(TRIM(cst_gender)) = 'F' THEN 'Female'
		 WHEN UPPER(TRIM(cst_gender)) = 'M' THEN 'Male'
		 ELSE 'N/A'
	END as cst_gender, -- Normalize the marrital status column from coded value to more descriptive and user friendly value.
	cst_create_date
	FROM(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date) as flag_last
	FROM Bronze_Bara_Project.crm_cust_info)t
	WHERE flag_last =1; -- Remove duplicates with the help of row number as we only select recent records per customer
	SET endtime = NOW();
	-- ========================================================
	-- 2nd Table crm_prd_info
	-- ========================================================
    SET starttime = NOW();
    SELECT 'Truncating the Silver_Bara_Project.crm_prd_info table' AS Message;
	TRUNCATE TABLE Silver_Bara_Project.crm_prd_info;
	SELECT 'Loading Silver_Bara_Project.crm_prd_info table' AS Message;
	INSERT INTO Silver_Bara_Project.crm_prd_info(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
	) -- Data loading into silver layer

	SELECT 
	prd_id,
	REPLACE(SUBSTRING(prd_key, 1, 5),'-','_') as cat_id, -- Extract the category ID from product key for joining two tables.
	SUBSTRING(prd_key,7,LENGTH(prd_key)) as prd_key,  -- Extract the prd_key from product key for joining two tables.
	prd_nm,
	prd_cost,
	CASE 
		WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
		WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
		WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
		WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
		ELSE 'N/A'
	END as prd_line, -- Map prd_line value in more user friendly format
	CAST(prd_start_dt AS DATE) as prd_start_dt,
	CAST(
	DATE_SUB(
		LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt), INTERVAL 1 DAY
			) AS DATE
	) as prd_end_dt 
	-- Calculate end date as one day before the start date of next window
	FROM Bronze_Bara_Project.crm_prd_info;
	SET endtime = NOW();
	-- ========================================================
	-- 3rd Table crm_sales_details
	-- ========================================================
    SET starttime = NOW();
    SELECT 'Truncating the Silver_Bara_Project.crm_sales_details' AS Message;
	TRUNCATE TABLE Silver_Bara_Project.crm_sales_details;
	SELECT 'Loading Silver_Bara_Project.crm_sales_details table' AS Message;
	INSERT INTO Silver_Bara_Project.crm_sales_details(
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
	CASE
		WHEN sls_order_dt = 0 or LENGTH(sls_order_dt)!=8 THEN NULL
		ELSE STR_TO_DATE(CAST(sls_order_dt AS CHAR),'%Y%m%d')
	END as sls_order_dt,
	CASE
		WHEN sls_ship_dt = 0 or LENGTH(sls_ship_dt)!=8 THEN NULL
		ELSE STR_TO_DATE(CAST(sls_ship_dt AS CHAR),'%Y%m%d')
	END as sls_ship_dt,
	CASE
		WHEN sls_due_dt = 0 or LENGTH(sls_due_dt)!=8 THEN NULL
		ELSE STR_TO_DATE(CAST(sls_due_dt AS CHAR),'%Y%m%d')
	END as sls_due_dt,
	CASE WHEN sls_sales != sls_quantity * ABS(sls_price) OR sls_sales IS NULL OR sls_sales <= 0 THEN sls_quantity * ABS(sls_price)
		 ELSE sls_sales
	END as sls_sales, -- Recalculating the sales value if there is any o , negative or missing value.
	sls_quantity,
	CASE WHEN sls_price IS NULL OR sls_price <= 0 THEN CAST(sls_sales/ NULLIF(sls_quantity,0) AS SIGNED)
		 ELSE sls_price
	END as sls_price -- Derive price if original price is invalid
	FROM Bronze_Bara_Project.crm_sales_details;
	SET endtime = NOW();
	-- ========================================================
	-- 4th Table erp_cust_az12
	-- ========================================================
    SET starttime = NOW();
    SELECT 'Truncating the Silver_Bara_Project.erp_cust_az12' AS Message;
	TRUNCATE TABLE Silver_Bara_Project.erp_cust_az12;
	SELECT 'Loading Silver_Bara_Project.erp_cust_az12 table' AS Message;
	INSERT INTO Silver_Bara_Project.erp_cust_az12(cid,bdate,gen)
	SELECT 
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LENGTH(cid))
		 ELSE cid
	END AS cid, -- Remove NAS prefix from cid
	CASE WHEN bdate > NOW() THEN Null
		 ELSE bdate
	END AS bdate, -- Set future dates to null
	CASE
		WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		ELSE 'n/a'
	END AS gen -- Normalize gender values and unknown cases
	FROM Bronze_Bara_Project.erp_cust_az12;
	SET endtime = NOW();
	-- ========================================================
	-- 5th Table erp_loc_a101
	-- ========================================================
	SET starttime = NOW();
    SELECT 'Truncating the Silver_Bara_Project.erp_loc_a101' AS Message;
    TRUNCATE TABLE Silver_Bara_Project.erp_loc_a101;
	SELECT 'Loading Silver_Bara_Project.erp_loc_a101 table' AS Message;
	INSERT INTO Silver_Bara_Project.erp_loc_a101
	(cid,cntry)
	SELECT 
	REPLACE(cid,'-','') cid,
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		 WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
		 WHEN TRIM(cntry) IS NULL or TRIM(cntry) = '' THEN 'n/a'
		 ELSE TRIM(cntry)
	END as cntry -- Normalize and handle missing and blank country value
	FROM Bronze_Bara_Project.erp_loc_a101;
	SET endtime = NOW();
	-- ========================================================
	-- 6th Table erp_loc_a101
	-- ========================================================
	SET starttime = NOW();
    SELECT 'Truncating the Silver_Bara_Project.erp_px_cat_g1v2' AS Message;
    TRUNCATE TABLE Silver_Bara_Project.erp_px_cat_g1v2;
	SELECT 'Loading Silver_Bara_Project.erp_px_cat_g1v2 table' AS Message;
	INSERT INTO Silver_Bara_Project.erp_px_cat_g1v2(
	ID,
	cat,
	subcat,
	maintenance
	)
	SELECT 
	ID,
	cat,
	subcat,
	maintenance
	FROM Bronze_Bara_Project.erp_px_cat_g1v2;
	SET endtime = NOW();
    
    SET batch_end_time = NOW();
    SELECT CONCAT('Total Batch Duration :', TIMESTAMPDIFF(SECOND, batch_start_time, batch_end_time),' Seconds') AS Message;
END //

DELIMITER ;

CALL load_Silver();









