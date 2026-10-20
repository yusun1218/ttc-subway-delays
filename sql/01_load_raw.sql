-- 01_load_raw.sql
-- Load the files exactly as downloaded. Every column is text so nothing gets
-- silently converted or dropped; cleaning happens in the next step.
-- Run from the project folder:  psql -d ttc -f sql/01_load_raw.sql

DROP SCHEMA IF EXISTS raw CASCADE;
CREATE SCHEMA raw;

-- 2023 and 2024 come as one Excel file per year (converted to CSV)
CREATE TABLE raw.delays_2023 (
    date text, time text, day text, station text, code text,
    min_delay text, min_gap text, bound text, line text, vehicle text
);
CREATE TABLE raw.delays_2024 (LIKE raw.delays_2023);

-- From 2025 the city publishes one file that keeps growing, with an extra _id column
CREATE TABLE raw.delays_since_2025 (
    _id text, date text, time text, day text, station text, code text,
    min_delay text, min_gap text, bound text, line text, vehicle text
);

-- Code lookup tables: the old one (used up to 2024) and the new one (2025+)
CREATE TABLE raw.codes_old (code text, description text, system text);
CREATE TABLE raw.codes_new (_id text, code text, description text);

\copy raw.delays_2023       FROM 'data/raw/ttc-subway-delay-2023.csv'            WITH (FORMAT csv, HEADER true)
\copy raw.delays_2024       FROM 'data/raw/ttc-subway-delay-2024.csv'            WITH (FORMAT csv, HEADER true)
\copy raw.delays_since_2025 FROM 'data/raw/ttc-subway-delay-data-since-2025.csv' WITH (FORMAT csv, HEADER true)
\copy raw.codes_old         FROM 'data/raw/ttc-subway-delay-codes-old.csv'       WITH (FORMAT csv, HEADER true)
\copy raw.codes_new         FROM 'data/raw/code-descriptions.csv'                WITH (FORMAT csv, HEADER true)

SELECT 'delays_2023' AS table_name, COUNT(*) AS row_count FROM raw.delays_2023
UNION ALL SELECT 'delays_2024', COUNT(*) FROM raw.delays_2024
UNION ALL SELECT 'delays_since_2025', COUNT(*) FROM raw.delays_since_2025
UNION ALL SELECT 'codes_old', COUNT(*) FROM raw.codes_old
UNION ALL SELECT 'codes_new', COUNT(*) FROM raw.codes_new;
