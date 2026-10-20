-- 02_combine.sql
-- Combine the three yearly tables into one table with proper data types
DROP SCHEMA IF EXISTS staging CASCADE;

CREATE SCHEMA staging;

CREATE TABLE staging.delays AS
SELECT
    '2023'              AS source_file,
    date::date          AS delay_date,
    time::time          AS delay_time,
    day                 AS day_of_week,
    station             AS station_raw,
    code,
    min_delay::integer  AS min_delay,
    min_gap::integer    AS min_gap,
    bound,
    line                AS line_raw,
    vehicle::integer    AS vehicle
FROM raw.delays_2023

UNION ALL

SELECT
    '2024'              AS source_file,
    date::date          AS delay_date,
    time::time          AS delay_time,
    day                 AS day_of_week,
    station             AS station_raw,
    code,
    min_delay::integer  AS min_delay,
    min_gap::integer    AS min_gap,
    bound,
    line                AS line_raw,
    vehicle::integer    AS vehicle
FROM raw.delays_2024

UNION ALL

SELECT
    'since_2025'        AS source_file,
    date::date          AS delay_date,
    time::time          AS delay_time,
    day                 AS day_of_week,
    station             AS station_raw,
    code,
    min_delay::integer  AS min_delay,
    min_gap::integer    AS min_gap,
    bound,
    line                AS line_raw,
    vehicle::integer    AS vehicle
FROM raw.delays_since_2025
;
