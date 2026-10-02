/*
04_create_mart_vehicle_risk_profile.sql

Final aggregation layer for the vehicle_risk_profiling mart schema.

Purpose:
- Produce the final mart output table to be consumed by R.
- Aggregate mart.vehicle_dimensions_2015_2024 to the business grain: one row per 
  combination of vehicle_type, propulsion_code, engine_capacity_band, vehicle_age_band.
- Calculate the project's three core contribution metrics:
  1. avg_weighted_severity_per_vehicle: mean weighted injury burden per collision involvement.
  2. frequency_share: each profile's share of all collision-involved vehicles (2015-2024).
  3. risk_proxy_score: each profile's contribution to the overall mean weighted
     injury burden per collision-involved vehicle.

Design choices:
- Business grain is set here: GROUP BY collapses vehicle-level rows into one row per 
  profile combination. This is the first and only aggregation to this grain in the pipeline.
- Final grouping keys: nullable code fields are normalised to an internal Unknown bucket 
  (-999), while nullable banding fields are normalised to 'Unknown'. This keeps unknown
  groups visible while allowing the declared primary key to be enforced.
- MIN() for label columns: vehicle_type_label and propulsion_label are deterministic per code, 
  so MIN() collapses them cleanly without requiring a separate CTE. Codes are the
  GROUP BY keys; labels are descriptive and resolved this way for conciseness.
- Frequency denominator: total_vehicles is the global count of all collision-involved
  vehicles across all profiles, derived from the profiles_aggregated CTE to avoid
  re-scanning the base table.
- Risk proxy score: a volume-weighted contribution measure. It ranks profiles by
  how much they add to the overall mean weighted injury burden, so frequent profiles
  score highly even when per-vehicle severity is modest. Frequency and average
  severity should be read separately (see the frequency-severity quadrant figure).
  Algebraically: 
  frequency_share * avg_weighted_severity_per_vehicle
  = (vehicle_count / total_vehicles) * (weighted_severity_total / vehicle_count)
  = weighted_severity_total / total_vehicles
- NULLIF guards: applied on all division operations to prevent zero-division errors,
  though in practice COUNT(*) denominators cannot be zero at this grain.
- DENSE_RANK(): applied to risk_proxy_score descending so R receives pre-computed rank
  positions, making the output immediately interpretable without further transformation.
- Unknown and sentinel-coded groups: retained so their volume remains visible and exclusion 
  decisions can be made in R with data, not assumptions.
*/

DROP TABLE IF EXISTS mart.vehicle_risk_profiles_2015_2024;

CREATE TABLE mart.vehicle_risk_profiles_2015_2024 AS
WITH profiles_aggregated AS (
    SELECT
        COALESCE(vehicle_type, -999)                         AS vehicle_type,
        COALESCE(MIN(vehicle_type_label), 'Unknown')         AS vehicle_type_label,
        COALESCE(propulsion_code, -999)                      AS propulsion_code,
        COALESCE(MIN(propulsion_label), 'Unknown')           AS propulsion_label,
        COALESCE(engine_capacity_band, 'Unknown')            AS engine_capacity_band,
        COALESCE(vehicle_age_band, 'Unknown')                AS vehicle_age_band,
        COUNT(*)                                             AS vehicle_count,
        SUM(slight_count)::int                               AS slight_count,
        SUM(serious_count)::int                              AS serious_count,
        SUM(fatal_count)::int                                AS fatal_count,
        SUM(weighted_severity_score)::int                    AS weighted_severity_total,
        (
            SUM(weighted_severity_score)::numeric 
            / NULLIF(COUNT(*), 0)
        )::numeric(18, 6) AS avg_weighted_severity_per_vehicle
    FROM mart.vehicle_dimensions_2015_2024
    GROUP BY
        COALESCE(vehicle_type, -999),
        COALESCE(propulsion_code, -999),
        COALESCE(engine_capacity_band, 'Unknown'),
        COALESCE(vehicle_age_band, 'Unknown')
),

total_vehicles AS (
    SELECT
        SUM(vehicle_count) AS total_vehicles
    FROM profiles_aggregated
),

final AS (
    SELECT
        pa.*,
        (
            pa.vehicle_count::numeric 
            / NULLIF(tv.total_vehicles, 0)
        )::numeric(18, 10) AS frequency_share,
        (
            (pa.vehicle_count::numeric / NULLIF(tv.total_vehicles, 0))
            * pa.avg_weighted_severity_per_vehicle
        )::numeric(18, 10) AS risk_proxy_score
    FROM profiles_aggregated AS pa
    CROSS JOIN total_vehicles AS tv
)

SELECT
    vehicle_type,
    vehicle_type_label,
    propulsion_code,
    propulsion_label,
    engine_capacity_band,
    vehicle_age_band,
    vehicle_count,
    slight_count,
    serious_count,
    fatal_count,
    weighted_severity_total,
    avg_weighted_severity_per_vehicle,
    frequency_share,
    risk_proxy_score,
    DENSE_RANK() OVER (ORDER BY risk_proxy_score DESC) AS risk_rank
FROM final;

ALTER TABLE mart.vehicle_risk_profiles_2015_2024
    ADD CONSTRAINT pk_vehicle_risk_profiles_2015_2024
    PRIMARY KEY (vehicle_type, propulsion_code, engine_capacity_band, vehicle_age_band);