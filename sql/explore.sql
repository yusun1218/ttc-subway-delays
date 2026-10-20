-- explore.sql
-- Exploratory queries I ran while cleaning the data. Not part of the pipeline;
-- run them one at a time inside psql to see what each step was based on.


-- Look at duplicate records before removing them (03_dedupe.sql)
WITH numbered AS (
    SELECT *,
    ROW_NUMBER() OVER (
        PARTITION BY delay_date, delay_time, day_of_week, station_raw, 
        code, min_delay, min_gap, bound, line_raw, vehicle
        ORDER BY source_file
    ) AS row_num
    FROM staging.delays
)  
SELECT delay_date, delay_time, station_raw, code, min_delay, row_num
FROM numbered
WHERE row_num > 1
ORDER BY delay_date, delay_time 
LIMIT 10;

-- What spellings does the line column have?
SELECT line_raw, COUNT(*) AS delay_count
FROM staging.delays_deduped
GROUP BY line_raw
ORDER BY delay_count DESC;

-- Same, with delay minutes: rows tagged with two lines turn out to have 0 minutes
SELECT line_raw,
       COUNT(*)       AS delay_count,
       SUM(min_delay) AS total_minutes,
       MAX(min_delay) AS longest_delay
FROM staging.delays_deduped
GROUP BY line_raw
ORDER BY delay_count DESC;

-- SRT (Line 3) closed in July 2023 - why are there later rows?
SELECT EXTRACT(YEAR FROM delay_date) AS year,
       COUNT(*)       AS delay_count,
       SUM(min_delay) AS total_minutes
FROM staging.delays_deduped
WHERE line_raw = 'SRT'
GROUP BY year
ORDER BY year;

-- Test the line mapping before saving it in 04_clean_line.sql
SELECT 
    CASE
        WHEN line_raw LIKE '%YU%BD%' OR line_raw LIKE '%BD%YU%' THEN 'Multiple lines'
        WHEN line_raw IN ('YU', 'YUS', 'LINE 1') THEN 'Line 1'
        WHEN line_raw IN ('BD', 'BD LINE 2') OR line_raw LIKE 'BLOOR DANFORTH%' OR line_raw LIKE 'LINE 2%' THEN 'Line 2'
        WHEN line_raw IN ('SRT') THEN ('Line 3')
        WHEN line_raw IN ('SHP', 'SHEP') THEN ('Line 4')
        ELSE 'Unknown'
    END AS line,
    COUNT(*)       AS delay_count,
    SUM(min_delay) AS total_minutes
FROM staging.delays_deduped
GROUP BY line
ORDER BY delay_count DESC;
