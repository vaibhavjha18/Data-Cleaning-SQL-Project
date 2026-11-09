-- =====================================================================
-- NASHVILLE HOUSING - DATA CLEANING (SQLite)
-- Author : Vaibhav Jha
--
-- HOW TO RUN (always on a COPY of the raw database):
--   cp data/housing_raw.db housing_work.db
--   sqlite3 -bail housing_work.db < SQL_Data_Cleaning.sql
-- or open housing_work.db in DB Browser for SQLite -> Execute SQL -> run all.
--
-- Requires SQLite 3.35+ (window functions + ALTER TABLE ... DROP COLUMN).
-- The script runs as ONE transaction and creates a backup table first, so
-- running it a second time fails immediately (backup already exists) and
-- changes nothing.
-- =====================================================================

BEGIN TRANSACTION;

-- ---------------------------------------------------------------------
-- STEP 0 - Backup the raw table (used for the before/after check at the end)
-- ---------------------------------------------------------------------
CREATE TABLE nashvillehousingdata_backup AS
SELECT * FROM nashvillehousingdata;


-- ---------------------------------------------------------------------
-- STEP 1 - Standardise SaleDate: 'April 9, 2013'  ->  '2013-04-09'
-- The WHERE clause only touches dates still in the long text format.
-- ---------------------------------------------------------------------
UPDATE nashvillehousingdata
SET SaleDate = printf(
        '%04d-%02d-%02d',
        CAST(substr(SaleDate, -4) AS INTEGER),
        CASE substr(SaleDate, 1, instr(SaleDate, ' ') - 1)
            WHEN 'January'   THEN 1   WHEN 'February' THEN 2   WHEN 'March'    THEN 3
            WHEN 'April'     THEN 4   WHEN 'May'      THEN 5   WHEN 'June'     THEN 6
            WHEN 'July'      THEN 7   WHEN 'August'   THEN 8   WHEN 'September' THEN 9
            WHEN 'October'   THEN 10  WHEN 'November' THEN 11  WHEN 'December' THEN 12
        END,
        CAST(substr(SaleDate,
                    instr(SaleDate, ' ') + 1,
                    instr(SaleDate, ',') - instr(SaleDate, ' ') - 1) AS INTEGER))
WHERE SaleDate LIKE '% %, %';


-- ---------------------------------------------------------------------
-- STEP 2 - Fill NULL PropertyAddress using another sale of the same ParcelID
-- (a parcel always has the same address, so a sibling row can supply it)
-- ---------------------------------------------------------------------
UPDATE nashvillehousingdata AS a
SET PropertyAddress = (
        SELECT b.PropertyAddress
        FROM nashvillehousingdata AS b
        WHERE b.ParcelID = a.ParcelID
          AND b.UniqueID <> a.UniqueID
          AND b.PropertyAddress IS NOT NULL
        LIMIT 1)
WHERE a.PropertyAddress IS NULL;


-- ---------------------------------------------------------------------
-- STEP 3 - Split PropertyAddress ('street, city') into two columns
-- replace(...,'  ',' ') removes the doubled spaces found in the raw street names
-- ---------------------------------------------------------------------
ALTER TABLE nashvillehousingdata ADD COLUMN PropertySplitAddress TEXT;
ALTER TABLE nashvillehousingdata ADD COLUMN PropertySplitCity    TEXT;

UPDATE nashvillehousingdata
SET PropertySplitAddress = replace(replace(
        trim(substr(PropertyAddress, 1, instr(PropertyAddress, ',') - 1)),
        '  ', ' '), '  ', ' '),
    PropertySplitCity = trim(substr(PropertyAddress, instr(PropertyAddress, ',') + 1));


-- ---------------------------------------------------------------------
-- STEP 4 - Split OwnerAddress ('street, city, state') into three columns
-- (OwnerAddress is NULL for about half the rows - those stay NULL)
-- ---------------------------------------------------------------------
ALTER TABLE nashvillehousingdata ADD COLUMN OwnerSplitAddress TEXT;
ALTER TABLE nashvillehousingdata ADD COLUMN OwnerSplitCity    TEXT;
ALTER TABLE nashvillehousingdata ADD COLUMN OwnerSplitState   TEXT;

UPDATE nashvillehousingdata
SET OwnerSplitAddress = replace(replace(
        trim(substr(OwnerAddress, 1, instr(OwnerAddress, ',') - 1)),
        '  ', ' '), '  ', ' '),
    -- text between the 1st and 2nd comma
    OwnerSplitCity = trim(substr(
        OwnerAddress,
        instr(OwnerAddress, ',') + 1,
        instr(substr(OwnerAddress, instr(OwnerAddress, ',') + 1), ',') - 1)),
    -- text after the 2nd comma
    OwnerSplitState = trim(substr(
        OwnerAddress,
        instr(OwnerAddress, ',') + 1
          + instr(substr(OwnerAddress, instr(OwnerAddress, ',') + 1), ',')))
WHERE OwnerAddress IS NOT NULL;


-- ---------------------------------------------------------------------
-- STEP 5 - SoldAsVacant: 'Y'/'N' -> 'Yes'/'No' (the column mixed both styles)
-- ---------------------------------------------------------------------
UPDATE nashvillehousingdata
SET SoldAsVacant = CASE SoldAsVacant
                       WHEN 'Y' THEN 'Yes'
                       WHEN 'N' THEN 'No'
                       ELSE SoldAsVacant
                   END;


