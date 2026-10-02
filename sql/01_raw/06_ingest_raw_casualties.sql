/*
06_ingest_raw_casualties.sql

Purpose:
- Client-side ingestion of all observations from data/raw/casualties_master.csv 
  into the raw.casualties table.

Execution guide (IMPORTANT):
- This script must be executed via the PostgreSQL command-line client (psql) 
  inside a shell application.
- It cannot be run directly in GUI query tools such as pgAdmin, because \copy 
  is a psql meta-command rather than standard SQL.
- Ensure psql is available in your system PATH before running the command below.
- If psql is not available in PATH, or you prefer not to add it, an alternative command 
  using the full psql.exe path is provided.
- Run from any shell application you prefer, with the working directory set to 
  the project root.
- The example commands below use Windows paths. macOS/Linux users should use 
  the equivalent local project path and shell syntax.
- You may need to adjust the local project path, PostgreSQL username, or database name 
  depending on your machine.

Design choices (raw layer):
- Use of client-side \copy avoids relying on the PostgreSQL server process having 
  direct file-system access to the local data/raw directory, which can cause 
  permission and path-resolution issues on local installs.
- CSV paths are kept relative to the project root for simpler reproducibility.
- No filtering, transformation, or type casting is applied at this stage.

--------------------------------------------------------------------------------
Shell commands (adjust for your file path, PostgreSQL details, and shell syntax):
> cd "C:\Users\YourName\Datasets\vehicle-risk-profiling"
> psql -U postgres -d vehicle_risk_profiling -f sql/01_raw/06_ingest_raw_casualties.sql

Alternative if psql is not in PATH, or you prefer not to add it (using PowerShell syntax):
> cd "C:\Users\YourName\Datasets\vehicle-risk-profiling"
> & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d vehicle_risk_profiling -f "sql/01_raw/06_ingest_raw_casualties.sql"
--------------------------------------------------------------------------------
*/

\copy raw.casualties FROM 'data/raw/casualties_master.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '', QUOTE '"');