-- 07_codes_and_final_table.sql
-- 1. Build one code lookup from the new (2025+) and old (up to 2024) code tables
-- 2. Create the final, analysis-ready table: analytics.delays

-- ---------- 1. code lookup ----------
DROP TABLE IF EXISTS reference.delay_codes;

CREATE TABLE reference.delay_codes AS
WITH new_codes AS (
    SELECT
        code,
        -- the new file has broken characters (UTF-8 read as Latin-1): fix dashes and quotes
        REPLACE(REPLACE(REPLACE(description,
            E'â\u0080\u0093', '-'),
            E'â\u0080\u009c', '"'),
            E'â\u0080\u009d', '"') AS description
    FROM raw.codes_new
),
old_codes AS (
    SELECT code, UPPER(description) AS description
    FROM raw.codes_old
    WHERE code NOT IN (SELECT code FROM new_codes)   -- prefer the newer description
)
SELECT code, description FROM new_codes
UNION ALL
SELECT code, description FROM old_codes;


-- ---------- 2. final table ----------
DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;

CREATE TABLE analytics.delays AS
SELECT
    -- order by every column that identifies an incident, so the id is the same on every rebuild
    ROW_NUMBER() OVER (
        ORDER BY d.delay_date, d.delay_time, d.station_raw, d.code, d.min_delay,
                 d.min_gap, d.bound, d.line_raw, d.vehicle
    ) AS delay_id,
    d.delay_date,
    d.delay_time,
    EXTRACT(YEAR  FROM d.delay_date)::int    AS year,
    EXTRACT(MONTH FROM d.delay_date)::int    AS month,
    EXTRACT(HOUR  FROM d.delay_time)::int    AS hour,
    -- recompute the weekday from the date: the source labels 2026-04-26 (a Sunday) as Saturday
    TRIM(TO_CHAR(d.delay_date, 'Day'))       AS day_of_week,
    EXTRACT(ISODOW FROM d.delay_date) >= 6   AS is_weekend,
    d.line,
    d.station,
    d.location_type,
    d.bound,
    d.code,
    COALESCE(c.description, 'UNKNOWN CODE')  AS code_description,
    -- the first letter of the code is the TTC department responsible
    CASE LEFT(d.code, 1)
        WHEN 'E' THEN 'Train equipment'
        WHEN 'P' THEN 'Track, signals & power'
        WHEN 'T' THEN 'Operations & staff'
        WHEN 'S' THEN 'Security & passenger behaviour'
        WHEN 'M' THEN 'Customers, weather & other'
        ELSE 'Other'
    END                                      AS cause_group,
    d.min_delay,
    d.min_gap,
    d.min_delay > 0                          AS caused_delay,
    d.vehicle,
    d.station_raw,
    d.line_raw,
    d.source_file
FROM staging.delays_with_station AS d
LEFT JOIN reference.delay_codes AS c
  ON c.code = d.code;


-- ---------- checks ----------
SELECT COUNT(*) AS total_rows FROM analytics.delays;   -- should be 94,802

SELECT
    (code_description = 'UNKNOWN CODE') AS unknown_code,
    COUNT(*)       AS delay_count,
    SUM(min_delay) AS total_minutes
FROM analytics.delays
GROUP BY 1;
