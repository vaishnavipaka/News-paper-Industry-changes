select * from dim_city;
select * from dim_ad_category;
select * from fact_ad_revenue;
select * from fact_city_readiness;
select * from fact_digital_pilot;
select * from fact_print_sales;

  
describe dim_city;
describe dim_ad_category;
describe fact_ad_revenue;
describe fact_city_readiness;
describe fact_digital_pilot;
describe fact_print_sales;

#dim city
ALTER TABLE dim_city
CHANGE ï»¿city_id city_id text;

alter table dim_city
modify City_ID varchar(50);

ALTER TABLE dim_city
ADD PRIMARY KEY (City_Id);


#dim ad category
 
ALTER TABLE dim_ad_category
CHANGE ï»¿ad_category_id ad_categoryid text;

alter table dim_ad_category
modify ad_categoryid varchar(50);

ALTER TABLE dim_ad_category
ADD PRIMARY KEY (ad_categoryid);

# fact ad revenue

ALTER TABLE fact_ad_revenue
ADD COLUMN revenue_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

alter table fact_ad_revenue
modify ad_category varchar(50);

ALTER TABLE fact_ad_revenue
ADD CONSTRAINT fk_revenue_category
FOREIGN KEY (ad_category)
REFERENCES dim_ad_category(ad_categoryid)
ON UPDATE CASCADE
ON DELETE CASCADE;

#fact city readiness

ALTER TABLE fact_city_readiness
ADD COLUMN readiness_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

show create table fact_city_readiness;

ALTER TABLE fact_city_readiness
DROP FOREIGN KEY fk_readiness_city;

ALTER TABLE fact_city_readiness
ADD CONSTRAINT fk_readiness_city
FOREIGN KEY (City_Id)
REFERENCES dim_city(City_Id)
ON UPDATE CASCADE
ON DELETE CASCADE;

#fact digital pilot

SHOW CREATE TABLE fact_digital_pilot;

ALTER TABLE fact_digital_pilot
DROP FOREIGN KEY fk_digital_city;

ALTER TABLE fact_digital_pilot
DROP FOREIGN KEY fk_digital_category;

 ALTER TABLE fact_digital_pilot
ADD CONSTRAINT fk_digital_category FOREIGN KEY (ad_category_id)
REFERENCES dim_ad_category(ad_categoryid)
ON UPDATE CASCADE
ON DELETE CASCADE;

 ALTER TABLE fact_digital_pilot
ADD CONSTRAINT fk_digital_city FOREIGN KEY (City_Id)
REFERENCES dim_city(City_Id)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE fact_digital_pilot
ADD COLUMN pilot_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

 
#fact print sales
ALTER TABLE fact_print_sales
ADD COLUMN print_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

ALTER TABLE fact_print_sales
CHANGE Month print_month text;

ALTER TABLE fact_print_sales
CHANGE ï»¿edition_ID edition_id text;

ALTER TABLE fact_print_sales
CHANGE `Copies Sold` copies_sold int;

ALTER TABLE fact_print_sales
ADD CONSTRAINT fk_print_city
FOREIGN KEY (City_Id)
REFERENCES dim_city(City_Id)
ON UPDATE CASCADE
ON DELETE CASCADE;

  
  SELECT print_month
FROM fact_print_sales
WHERE print_month IS NULL;

ALTER TABLE fact_print_sales
MODIFY COLUMN Month_numeric DATE;




 UPDATE fact_print_sales
