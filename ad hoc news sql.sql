#business ad hoc 1 - monthly circulation drop check
SELECT city, month, net_circulation, prev_circulation, (prev_circulation - net_circulation) AS drop_val
FROM (
  SELECT
    dc.city,
    DATE_FORMAT(fps.Month_numeric, '%Y-%m') AS month,
    SUM(fps.Net_Circulation) AS net_circulation,
    LAG(SUM(fps.Net_Circulation)) OVER (PARTITION BY dc.city ORDER BY fps.Month_numeric) AS prev_circulation
  FROM fact_print_sales fps
  JOIN dim_city dc ON fps.City_ID = dc.City_ID
  WHERE fps.Month_numeric BETWEEN '2019-01-01' AND '2024-12-31'
  GROUP BY dc.city, fps.Month_numeric
) t
WHERE prev_circulation IS NOT NULL
ORDER BY (prev_circulation - net_circulation) DESC
LIMIT 3;


## 2. Yearly revenue concentration by category 
SELECT
    year,
    category_name,
    category_revenue,
    total_revenue_year,
    ROUND((category_revenue / total_revenue_year) * 100, 2) AS pct_of_year_total
FROM (
    SELECT
        SUBSTRING(quarter, 1, 4) AS year,
        dac.standard_ad_category AS category_name,
        SUM(far.ad_revenue) AS category_revenue,
        SUM(SUM(far.ad_revenue)) OVER (PARTITION BY SUBSTRING(quarter, 1, 4)) AS total_revenue_year
    FROM fact_ad_revenue far
    JOIN dim_ad_category dac ON dac.ad_categoryid = far.ad_category
    GROUP BY year, dac.standard_ad_category
) t
WHERE (category_revenue / total_revenue_year) > 0.40
ORDER BY year, pct_of_year_total DESC;


# Ad hoc -3 Print efficiency leader board
SELECT 
    dc.city AS city_name,
    SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.copies_sold ELSE 0 END) AS copies_printed_2024,
    SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.Net_Circulation ELSE 0 END) AS net_circulation_2024,
    CASE 
      WHEN SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.copies_sold ELSE 0 END) = 0 THEN 0
      ELSE ROUND(
        SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.Net_Circulation ELSE 0 END) /
        SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.copies_sold ELSE 0 END),
      4)
    END AS efficiency_ratio,
    RANK() OVER (ORDER BY 
      SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.Net_Circulation ELSE 0 END) /
      NULLIF(SUM(CASE WHEN YEAR(fps.Month_numeric) = 2024 THEN fps.copies_sold ELSE 0 END), 0) DESC) AS efficiency_rank_2024
FROM fact_print_sales fps
JOIN dim_city dc ON fps.City_ID = dc.City_ID
WHERE YEAR(fps.Month_numeric) = 2024
GROUP BY dc.city
ORDER BY efficiency_rank_2024
LIMIT 5;

# 4. Internet readiness growth 2021
  WITH internet_rates AS (
    SELECT 
        dc.city AS city_name,
        fcr.quarter,
        AVG(fcr.internet_penetration) AS internet_rate
    FROM fact_city_readiness fcr
    JOIN dim_city dc ON fcr.city_id = dc.City_ID
    WHERE fcr.quarter IN ('2021-Q1', '2021-Q2', '2021-Q3', '2021-Q4')
    GROUP BY dc.city, fcr.quarter
)
SELECT 
    city_name,
    MAX(CASE WHEN quarter = '2021-Q1' THEN internet_rate END) AS internet_rate_q1_2021,
    MAX(CASE WHEN quarter = '2021-Q2' THEN internet_rate END) AS internet_rate_q2_2021,
    MAX(CASE WHEN quarter = '2021-Q3' THEN internet_rate END) AS internet_rate_q3_2021,
    MAX(CASE WHEN quarter = '2021-Q4' THEN internet_rate END) AS internet_rate_q4_2021,
    MAX(CASE WHEN quarter = '2021-Q4' THEN internet_rate END) - MAX(CASE WHEN quarter = '2021-Q1' THEN internet_rate END) AS delta_internet_rate
