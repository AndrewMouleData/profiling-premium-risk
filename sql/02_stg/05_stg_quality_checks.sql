/*
05_stg_quality_checks.sql

Quality assurance checks for the vehicle_risk_profiling staging schema.

Run each check individually.

Purpose:
- Validate that staging tables match expected hierarchical grain and time scope (2015-2024).
- Confirm key fields are populated and joinable.
- Detect data quality issues before analytics begin.

Design principles:
- Read-only: no data is modified.
*/

-- Check 1: Row count integrity
-- Expected result: all row counts > 0, ordered as vehicles > casualties > collisions

SELECT
    'stg.collisions_2015_2024' AS table_name,
    COUNT(*) AS row_count
FROM stg.collisions_2015_2024

UNION ALL

SELECT
    'stg.casualties_2015_2024' AS table_name,
    COUNT(*) AS row_count
FROM stg.casualties_2015_2024

UNION ALL

SELECT
    'stg.vehicles_2015_2024' AS table_name,
    COUNT(*) AS row_count
FROM stg.vehicles_2015_2024

ORDER BY row_count DESC;

-- Check 2: Time window validation
-- Expected result: scope_validation should PASS

SELECT
    MIN(accident_date) AS min_date,
    MAX(accident_date) AS max_date,
    CASE
        WHEN MIN(accident_date) >= DATE '2015-01-01'
             AND MAX(accident_date) < DATE '2025-01-01'
            THEN 'PASS'
        ELSE 'FAIL'
    END AS scope_validation
FROM stg.collisions_2015_2024;

-- Check 3: No null primary keys
-- Expected result: each null-count field should equal 0

SELECT
    (
        SELECT COUNT(*)
        FROM stg.collisions_2015_2024
        WHERE collision_index IS NULL
    ) AS collision_pk_nulls,
    (
        SELECT COUNT(*)
        FROM stg.vehicles_2015_2024
        WHERE collision_index IS NULL
           OR vehicle_reference IS NULL
    ) AS vehicle_pk_nulls,
    (
        SELECT COUNT(*)
        FROM stg.casualties_2015_2024
        WHERE collision_index IS NULL
           OR vehicle_reference IS NULL
           OR casualty_reference IS NULL
    ) AS casualty_pk_nulls;

-- Check 4: Confirm no duplicates in primary and composite key grains
-- Expected result: no rows should be returned under the headers

-- [collision table grain]
SELECT
    collision_index,
    COUNT(*) AS duplicate_count
FROM stg.collisions_2015_2024
GROUP BY collision_index
HAVING COUNT(*) > 1;

-- [vehicle table grain]
SELECT
    collision_index,
    vehicle_reference,
    COUNT(*) AS duplicate_count
FROM stg.vehicles_2015_2024
GROUP BY collision_index, vehicle_reference
HAVING COUNT(*) > 1;

-- [casualty table grain]
SELECT
    collision_index,
    vehicle_reference,
    casualty_reference,
    COUNT(*) AS duplicate_count
FROM stg.casualties_2015_2024
GROUP BY collision_index, vehicle_reference, casualty_reference
HAVING COUNT(*) > 1;

-- Check 5: Referential integrity, number of orphaned records after joins
-- Expected result: each orphan-count field should equal 0

SELECT
    -- [orphan vehicles check on collision]
    (
        SELECT
            COUNT(*)
        FROM stg.vehicles_2015_2024 AS vchls
        LEFT JOIN stg.collisions_2015_2024 AS colls
            ON vchls.collision_index = colls.collision_index
        WHERE colls.collision_index IS NULL
    ) AS orphan_vehicles_to_collision,

    -- [orphan casualties check on collision]
    (
        SELECT
            COUNT(*)
        FROM stg.casualties_2015_2024 AS casul
        LEFT JOIN stg.collisions_2015_2024 AS colls
            ON casul.collision_index = colls.collision_index
        WHERE colls.collision_index IS NULL
    ) AS orphan_casualties_to_collision,

    -- [orphan casualties check on vehicle]
    (
        SELECT
            COUNT(*)
        FROM stg.casualties_2015_2024 AS casul
        LEFT JOIN stg.vehicles_2015_2024 AS vchls
            ON casul.collision_index = vchls.collision_index
            AND casul.vehicle_reference = vchls.vehicle_reference
        WHERE casul.vehicle_reference IS NOT NULL
          AND vchls.collision_index IS NULL
    ) AS orphan_casualties_to_vehicle;

-- Check 6: Check severity integer values
-- Expected result: exactly three rows, with casualty_severity values 1, 2 and 3 only; no NULL or unexpected codes.

SELECT
    casualty_severity,
    COUNT(*) AS row_count
FROM stg.casualties_2015_2024
GROUP BY casualty_severity
ORDER BY casualty_severity;

