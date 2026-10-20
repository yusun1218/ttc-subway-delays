-- 04_clean_line.sql
-- Map ~50 spellings of the line column into four subway lines plus two extra groups

DROP TABLE IF EXISTS staging.delays_clean;

CREATE TABLE staging.delays_clean AS
SELECT
    *,
    CASE
        WHEN line_raw LIKE '%YU%BD%' OR line_raw LIKE '%BD%YU%' THEN 'Multiple lines'
        WHEN line_raw IN ('YU', 'YUS', 'LINE 1') THEN 'Line 1'
        WHEN line_raw IN ('BD', 'BD LINE 2') OR line_raw LIKE 'BLOOR DANFORTH%' OR line_raw LIKE 'LINE 2%' THEN 'Line 2'
        WHEN line_raw IN ('SRT') THEN ('Line 3')
        WHEN line_raw IN ('SHP', 'SHEP') THEN ('Line 4')
        ELSE 'Unknown'
    END AS line
FROM staging.delays_deduped;