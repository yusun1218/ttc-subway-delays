-- 09_export_for_tableau.sql
-- Export the clean table and the commuter-risk summary as CSV files for Tableau.
-- Run from the project folder:  psql -d ttc -f sql/09_export_for_tableau.sql

-- Commuter risk (same logic as Q4 in 08_analysis.sql), saved as a view so it can be exported
CREATE OR REPLACE VIEW analytics.commuter_risk AS
WITH weekdays AS (
    SELECT day::date AS day
    FROM generate_series('2023-01-01'::date, '2026-08-31'::date, interval '1 day') AS day
    WHERE EXTRACT(ISODOW FROM day) < 6
),
windows (time_window, start_hour, end_hour) AS (
    VALUES ('1. AM peak (7-10)', 7, 10),
           ('2. Midday (10-15)', 10, 15),
           ('3. PM peak (15-19)', 15, 19),
           ('4. Evening (19-24)', 19, 24)
),
lines (line) AS (
    VALUES ('Line 1'), ('Line 2'), ('Line 4')
),
long_delay_days AS (
    SELECT DISTINCT d.delay_date, d.line, w.time_window
    FROM analytics.delays AS d
    JOIN windows AS w
      ON d.hour >= w.start_hour AND d.hour < w.end_hour
    WHERE d.min_delay >= 10
      AND NOT d.is_weekend
)
SELECT
    l.line,
    w.time_window,
    COUNT(*)                                          AS weekdays,
    COUNT(ld.delay_date)                              AS weekdays_with_long_delay,
    ROUND(100.0 * COUNT(ld.delay_date) / COUNT(*), 1) AS pct_of_weekdays_with_long_delay
FROM weekdays
CROSS JOIN lines AS l
CROSS JOIN windows AS w
LEFT JOIN long_delay_days AS ld
  ON ld.delay_date = weekdays.day
 AND ld.line = l.line
 AND ld.time_window = w.time_window
GROUP BY l.line, w.time_window;

-- \copy can't read a view directly, so wrap it in a SELECT.
-- Booleans are written as true/false (PostgreSQL's default t/f isn't recognised by Tableau).
\copy (SELECT delay_id, delay_date, delay_time, year, month, hour, day_of_week, is_weekend::text AS is_weekend, line, station, location_type, bound, code, code_description, cause_group, min_delay, min_gap, caused_delay::text AS caused_delay, vehicle, station_raw, line_raw, source_file FROM analytics.delays ORDER BY delay_id) TO 'data/tableau/ttc_subway_delays_clean.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM analytics.commuter_risk ORDER BY line, time_window) TO 'data/tableau/commuter_risk.csv' WITH (FORMAT csv, HEADER true)
