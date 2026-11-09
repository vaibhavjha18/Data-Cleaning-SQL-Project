-- =====================================================================
-- NASHVILLE HOUSING - ANALYSIS ON THE CLEANED DATA (SQLite)
-- Author : Vaibhav Jha
-- Run on data/housing_clean.db (or on your work copy after SQL_Data_Cleaning.sql)
--
-- Ground rules used in the price queries:
--   * SalePrice > 0              - 7 sales are recorded at $0
--   * MultiParcelSale = 0        - bulk deals repeat one total price on every parcel
--   * SaleDate < '2017-01-01'    - data covers 2013-2016 (two rows dated 2019 look like typos)
--   * LandUse = 'SINGLE FAMILY'  - keeps the homes comparable
-- Medians are used because a few very large sales pull averages up.
-- SQLite has no MEDIAN(), so it is built from ROW_NUMBER() + COUNT() window functions.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Single-family price trend by year, with year-over-year change (LAG)
-- ---------------------------------------------------------------------
WITH sf AS (
    SELECT substr(SaleDate, 1, 4) AS yr,
           SalePrice,
           ROW_NUMBER() OVER (PARTITION BY substr(SaleDate, 1, 4) ORDER BY SalePrice) AS rn,
           COUNT(*)     OVER (PARTITION BY substr(SaleDate, 1, 4))                    AS cnt
    FROM nashvillehousingdata
    WHERE LandUse = 'SINGLE FAMILY' AND SalePrice > 0
      AND MultiParcelSale = 0 AND SaleDate < '2017-01-01'
),
yearly AS (
    SELECT yr,
           MAX(cnt)                                                        AS sales,
           ROUND(AVG(SalePrice))                                           AS avg_price,
           ROUND(AVG(CASE WHEN rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
                          THEN SalePrice END))                             AS median_price
    FROM sf
    GROUP BY yr
)
SELECT yr, sales, avg_price, median_price,
       ROUND(100.0 * (median_price - LAG(median_price) OVER (ORDER BY yr))
                   / LAG(median_price) OVER (ORDER BY yr), 1)              AS median_yoy_pct
FROM yearly
ORDER BY yr;


-- ---------------------------------------------------------------------
-- Q2. Which cities are most expensive? (cities with 300+ single-family sales)
-- ---------------------------------------------------------------------
WITH sf AS (
    SELECT PropertySplitCity AS city,
           SalePrice,
           ROW_NUMBER() OVER (PARTITION BY PropertySplitCity ORDER BY SalePrice) AS rn,
           COUNT(*)     OVER (PARTITION BY PropertySplitCity)                    AS cnt
    FROM nashvillehousingdata
    WHERE LandUse = 'SINGLE FAMILY' AND SalePrice > 0
      AND MultiParcelSale = 0 AND SaleDate < '2017-01-01'
),
cities AS (
    SELECT city,
           MAX(cnt) AS sales,
           ROUND(AVG(CASE WHEN rn IN ((cnt + 1) / 2, (cnt + 2) / 2) THEN SalePrice END)) AS median_price
    FROM sf
    GROUP BY city
    HAVING MAX(cnt) >= 300
)
SELECT RANK() OVER (ORDER BY median_price DESC) AS price_rank,
       city, sales, median_price
FROM cities
ORDER BY price_rank;


-- ---------------------------------------------------------------------
-- Q3. How much does bedroom count move the price? (single-family, 100+ sales)
-- ---------------------------------------------------------------------
WITH sf AS (
    SELECT Bedrooms AS bedrooms,
           SalePrice,
           ROW_NUMBER() OVER (PARTITION BY Bedrooms ORDER BY SalePrice) AS rn,
           COUNT(*)     OVER (PARTITION BY Bedrooms)                    AS cnt
    FROM nashvillehousingdata
    WHERE LandUse = 'SINGLE FAMILY' AND SalePrice > 0
      AND MultiParcelSale = 0 AND SaleDate < '2017-01-01'
      AND Bedrooms BETWEEN 1 AND 6
)
SELECT bedrooms,
       MAX(cnt) AS sales,
       ROUND(AVG(CASE WHEN rn IN ((cnt + 1) / 2, (cnt + 2) / 2) THEN SalePrice END)) AS median_price