SET Month_numeric =
CASE UPPER(LEFT(TRIM(print_month),3))
  WHEN 'JAN' THEN STR_TO_DATE(CONCAT('01-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'FEB' THEN STR_TO_DATE(CONCAT('02-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'MAR' THEN STR_TO_DATE(CONCAT('03-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'APR' THEN STR_TO_DATE(CONCAT('04-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'MAY' THEN STR_TO_DATE(CONCAT('05-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'JUN' THEN STR_TO_DATE(CONCAT('06-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'JUL' THEN STR_TO_DATE(CONCAT('07-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'AUG' THEN STR_TO_DATE(CONCAT('08-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'SEP' THEN STR_TO_DATE(CONCAT('09-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'OCT' THEN STR_TO_DATE(CONCAT('10-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'NOV' THEN STR_TO_DATE(CONCAT('11-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
  WHEN 'DEC' THEN STR_TO_DATE(CONCAT('12-', RIGHT(TRIM(print_month),2), '-01'), '%m-%y-%d')
END;

SELECT DATE_FORMAT(Month_numeric, '%Y-%m') AS YearMonth
FROM fact_print_sales;

 
#primary & secondary analaysis 

# 1.  Print Circulation Trends 

#  What is the trend in copies printed, copies sold, and net circulation across all 
#  cities from 2019 to 2024? How has this changed year-over-year? 

SELECT 
    dc.city,
    YEAR(fp.Month_numeric) AS Year,
    SUM(fp.copies_sold) AS Total_Printed,
    SUM(fp.Copies_Sold) AS Total_Sold,
    SUM(fp.Net_Circulation) AS Total_Circulation
FROM fact_print_sales fp
JOIN dim_city dc ON dc.City_ID = fp.City_ID
where year(month_numeric) is not null
GROUP BY dc.city, YEAR(fp.Month_numeric)
ORDER BY dc.city,Year;

/* Formula for YoY change (%) */ 

/* YoY% = Current Year Value − Previous Year Value / Previous Year Value × 100 
ex- (2019) 3,68,79,749 - (2018) 10,68,164 / 10,68,164 x 100 */


/* This query calculates the total copies printed, sold, and net circulation 
for each city per year. 
It also computes the year-over-year (YoY) percentage change for each metric 
to help analyze trends across cities from 2019 to 2024.
*/

SELECT 
    dc.city,  -- City name
    YEAR(fp.Month_numeric) AS Year,  -- Extract year from Month_numeric
    SUM(fp.Copies_sold) AS Total_Printed,  -- Total copies printed per city per year
    SUM(fp.Copies_Sold) AS Total_Sold,       -- Total copies sold per city per year
    SUM(fp.Net_Circulation) AS Total_Circulation,  -- Total net circulation per city per year
    ROUND((SUM(fp.Copies_sold) - LAG(SUM(fp.Copies_sold)) OVER (PARTITION BY dc.city ORDER BY YEAR(fp.Month_numeric))) / 
          LAG(SUM(fp.Copies_sold)) OVER (PARTITION BY dc.city ORDER BY YEAR(fp.Month_numeric)) * 100, 2) AS Printed_YoY,
    ROUND((SUM(fp.Copies_Sold) - LAG(SUM(fp.Copies_Sold)) OVER (PARTITION BY dc.city ORDER BY YEAR(fp.Month_numeric))) / 
          LAG(SUM(fp.Copies_Sold)) OVER (PARTITION BY dc.city ORDER BY YEAR(fp.Month_numeric)) * 100, 2) AS Sold_YoY,
    ROUND((SUM(fp.Net_Circulation) - LAG(SUM(fp.Net_Circulation)) OVER (PARTITION BY dc.city ORDER BY YEAR(fp.Month_numeric))) / 
          LAG(SUM(fp.Net_Circulation)) OVER (PARTITION BY dc.city ORDER BY YEAR(fp.Month_numeric)) * 100, 2) AS Circulation_YoY
FROM fact_print_sales fp
JOIN dim_city dc 
    ON dc.City_ID = fp.City_ID
GROUP BY dc.city, YEAR(fp.Month_numeric)
ORDER BY dc.city, Year;


 SELECT
  dc.city,
  SUM(COALESCE(fp.copies_sold,0))    AS total_sold_copies_2019,
  SUM(COALESCE(fp.net_circulation,0)) AS total_net_circulated_2019,
  ( (SUM(COALESCE(fp.net_circulation,0)) - SUM(COALESCE(fp.copies_sold,0))) 
    / NULLIF(SUM(COALESCE(fp.net_circulation,0)),0) * 100 ) AS diff_percent
FROM fact_print_sales fp
JOIN dim_city dc ON dc.City_ID = fp.City_ID
WHERE YEAR(month_numeric) = 2019
GROUP BY dc.city
ORDER BY dc.city;



/*2. To Performing Cities 
Which cities contributed the highest to net circulation and copies sold in 2024? 
Are these cities still profitable to operate in?*/
SELECT 
    dc.city,
    YEAR(fp.Month_numeric) AS Year,
    SUM(fp.copies_sold) AS Total_Printed,
    SUM(fp.Copies_Sold) AS Total_Sold,
    SUM(fp.Net_Circulation) AS Total_Circulation
FROM fact_print_sales fp
JOIN dim_city dc ON dc.City_ID = fp.City_ID
where year(month_numeric) = 2024
GROUP BY dc.city,year
ORDER BY dc.city,year asc;

 
/* 3. Print Waste Analysis 
Which cities have the largest gap between copies printed and net circulation, and 
how has that gap changed over time? */

-- Q3: Largest gap between printed and net circulation per city per year
SELECT
  dc.city,
  YEAR(fp.month_numeric) AS year,
  SUM(fp.copies_sold - fp.net_circulation) AS print_waste
FROM fact_print_sales fp
JOIN dim_city dc ON dc.city_id = fp.city_id
GROUP BY dc.city, YEAR(fp.month_numeric)
ORDER BY print_waste desc;

/* 4. Ad Revenue Trends by Category 
How has ad revenue evolved across different ad categories between 2019 and 
2024? Which categories have remained strong, and which have declined? */

select sum(fr.ad_revenue),dac.ad_categoryid,dac.standard_ad_category,year(month_numeric) from fact_ad_revenue fr
join dim_ad_category dac  on dac.ad_categoryid=fr.ad_category
join fact_print_sales fp on fp.edition_id=fr.edition_id
group by dac.ad_categoryid, year(month_numeric)
order by sum(fr.ad_revenue) desc;


/* 5. City-Level Ad Revenue Performance 
Which cities generated the most ad revenue, and how does that correlate with 
their print circulation? */

select sum(fr.ad_revenue),fp.edition_id,fp.City_ID,dc.city,dac.standard_ad_category,sum(fp.Net_Circulation) from fact_ad_revenue fr
join fact_print_sales fp on fp.edition_id=fr.edition_id
join dim_city dc on dc.City_ID=fp.City_ID
join dim_ad_category dac on dac.ad_categoryid=fr.ad_category
group by fp.City_ID,fp.edition_id,dac.standard_ad_category
order by sum(fr.ad_revenue) desc;

6. Digital Readiness vs. Performance 
Which cities show high digital readiness (based on smartphone, internet, and 
literacy rates) but had low digital pilot engagement? 


7. Ad Revenue vs. Circulation ROI 
Which cities had the highest ad revenue per net circulated copy? Is this ratio 
improving or worsening over time? 
8. Digital Relaunch City Prioritization 
Based on digital readiness, pilot engagement, and print decline, which 3 cities should be 
prioritized for Phase 1 of the digital relaunch? ---------------------------------------------------------------------------------------------------- 
codebasics.i





