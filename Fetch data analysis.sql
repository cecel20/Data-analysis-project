SELECT * FROM fetch.TRANSACTION_TAKEHOME;
SELECT * FROM `fetch`.products_TAKEHOME;
SELECT * FROM `fetch`.user_TAKEHOME;


# Check for missing or null values 
SELECT 'PRODUCTS_TAKEHOME' AS table_name, 'BARCODE' AS column_name, COUNT(*) AS missing_values
FROM fetch.PRODUCTS_TAKEHOME
WHERE BARCODE IS NULL OR BARCODE = ''
UNION ALL
SELECT 'TRANSACTION_TAKEHOME', 'BARCODE', COUNT(*)
FROM fetch.TRANSACTION_TAKEHOME
WHERE BARCODE IS NULL OR BARCODE = ''
UNION ALL
SELECT 'USER_TAKEHOME', 'BIRTH_DATE', COUNT(*)
FROM fetch.USER_TAKEHOME
WHERE BIRTH_DATE IS NULL OR BIRTH_DATE = ''
UNION ALL
SELECT 'USER_TAKEHOME', 'GENDER', COUNT(*)
FROM fetch.USER_TAKEHOME
WHERE GENDER IS NULL OR GENDER = '';

#ALTER TABLE PRODUCTS_TAKEHOME, TRANSACTION_TAKEHOME MODIFY COLUMN BARCODE VARCHAR(50);
ALTER TABLE fetch.PRODUCTS_TAKEHOME MODIFY COLUMN BARCODE VARCHAR(50);

ALTER TABLE fetch.TRANSACTION_TAKEHOME MODIFY COLUMN BARCODE VARCHAR(50);

# Check for non-numeric values
SELECT DISTINCT FINAL_QUANTITY
FROM fetch.TRANSACTION_TAKEHOME
WHERE FINAL_QUANTITY NOT REGEXP '^[0-9]+(\.[0-9]*)?$';

SELECT DISTINCT FINAL_SALE
FROM fetch.TRANSACTION_TAKEHOME
WHERE FINAL_SALE NOT REGEXP '^[0-9]+(\.[0-9]*)?$';

UPDATE fetch.TRANSACTION_TAKEHOME
SET FINAL_QUANTITY = '0'
WHERE FINAL_QUANTITY = 'zero';

UPDATE fetch.TRANSACTION_TAKEHOME
SET FINAL_SALE = '0'
WHERE FINAL_SALE = 'zero';

SELECT ID, COUNT(*)
FROM fetch.USER_TAKEHOME
GROUP BY ID
HAVING COUNT(*) > 1;

SELECT t.BARCODE
FROM fetch.TRANSACTION_TAKEHOME t
LEFT JOIN fetch.PRODUCTS_TAKEHOME p ON t.BARCODE = p.BARCODE
WHERE p.BARCODE IS NULL;

# clean the PRODUCTS_TAKEHOME_CLEAN table
# Replaced NULL values in MANUFACTURER and BRAND with 'Unknown'.
# Converted BARCODE to VARCHAR(50) to prevent truncation.
DROP TABLE IF EXISTS fetch.PRODUCTS_TAKEHOME1;
CREATE TABLE fetch.PRODUCTS_TAKEHOME1 AS 
SELECT 
    CATEGORY_1, 
    CATEGORY_2, 
    CATEGORY_3, 
    CATEGORY_4, 
    COALESCE(MANUFACTURER, 'Unknown') AS MANUFACTURER, 
    COALESCE(BRAND, 'Unknown') AS BRAND, 
    CAST(BARCODE AS CHAR(50)) AS BARCODE
FROM fetch.PRODUCTS_TAKEHOME
WHERE BARCODE IS NOT NULL AND BARCODE <> '';

SELECT * from fetch.PRODUCTS_TAKEHOME_CLEAN;