FROM sf
GROUP BY bedrooms
HAVING MAX(cnt) >= 100
ORDER BY bedrooms;


-- ---------------------------------------------------------------------
-- Q4a. Quick resales: single-family homes sold twice within 12 months
-- LAG() fetches the previous sale of the same parcel. Both prices must be at
-- least $50,000 (skips nominal transfers). YearBuilt separates existing homes
-- (built before the first sale) from new construction, where a builder buys a
-- lot and sells the finished house - that is not a renovation "flip".
-- ---------------------------------------------------------------------
WITH sales AS (
    SELECT ParcelID, SaleDate, SalePrice, YearBuilt,
           LAG(SaleDate)  OVER (PARTITION BY ParcelID ORDER BY SaleDate, UniqueID) AS prev_date,
           LAG(SalePrice) OVER (PARTITION BY ParcelID ORDER BY SaleDate, UniqueID) AS prev_price
    FROM nashvillehousingdata
    WHERE LandUse = 'SINGLE FAMILY' AND MultiParcelSale = 0
      AND SalePrice >= 50000 AND SaleDate < '2017-01-01'
),
resales AS (
    SELECT *,
           CAST(julianday(SaleDate) - julianday(prev_date) AS INTEGER) AS days_held,
           100.0 * (SalePrice - prev_price) / prev_price               AS gain_pct,
           CASE WHEN YearBuilt IS NULL                                   THEN '3 - year built unknown'
                WHEN YearBuilt < CAST(substr(prev_date, 1, 4) AS INTEGER) THEN '1 - existing home'
                ELSE '2 - new construction' END                         AS home_type
    FROM sales
    WHERE prev_price IS NOT NULL
),
quick AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY home_type ORDER BY gain_pct) AS rn,
           COUNT(*)     OVER (PARTITION BY home_type)                   AS cnt
    FROM resales
    WHERE days_held BETWEEN 1 AND 365
)
SELECT home_type,
       MAX(cnt)                                                        AS resales,
       ROUND(AVG(days_held))                                           AS avg_days_between_sales,
       ROUND(100.0 * SUM(gain_pct > 0) / COUNT(*), 1)                  AS pct_sold_for_more,
       ROUND(AVG(CASE WHEN rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
                      THEN gain_pct END), 1)                           AS median_gain_pct
FROM quick
GROUP BY home_type
ORDER BY home_type;


-- ---------------------------------------------------------------------
-- Q4b. The five biggest quick-resale gains among existing homes
-- (a sanity check by eye - old houses bought cheap and resold within a year)
-- ---------------------------------------------------------------------
WITH sales AS (
    SELECT PropertySplitAddress AS address, PropertySplitCity AS city, YearBuilt,
           SaleDate, SalePrice,
           LAG(SaleDate)  OVER (PARTITION BY ParcelID ORDER BY SaleDate, UniqueID) AS prev_date,
           LAG(SalePrice) OVER (PARTITION BY ParcelID ORDER BY SaleDate, UniqueID) AS prev_price
    FROM nashvillehousingdata
    WHERE LandUse = 'SINGLE FAMILY' AND MultiParcelSale = 0
      AND SalePrice >= 50000 AND SaleDate < '2017-01-01'
)
SELECT address, city, YearBuilt, prev_date, prev_price, SaleDate, SalePrice,
       CAST(julianday(SaleDate) - julianday(prev_date) AS INTEGER) AS days_held,
       ROUND(100.0 * (SalePrice - prev_price) / prev_price, 1)     AS gain_pct
FROM sales
WHERE prev_price IS NOT NULL
  AND julianday(SaleDate) - julianday(prev_date) BETWEEN 1 AND 365
  AND YearBuilt IS NOT NULL AND YearBuilt < CAST(substr(prev_date, 1, 4) AS INTEGER)
ORDER BY gain_pct DESC
LIMIT 5;
