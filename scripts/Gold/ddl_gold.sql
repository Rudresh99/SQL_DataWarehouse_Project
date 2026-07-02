/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/
-- ======================================================
-- For dim_customers view
-- ======================================================
CREATE VIEW Gold_Bara_Project.dim_customer AS  
SELECT 
	ROW_NUMBER() OVER(ORDER BY ci.cst_id) as customer_key, -- Surrogate Key - System generated unique identifier assigned to each record in a table
	ci.cst_id as customer_id,
	ci.cst_key as customer_number,
	ci.cst_firstname as first_name,
	ci.cst_lastname as last_name,
    la.cntry as country,
	ci.cst_marital_status as marital_status,
	CASE WHEN ci.cst_gender != 'n/a' THEN ci.cst_gender -- CRM is the Master for gender info
		 ELSE coalesce(ca.gen,'n/a')
	END as gender,
    ca.bdate as birth_date,
	ci.cst_create_date as create_date
FROM Silver_Bara_Project.crm_cust_info as ci
LEFT JOIN Silver_Bara_Project.erp_cust_az12 as ca
ON        ci.cst_key = ca.cid
LEFT JOIN Silver_Bara_Project.erp_loc_a101 as la
ON        ci.cst_key = la.cid;

-- ======================================================
-- For dim_products view
-- ======================================================
CREATE VIEW Gold_Bara_Project.dim_products AS
SELECT
	ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) as product_key, -- Surrogate Key - System generated unique identifier assigned to each record in a table
	pn.prd_id as product_id,
    pn.prd_key as product_number,
    pn.prd_nm as product_name,
    pn.cat_id as category_id,
    pc.cat category,
    pc.subcat sub_category,
    pc.maintenance,
    pn.prd_cost as cost,
    pn.prd_line product_line,
    pn.prd_start_dt as start_date
FROM Silver_Bara_Project.crm_prd_info as pn
LEFT JOIN Silver_Bara_Project.erp_px_cat_g1v2 pc
ON		pn.cat_id = pc.ID
WHERE pn.prd_end_dt IS NULL; -- Filter out all historical data

-- ======================================================
-- For fact_sales view
-- ======================================================
CREATE VIEW Gold_Bara_Project.fact_sales AS
SELECT  
	sd.sls_ord_num as order_number,
	pd.product_key,
	cd.customer_key,
	sd.sls_order_dt as order_date,
	sd.sls_ship_dt as shipping_date,
	sd.sls_due_dt as due_date,
	sd.sls_sales as sales_amount,
	sd.sls_quantity as quantity,
	sd.sls_price as price
FROM Silver_Bara_Project.crm_sales_details as sd
LEFT JOIN Gold_Bara_Project.dim_products pd
ON 		 sd.sls_prd_key = pd.product_number
LEFT JOIN Gold_Bara_Project.dim_customer cd
ON 		 sd.sls_cust_id = cd.customer_id;





















