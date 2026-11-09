# Analysis results

Output of `SQL_Analysis.sql`, run on `data/housing_clean.db` (56,373 cleaned sales, 2013-2016).
Price queries use single-family homes, `SalePrice > 0`, `MultiParcelSale = 0` and sales before 2017 (see the header of the SQL file).

## Q1. Single-family price trend by year (median, with year-over-year change)

| yr | sales | avg_price | median_price | median_yoy_pct |
|---|---|---|---|---|
| 2013 | 6,980 | $250,398 | $185,000 | - |
| 2014 | 8,377 | $260,030 | $198,850 | 7.5 |
| 2015 | 9,683 | $273,590 | $210,000 | 5.6 |
| 2016 | 8,332 | $300,213 | $235,000 | 11.9 |

## Q2. Most expensive cities (cities with 300+ single-family sales)

| price_rank | city | sales | median_price |
|---|---|---|---|
| 1 | BRENTWOOD | 974 | $329,450 |
| 2 | NOLENSVILLE | 344 | $306,600 |
| 3 | NASHVILLE | 22,848 | $231,500 |
| 4 | HERMITAGE | 2,123 | $194,040 |
| 5 | ANTIOCH | 3,993 | $165,990 |
| 6 | GOODLETTSVILLE | 500 | $164,400 |
| 7 | OLD HICKORY | 1,118 | $156,250 |
| 8 | MADISON | 1,270 | $138,000 |

## Q3. Median price by bedroom count (single-family, 100+ sales)

| bedrooms | sales | median_price |
|---|---|---|
| 2 | 4,359 | $149,000 |
| 3 | 11,855 | $179,000 |
| 4 | 3,800 | $345,000 |
| 5 | 739 | $585,000 |
| 6 | 118 | $757,500 |

## Q4a. Quick resales (sold twice within 12 months) by type of home

| home_type | resales | avg_days_between_sales | pct_sold_for_more | median_gain_pct |
|---|---|---|---|---|
| 1 - existing home | 1,133 | 175 | 95.2 | 63.3 |
| 2 - new construction | 165 | 234 | 98.2 | 203.9 |
| 3 - year built unknown | 303 | 162 | 92.4 | 33.3 |

## Q4b. Five biggest quick-resale gains among existing homes

| address | city | YearBuilt | prev_date | prev_price | SaleDate | SalePrice | days_held | gain_pct |
|---|---|---|---|---|---|---|---|---|
| 1017 N 6TH ST | NASHVILLE | 1930 | 2013-12-16 | $52,000 | 2014-08-22 | $330,000 | 249 | 534.6 |
| 1010 11TH AVE N | NASHVILLE | 1920 | 2013-10-24 | $50,000 | 2014-06-18 | $309,000 | 237 | 518.0 |
| 814 PETWAY AVE | NASHVILLE | 1953 | 2014-02-18 | $65,000 | 2014-08-22 | $365,000 | 185 | 461.5 |
| 1009 STOCKELL ST | NASHVILLE | 1930 | 2013-09-19 | $50,000 | 2014-02-13 | $253,690 | 147 | 407.4 |
| 802 WINTHORNE CT | NASHVILLE | 1960 | 2015-09-18 | $60,000 | 2016-09-16 | $295,000 | 364 | 391.7 |
