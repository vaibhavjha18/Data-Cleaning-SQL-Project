# Data Cleaning SQL Project – Nashville Housing

**Author:** Vaibhav Jha  
**GitHub:** [github.com/vaibhavjha18](https://github.com/vaibhavjha18)  
**LinkedIn:** [linkedin.com/in/vaibhav-jha-623349261](https://linkedin.com/in/vaibhav-jha-623349261)  
**Email:** vaibhavjha612@gmail.com

---

## Project Overview

This project cleans a real-world, messy housing dataset from Nashville using SQL, then uses the cleaned data to answer a few market questions. The goal was to turn raw, inconsistent records into an analysis-ready table: fix formats, fill missing values, split combined columns, remove duplicates, and document the problems that cannot be fixed.

---

## Tools Used

- SQL (SQLite 3.35 or newer)
- DB Browser for SQLite or the `sqlite3` command line

---

## Dataset

- **Source:** Nashville Housing Sales Data
- **Size:** 56,477 sale records, 19 columns, sales dated 2013–2016
- **Raw data:** `data/housing_raw.db` (never modified)
- **Cleaned result:** `data/housing_clean.db` (output of `SQL_Data_Cleaning.sql`)

---

## Results at a Glance

| Check                                   | Before   | After    |
|-----------------------------------------|----------|----------|
| Rows                                    | 56,477   | 56,373   |
| Sale dates not in `YYYY-MM-DD` format   | 56,477   | 0        |
| NULL property addresses                 | 29       | 0        |
| `SoldAsVacant` stored as Y/N            | 451      | 0        |
| Property addresses with doubled spaces  | 55,856   | 0        |
| Duplicate sale groups                   | 103      | 0        |
| Distinct `LandUse` labels               | 39       | 37       |
| Rows flagged as multi-parcel sales      | –        | 4,767    |

The script prints this same before/after table when it finishes.

---

## Cleaning Steps (`SQL_Data_Cleaning.sql`)

The step numbers below match the comments in the script.

- **Step 0 – Backup:** copy of the raw table, used for the before/after check.
- **Step 1 – Standardized dates:** `April 9, 2013` → `2013-04-09`.
- **Step 2 – Filled missing property addresses:** taken from another sale of the same `ParcelID`.
- **Step 3 – Split property address** into street and city; doubled spaces removed.
- **Step 4 – Split owner address** into street, city and state.
- **Step 5 – Standardized `SoldAsVacant`:** `Y`/`N` → `Yes`/`No`.
- **Step 6 – Standardized `LandUse` labels:** merged `VACANT RES LAND` and `VACANT RESIENTIAL LAND` into `VACANT RESIDENTIAL LAND` and fixed two other typos.
- **Step 7 – Removed 104 duplicate sales:** `ROW_NUMBER()` over parcel, address, date, price and legal reference.
- **Step 8 – Flagged multi-parcel sales:** when one deal covers several parcels, the total price is repeated on every parcel. These rows are kept and flagged (`MultiParcelSale = 1`) so price analysis can exclude them.
- **Step 9 – Dropped the two combined address columns** after splitting. `TaxDistrict` is kept because it is useful for area analysis.

---

## Known Data Issues (documented, not silently changed)

- **54% of rows (30,404)** have no owner address, acreage, tax district or valuation data. There is no reliable way to fill these, so they stay `NULL`.
- **7 sales have a price of $0.** Kept, but excluded from price analysis.
- **2 sales are dated 2019** while the data otherwise ends in 2016. Their legal references point to 2016 and 2014, so they look like typos. Kept, but excluded from yearly analysis.
- **`CONDO` (247 rows) vs `RESIDENTIAL CONDO` (14,064 rows)** may be a real distinction, so they were not merged.

---

## Analysis (`SQL_Analysis.sql`)

Price queries use single-family homes, `SalePrice > 0`, non-bulk sales and 2013–2016 only. Medians are used because a few very large sales pull averages up. Full output is in `SQL_Analysis_Results.md`.

- **Prices are rising:** the median single-family price went from $185,000 (2013) to $235,000 (2016), with year-over-year growth of 7.5%, 5.6% and 11.9%.
- **Brentwood ($329,450) and Nolensville ($306,600)** have the highest median prices; Madison ($138,000) has the lowest among the eight cities with 300+ sales.
- **Bedrooms matter, especially at 4+:** median price is $179,000 for 3 bedrooms and $345,000 for 4 bedrooms (bedroom data exists for about 24,000 rows only).
- **Quick resales:** 1,133 existing homes were resold within 12 months, 95% for more than the previous price (median gain 63%, before renovation and closing costs, so not profit).

---

## How to Run

Always start from a fresh copy of the raw database:

```bash
cp data/housing_raw.db housing_work.db
sqlite3 -bail housing_work.db < SQL_Data_Cleaning.sql
sqlite3 housing_work.db < SQL_Analysis.sql
```

Or open `housing_work.db` in DB Browser for SQLite and run each script in the **Execute SQL** tab.

The cleaning script runs as a single transaction. If you run it a second time it stops immediately (the backup table already exists) and changes nothing.

---

## Project Structure

```
Data-Cleaning-SQL-Project/
├── README.md
├── SQL_Data_Cleaning.sql        cleaning script (steps 0-9 + before/after check)
├── SQL_Analysis.sql             5 analysis queries on the cleaned data
├── SQL_Analysis_Results.md      output of the analysis queries
└── data/
    ├── housing_raw.db           raw data, untouched
    └── housing_clean.db         cleaned table
```

---

## Skills Demonstrated

- Data cleaning with SQL: `UPDATE` with a correlated subquery, `ALTER TABLE`, `CASE`, `printf`
- String parsing with `substr`, `instr`, `trim` and `replace`
- Handling missing values and removing duplicates
- Window functions (`ROW_NUMBER`, `LAG`, `RANK`, `COUNT OVER`) and CTEs
- Safe workflow: backup table, single transaction, before/after validation
- Spotting data-quality problems (bulk sales, typo dates, $0 prices) and documenting them
- Turning clean data into business insights

---

## Notes

This project is part of my data analyst portfolio and demonstrates practical SQL skills required for entry-level data analyst roles. The script was tested end to end on a fresh copy of the raw database (SQLite 3.45) and reproduces `data/housing_clean.db` exactly.