-- ---------------------------------------------------------------------
-- STEP 6 - LandUse: merge labels that are clearly the same thing / typos
-- (CONDO vs RESIDENTIAL CONDO is left alone - it may be a real distinction)
-- ---------------------------------------------------------------------
UPDATE nashvillehousingdata
SET LandUse = CASE
        WHEN LandUse IN ('VACANT RES LAND', 'VACANT RESIENTIAL LAND') THEN 'VACANT RESIDENTIAL LAND'
        WHEN LandUse LIKE 'GREENBELT/RES%'                            THEN 'GREENBELT/RES'
        WHEN LandUse = 'RESTURANT/CAFETERIA'                          THEN 'RESTAURANT/CAFETERIA'
        WHEN LandUse = 'CONDOMINIUM OFC  OR OTHER COM CONDO'          THEN 'CONDOMINIUM OFC OR OTHER COM CONDO'
        ELSE LandUse
    END;


-- ---------------------------------------------------------------------
-- STEP 7 - Remove duplicate sale records
-- Same parcel + address + date + price + legal reference = same sale.
-- ROW_NUMBER() keeps the lowest UniqueID of each group, deletes the rest.
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT UniqueID,
           ROW_NUMBER() OVER (
               PARTITION BY ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference
               ORDER BY UniqueID) AS rn
    FROM nashvillehousingdata
)
DELETE FROM nashvillehousingdata
WHERE UniqueID IN (SELECT UniqueID FROM ranked WHERE rn > 1);


-- ---------------------------------------------------------------------
-- STEP 8 - Flag multi-parcel (bulk) sales instead of deleting them
-- When one deal covers several parcels, the TOTAL price is repeated on every
-- parcel row (e.g. one $5.49M portfolio sale shows up on dozens of houses).
-- Those rows are real, but their SalePrice is not a per-property price, so
-- price analysis filters on MultiParcelSale = 0.
-- ---------------------------------------------------------------------
ALTER TABLE nashvillehousingdata ADD COLUMN MultiParcelSale INTEGER DEFAULT 0;

UPDATE nashvillehousingdata
SET MultiParcelSale = 1
WHERE (LegalReference, SaleDate, SalePrice) IN (
        SELECT LegalReference, SaleDate, SalePrice
        FROM nashvillehousingdata
        GROUP BY LegalReference, SaleDate, SalePrice
        HAVING COUNT(DISTINCT ParcelID) > 1);


-- ---------------------------------------------------------------------
-- STEP 9 - Drop the two combined address columns (now split; raw values
-- remain in nashvillehousingdata_backup). TaxDistrict is KEPT: it has real
-- values for every row that has owner data and is useful for area analysis.
-- ---------------------------------------------------------------------
ALTER TABLE nashvillehousingdata DROP COLUMN PropertyAddress;
ALTER TABLE nashvillehousingdata DROP COLUMN OwnerAddress;

COMMIT;


-- =====================================================================
-- CHECK - before vs after (expected values for the supplied raw data)
-- =====================================================================
SELECT 'Rows' AS check_name,
       (SELECT COUNT(*) FROM nashvillehousingdata_backup) AS before_cleaning,
       (SELECT COUNT(*) FROM nashvillehousingdata)        AS after_cleaning,
       '56,477 -> 56,373 (104 duplicates removed)'        AS expected
UNION ALL
SELECT 'Sale dates not in YYYY-MM-DD',
       (SELECT COUNT(*) FROM nashvillehousingdata_backup
         WHERE SaleDate NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
       (SELECT COUNT(*) FROM nashvillehousingdata
         WHERE SaleDate NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
       '56,477 -> 0'
UNION ALL
SELECT 'NULL property addresses',
       (SELECT COUNT(*) FROM nashvillehousingdata_backup WHERE PropertyAddress IS NULL),
       (SELECT COUNT(*) FROM nashvillehousingdata WHERE PropertySplitAddress IS NULL),
       '29 -> 0'
UNION ALL
SELECT 'SoldAsVacant stored as Y/N',
       (SELECT COUNT(*) FROM nashvillehousingdata_backup WHERE SoldAsVacant IN ('Y', 'N')),
       (SELECT COUNT(*) FROM nashvillehousingdata WHERE SoldAsVacant IN ('Y', 'N')),
       '451 -> 0'
UNION ALL
SELECT 'Distinct LandUse labels',
       (SELECT COUNT(DISTINCT LandUse) FROM nashvillehousingdata_backup),
       (SELECT COUNT(DISTINCT LandUse) FROM nashvillehousingdata),
       '39 -> 37'
UNION ALL
SELECT 'Property addresses with doubled spaces',
       (SELECT COUNT(*) FROM nashvillehousingdata_backup WHERE PropertyAddress LIKE '%  %'),
       (SELECT COUNT(*) FROM nashvillehousingdata WHERE PropertySplitAddress LIKE '%  %'),
       '55,856 -> 0'
UNION ALL
SELECT 'Duplicate sale records remaining',
       (SELECT COUNT(*) FROM (SELECT 1 FROM nashvillehousingdata_backup
                              GROUP BY ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference
                              HAVING COUNT(*) > 1)),
       (SELECT COUNT(*) FROM (SELECT 1 FROM nashvillehousingdata
                              GROUP BY ParcelID, PropertySplitAddress, SaleDate, SalePrice, LegalReference
                              HAVING COUNT(*) > 1)),
       '103 duplicate groups (104 extra rows) -> 0'
UNION ALL
SELECT 'Rows flagged as multi-parcel sales',
       0,
       (SELECT COUNT(*) FROM nashvillehousingdata WHERE MultiParcelSale = 1),
       '4,767 rows in 1,183 bulk sales (see STEP 8)';
