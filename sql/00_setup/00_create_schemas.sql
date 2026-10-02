/*
Project Title: Vehicle Risk Profiling with UK STATS19: A Motor Insurance Feasibility Study
Database Name: vehicle_risk_profiling

Purpose:
- This script creates the core schemas used in the project. It assumes the 
  database already exists locally.
- A medallion-style data architecture informs the schema structure, progressing
  from raw source data to staged data to analysis-ready tables.
- Schemas separate transformation stages and make data lineage explicit, which
  supports debugging and reproducibility.

Schemas:
- raw: Faithful, unmodified representations of the three source CSVs in /data/raw:
  collisions_master.csv, vehicles_master.csv, casualties_master.csv.
- stg: Tables that are cleaned, explicitly type-cast, and scoped to the project's
  analytical time window (the intermediate layer).
- mart: Analysis-ready vehicle-profile tables summarising collision involvement
  and weighted injury burden by vehicle characteristics (type, propulsion,
  engine capacity band, vehicle age band).
*/

CREATE SCHEMA IF NOT EXISTS raw;  -- Raw source layer
CREATE SCHEMA IF NOT EXISTS stg;  -- Staging layer
CREATE SCHEMA IF NOT EXISTS mart; -- Analysis-ready data mart