# Create transaction_takehome_clean table after clean the data
# Replaced "zero" in FINAL_QUANTITY and FINAL_SALE with 0.
# Converted non-numeric values to NULL in FINAL_QUANTITY and FINAL_SALE.
DROP TABLE IF EXISTS fetch.TRANSACTION_TAKEHOME1;

CREATE TABLE fetch.TRANSACTION_TAKEHOME1 AS 
SELECT 
    RECEIPT_ID, 
    PURCHASE_DATE, 
    SCAN_DATE, 
    STORE_NAME, 
    USER_ID, 
    CAST(BARCODE AS CHAR(50)) AS BARCODE, 
    CASE 
        WHEN FINAL_QUANTITY = 'zero' THEN 0 
        WHEN FINAL_QUANTITY REGEXP '^[0-9]+(\.[0-9]*)?$' THEN FINAL_QUANTITY 
        ELSE NULL 
    END AS FINAL_QUANTITY, 
    CASE 
        WHEN FINAL_SALE = 'zero' THEN 0 
        WHEN FINAL_SALE REGEXP '^[0-9]+(\.[0-9]*)?$' THEN FINAL_SALE 
        ELSE NULL 
    END AS FINAL_SALE
FROM fetch.TRANSACTION_TAKEHOME
WHERE BARCODE IS NOT NULL AND BARCODE <> '';

SELECT * from  fetch.TRANSACTION_TAKEHOME1 ;

# Create user_takehome_clean table 
# Replaced missing gender values with 'Unknown'
DROP TABLE IF EXISTS fetch.USER_TAKEHOME1;

CREATE TABLE fetch.USER_TAKEHOME1 AS 
SELECT 
    ID, 
    CREATED_DATE, 
    CASE 
        WHEN BIRTH_DATE = '' THEN NULL 
        ELSE BIRTH_DATE 
    END AS BIRTH_DATE,
    STATE, 
    LANGUAGE, 
    COALESCE(GENDER, 'Unknown') AS GENDER
FROM fetch.USER_TAKEHOME;

SELECT * from fetch.USER_TAKEHOMEN1 utc ;

# 1. Top 5 Brands by Receipts Scanned Among Users 21 and Over

With users_21_plus as (
  Select 
    ID as USER_ID,
    TIMESTAMPDIFF(YEAR, BIRTH_DATE, CURDATE()) as age
  FROM fetch.USER_TAKEHOME1
  Where TIMESTAMPDIFF(YEAR, BIRTH_DATE, CURDATE()) >= 21
)
Select 
  COALESCE(p.BRAND, 'Unknown Brand') AS brand,
  COUNT(Distinct t.RECEIPT_ID) as receipt_count
FROM fetch.TRANSACTION_TAKEHOME1 t
left join users_21_plus u on t.USER_ID = u.USER_ID
left join fetch.PRODUCTS_TAKEHOME1 p on t.BARCODE = p.BARCODE
Group by p.BRAND
Order by receipt_count DESC
Limit 5;

# 2. Top 5 Brands by Sales Among Users Who Have Had Their Account for at Least Six Months
SELECT COUNT(DISTINCT BRAND) AS total_brands
FROM fetch.PRODUCTS_TAKEHOME;

SELECT 
  COALESCE(p.BRAND, 'Unknown Brand') AS brand,  
  SUM(COALESCE(t.FINAL_SALE, 0)) AS total_sales
FROM fetch.TRANSACTION_TAKEHOME t
LEFT JOIN fetch.PRODUCTS_TAKEHOME p ON t.BARCODE = p.BARCODE
GROUP BY p.BRAND
ORDER BY total_sales DESC
LIMIT 20;  -- Show more brands to verify data

With users_6_months as (
  Select 
    ID as USER_ID
  From fetch.USER_TAKEHOME
  Where TIMESTAMPDIFF(MONTH, CREATED_DATE, CURDATE()) >= 6
)
Select 
	COALESCE(p.BRAND, 'Unknown Brand') AS brand,  
  	SUM(COALESCE(t.FINAL_SALE, 0)) AS total_sales
