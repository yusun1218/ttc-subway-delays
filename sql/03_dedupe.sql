-- 03_dedupe.sql
-- Remove exact duplicate records: rows that match on every field describing the incident.
-- 94,891 rows -> 94,802 (89 duplicates removed)

DROP TABLE IF EXISTS staging.delays_deduped;

CREATE TABLE staging.delays_deduped AS

WITH numbered AS (
    SELECT *,
    ROW_NUMBER() OVER (
        PARTITION BY delay_date, delay_time, day_of_week, station_raw, 
        code, min_delay, min_gap, bound, line_raw, vehicle
        ORDER BY source_file
    ) AS row_num
    FROM staging.delays
)  
SELECT
    source_file,
    delay_date,
    delay_time,
    day_of_week,
    station_raw,
    code,
    min_delay,
    min_gap,
    bound,
    line_raw,
    vehicle
FROM numbered
WHERE row_num = 1;