FROM internet_rates
GROUP BY city_name
ORDER BY delta_internet_rate desc
LIMIT 3;

SELECT DISTINCT quarter 
FROM fact_city_readiness 
WHERE quarter LIKE '2021%'
ORDER BY quarter;

#5. Consistent Multi year decline
      WITH yearly_print AS (
    SELECT
        dc.city AS city_name,
        YEAR(fps.Month_numeric) AS year,
        SUM(fps.Net_Circulation) AS net_circulation
    FROM fact_print_sales fps
    JOIN dim_city dc ON fps.City_ID = dc.City_ID
    WHERE fps.Month_numeric BETWEEN '2019-01-01' AND '2024-12-31'
    GROUP BY dc.city, year
),
yearly_ad_revenue AS (
    SELECT
        dc.city AS city_name,
        SUBSTRING(far.quarter, 1, 4) AS year,
        SUM(far.ad_revenue) AS ad_revenue
    FROM fact_ad_revenue far
    JOIN fact_print_sales fps ON far.edition_id = fps.edition_id
    JOIN dim_city dc ON fps.city_id = dc.city_id
    WHERE SUBSTRING(far.quarter, 1, 4) BETWEEN '2019' AND '2024'
    GROUP BY dc.city, year
),
combined AS (
    SELECT
        yp.city_name,
        yp.year,
        yp.net_circulation,
        COALESCE(ya.ad_revenue, 0) AS ad_revenue
    FROM yearly_print yp
    LEFT JOIN yearly_ad_revenue ya ON yp.city_name = ya.city_name AND yp.year = ya.year
),
lagged AS (
    SELECT
        city_name,
        year,
        net_circulation,
        ad_revenue,
        LAG(net_circulation) OVER (PARTITION BY city_name ORDER BY year) AS prev_net_circulation,
        LAG(ad_revenue) OVER (PARTITION BY city_name ORDER BY year) AS prev_ad_revenue
    FROM combined
)
SELECT
    city_name,
    year,
    net_circulation,
    ad_revenue,
    CASE WHEN prev_net_circulation IS NOT NULL AND net_circulation < prev_net_circulation THEN 'Yes' ELSE 'No' END AS net_circulation_decline,
    CASE WHEN prev_ad_revenue IS NOT NULL AND ad_revenue < prev_ad_revenue THEN 'Yes' ELSE 'No' END AS ad_revenue_decline
FROM lagged
ORDER BY city_name, year;
 # 6. readiness 2021 vs pilot engagement outlier 2021
 
  WITH readiness_2021 AS (
    SELECT
        dc.city AS city_name,
        AVG((smartphone_penetration + internet_penetration + literacy_rate) / 3) AS readiness_score
    FROM fact_city_readiness fcr
    JOIN dim_city dc ON fcr.city_id = dc.City_ID
    WHERE LEFT(fcr.quarter,4) = '2021' -- filter all quarters in 2021
    GROUP BY dc.city
),
engagement_2021 AS (
    SELECT
        dc.city AS city_name,
        AVG(fe.avg_bounce_rate) AS engagement_metric
    FROM fact_digital_pilot fe
    JOIN dim_city dc ON fe.city_id = dc.City_ID
    GROUP BY dc.city
),
ranked AS (
    SELECT
        r.city_name,
        r.readiness_score,
        e.engagement_metric,
        RANK() OVER (ORDER BY r.readiness_score DESC) AS readiness_rank_desc,
        RANK() OVER (ORDER BY e.engagement_metric asc) AS engagement_rank_asc
    FROM readiness_2021 r
    JOIN engagement_2021 e ON r.city_name = e.city_name
)
SELECT
    city_name,
    readiness_score AS readiness_score_2021,
    engagement_metric AS engagement_metric_2021,
    readiness_rank_desc,
    engagement_rank_asc,
    CASE
        WHEN readiness_rank_desc = 1 AND engagement_rank_asc <= 3 THEN 'Yes' ELSE 'No'
    END AS is_outlier
FROM ranked
ORDER BY readiness_rank_desc;