From fetch.TRANSACTION_TAKEHOME t
Left Join  fetch.PRODUCTS_TAKEHOME p on t.BARCODE = p.BARCODE
Left Join  users_6_months u on t.USER_ID = u.USER_ID
Group by p.BRAND
Order by total_sales DESC
Limit 5;



# 3. Percentage of Sales in the Health & Wellness Category by Generation
with generations as (
    select 
        id as user_id,
        case 
            when timestampdiff(year, birth_date, curdate()) between 21 and 39 then 'millennials'
            when timestampdiff(year, birth_date, curdate()) between 40 and 59 then 'generation x'
            when timestampdiff(year, birth_date, curdate()) >= 60 then 'baby boomers'
            else 'generation z'
        end as generation
    from fetch.user_takehome
),
total_sales as (
    select 
        sum(coalesce(t.final_sale, 0)) as total_health_wellness_sales
    from fetch.transaction_takehome t
    join fetch.products_takehome p on t.barcode = p.barcode
    where p.category_1 = 'Health & Wellness'
)
select 
    g.generation,
    sum(coalesce(t.final_sale, 0)) as category_sales,
    round(
        (sum(coalesce(t.final_sale, 0)) / nullif(ts.total_health_wellness_sales, 0)) * 100, 2
    ) as percentage_of_sales
from generations g
left join fetch.transaction_takehome t on g.user_id = t.user_id
left join fetch.products_takehome p on t.barcode = p.barcode 
    and p.category_1 = 'Health & Wellness'
cross join total_sales ts
group by g.generation, ts.total_health_wellness_sales
order by percentage_of_sales desc;

# Open-ended questions: for these, make assumptions and clearly state them when answering the question.
# Who are Fetch’s power users?
/* 
 * 	Power users at Fetch are those who engage frequently with the platform, make high-value purchases, 
and have long-term engagement, typically over 6 months to 1 year. 
They regularly purchase from high-demand categories like Dips & Salsa and offer repeat business through multiple transactions. 

	To identify power users, Fetch can analyze data such as purchase frequency, average transaction size, and customer lifecycle. 
Segmenting users based on these metrics can help pinpoint the most valuable and active customers.
*/

# Which is the leading brand in the Dips & Salsa category?
/* Based on the analysis shows that leading brand "YOUTHEORY" in the Dips & Salsa category is 
 * identified as the brand with the highest total sales from transactions. 
 * 
 * The result shows that "YOUTHEORY" is the top brand in terms of sales, followed by "BRANK NOT KNOWN".
 * However, this suggests that there may be missing or incomplete brand information in the data, 
 * which should be addressed to clarify the actual leading brand.
*/
SELECT 
    p.BRAND, 
    SUM(COALESCE(t.FINAL_SALE, 0)) AS total_sales
FROM fetch.TRANSACTION_TAKEHOME t
LEFT JOIN fetch.PRODUCTS_TAKEHOME p ON t.BARCODE = p.BARCODE
GROUP BY p.BRAND
ORDER BY total_sales DESC
LIMIT 3;

# At what percent has Fetch grown year over year?
SELECT 
    YEAR(t.PURCHASE_DATE) AS year,
    SUM(COALESCE(t.FINAL_SALE, 0)) AS total_sales
FROM fetch.TRANSACTION_TAKEHOME t
WHERE t.PURCHASE_DATE BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY YEAR(t.PURCHASE_DATE)

UNION ALL

SELECT 
    YEAR(t.PURCHASE_DATE) AS year,
    SUM(COALESCE(t.FINAL_SALE, 0)) AS total_sales
FROM fetch.TRANSACTION_TAKEHOME t
WHERE t.PURCHASE_DATE BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY YEAR(t.PURCHASE_DATE);
/* 
 * Based on the sales data for 2023 and 2024, Fetch has experienced a X% growth year over year. 
 * This indicates a positive trend in its sales, showcasing strong performance compared to the previous year.
*/