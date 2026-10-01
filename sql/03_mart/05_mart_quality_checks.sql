/*
05_mart_quality_checks.sql

Quality assurance checks for the profiling_premium_risk mart schema.

Run each check individually.

Purpose:
- Validate structural integrity of the vehicle-level severity aggregation layer.
- Confirm grain enforcement at (collision_index, vehicle_reference).
- Ensure casualty counts and weighted severity calculations reconcile exactly with staging data.
- Provide explicit, auditable confirmation that no rows were lost, duplicated, 
  or miscalculated during aggregation.

Design choices:
- Checks focus on mart.vehicle_level_severity_2015_2024 because it is the first 
  transformation that changes grain and introduces weighted severity logic; 
  any error here would cascade through the remainder of the mart pipeline.
- Grain validation: duplicate detection confirms no duplicate rows exist at the declared 
  composite grain.
- Row-count reconciliation: mart row count is compared to DISTINCT 
  (collision_index, vehicle_reference) combinations from stg.casualties_2015_2024 
  to confirm one-to-one collapse from casualty to vehicle involvement level.
- Deterministic weight verification: weighted_severity_score is recomputed inline 
  to ensure no arithmetic drift or CASE logic misalignment.
- Casualty parity check: total slight/serious/fatal counts in the mart must equal 
  total casualty rows in staging, confirming no loss or double-counting.
- Severity domain validation: confirms only expected STATS19 severity codes 
  (1, 2, 3) are present; any unexpected values indicate upstream anomalies in the data.
*/

-- Check 1: Primary key grain uniqueness
-- Expected result: no rows should be returned under the headers.

SELECT
    collision_index,
    vehicle_reference,
    COUNT(*) AS duplicate_count
FROM mart.vehicle_level_severity_2015_2024
GROUP BY
    collision_index,
    vehicle_reference
HAVING COUNT(*) > 1;

-- Check 2: Mart row count equals distinct collision/vehicle combinations from staging
-- Expected result: counts_match should PASS.

WITH row_counts AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM mart.vehicle_level_severity_2015_2024
        ) AS mart_rows,
        (
            SELECT COUNT(*)
            FROM (
                SELECT DISTINCT
                    collision_index,
                    vehicle_reference
                FROM stg.casualties_2015_2024
            ) AS distinct_casualty_vehicles
        ) AS distinct_vehicle_in_casualties
)

SELECT
    mart_rows,
    distinct_vehicle_in_casualties,
    CASE
        WHEN mart_rows = distinct_vehicle_in_casualties THEN 'PASS'
        ELSE 'FAIL'
    END AS counts_match
FROM row_counts;

-- Check 3: Weighted severity score integrity across mart rows
-- Expected result: mismatched_rows should equal 0.

SELECT
    COUNT(*) AS mismatched_rows
FROM mart.vehicle_level_severity_2015_2024
WHERE weighted_severity_score <>
      (
            (slight_count  * 1)
          + (serious_count * 15)
          + (fatal_count   * 60)
      );

-- Check 4: Mart casualty counts reconcile to staging casualty rows
-- Expected result: counts_match should PASS.

WITH casualty_counts AS (
    SELECT
        (
            SELECT COUNT(*)
            FROM stg.casualties_2015_2024
        ) AS stg_casualty_rows,
        (
            SELECT SUM(slight_count + serious_count + fatal_count)
            FROM mart.vehicle_level_severity_2015_2024
        ) AS summed_mart_casualty_counts
)

SELECT
    stg_casualty_rows,
    summed_mart_casualty_counts,
    CASE
        WHEN stg_casualty_rows = summed_mart_casualty_counts THEN 'PASS'
        ELSE 'FAIL'
    END AS counts_match
FROM casualty_counts;

-- Check 5: Severity integer values
-- Expected result: exactly three rows, with casualty_severity values 1, 2 and 3 only; no NULL or unexpected codes.

SELECT
    casualty_severity,
    CASE casualty_severity
        WHEN 1 THEN 'Fatal'
        WHEN 2 THEN 'Serious'
        WHEN 3 THEN 'Slight'
        ELSE 'Unexpected'
    END AS severity_label,
    COUNT(*) AS row_count
FROM stg.casualties_2015_2024
GROUP BY
    casualty_severity,
    CASE casualty_severity
        WHEN 1 THEN 'Fatal'
        WHEN 2 THEN 'Serious'
        WHEN 3 THEN 'Slight'
        ELSE 'Unexpected'
    END
ORDER BY casualty_severity;