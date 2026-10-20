-- 06_clean_station.sql
-- Match about 1,700 spellings of station names to the 75 official stations.
--
-- How it works:
--   1. Tidy each raw name: upper case, dots turned into spaces, extra spaces removed.
--   2. Set aside names that aren't a station at all: yards/carhouses and whole-line entries.
--   3. Build matching patterns: one per official station (UPPER(station) || '%'),
--      plus a short list of exceptions for spellings the automatic pattern can't catch.
--   4. A name can match more than one pattern (LAWRENCE EAST matches LAWRENCE% too),
--      so keep the longest, most specific match.
-- Matching runs on the distinct names (~1,700) instead of all 94,802 rows, then joins back.

DROP TABLE IF EXISTS staging.station_map;

CREATE TABLE staging.station_map AS
WITH names AS (
    SELECT DISTINCT
        station_raw,
        TRIM(REGEXP_REPLACE(REPLACE(UPPER(station_raw), '.', ' '), '\s+', ' ', 'g')) AS name
    FROM staging.delays_clean
),

-- one automatic pattern per official station, plus hand-written exceptions
patterns AS (
    SELECT station, UPPER(station) || '%' AS pattern
    FROM reference.stations

    UNION ALL

    SELECT station, pattern
    FROM (VALUES
        -- interchange stations recorded under one line's name
        ('Bloor-Yonge',     'BLOOR STATION%'),
        ('Bloor-Yonge',     'BLOOR TO %'),
        ('Bloor-Yonge',     'BLOOR YONGE%'),
        ('Bloor-Yonge',     'YONGE BD%'),
        ('Bloor-Yonge',     'YONGE STATION%'),
        ('Bloor-Yonge',     'YONGE AND BLOOR%'),
        ('Bloor-Yonge',     'YONGE-BLOOR%'),
        ('Sheppard-Yonge',  'SHEPPARD%'),
        ('Sheppard-Yonge',  'YONGE SHP%'),
        ('Sheppard-Yonge',  'YONGE SHEPPARD%'),
        ('Sheppard-Yonge',  'YONGE-SHEPPARD%'),
        -- renamed stations: old names still appear in the data
        ('TMU',             'DUNDAS STATION%'),
        ('TMU',             'DUNDAS TO %'),
        ('Cedarvale',       'EGLINTON WEST%'),
        -- abbreviations and spellings the automatic pattern misses
        ('Vaughan Metropolitan Centre', 'VMC%'),
        ('Vaughan Metropolitan Centre', 'VAUGHAN%'),
        ('Scarborough Centre', 'SCARBOROUGH CTR%'),
        ('Scarborough Centre', 'SCARBOROUGH CENTER%'),
        ('North York Centre',  'NORTH YORK%'),
        ('Downsview Park',     'DOWNSVIEW%'),
        ('Queen''s Park',      'QUEENS PARK%'),
        ('Main Street',        'MAIN STATION%'),
        ('Main Street',        'MAIN ST%')
    ) AS exceptions (station, pattern)
),

matches AS (
    SELECT
        n.station_raw,
        p.station,
        ROW_NUMBER() OVER (
            PARTITION BY n.station_raw
            ORDER BY LENGTH(p.pattern) DESC
        ) AS row_num
    FROM names AS n
    JOIN patterns AS p
      ON n.name LIKE p.pattern
)

SELECT
    n.station_raw,
    CASE
        WHEN n.name ~ '(YARD|CARHOUSE|HOSTLER|BUILD ?-?UP|WYE|PORTAL|SHOP)' THEN NULL
        WHEN n.name ~ '^(LINE [1-4]|YONGE[- ]UNIVERSITY|BLOOR[- ]DANFORTH|SCARBOROUGH RAPID|TORONTO TRANSIT|TRANSIT CONTROL|SUBWAY|SYSTEM)' THEN NULL
        ELSE m.station
    END AS station,
    CASE
        WHEN n.name ~ '(YARD|CARHOUSE|HOSTLER|BUILD ?-?UP|WYE|PORTAL|SHOP)' THEN 'Yard / carhouse'
        WHEN n.name ~ '^(LINE [1-4]|YONGE[- ]UNIVERSITY|BLOOR[- ]DANFORTH|SCARBOROUGH RAPID|TORONTO TRANSIT|TRANSIT CONTROL|SUBWAY|SYSTEM)' THEN 'Whole line / system'
        WHEN m.station IS NOT NULL THEN 'Station'
        ELSE 'Unmatched'
    END AS location_type
FROM names AS n
LEFT JOIN matches AS m
  ON m.station_raw = n.station_raw
 AND m.row_num = 1;


-- add the clean station to every delay record
DROP TABLE IF EXISTS staging.delays_with_station;

CREATE TABLE staging.delays_with_station AS
SELECT
    d.*,
    sm.station,
    sm.location_type
FROM staging.delays_clean AS d
LEFT JOIN staging.station_map AS sm
  ON sm.station_raw = d.station_raw;


-- check: row count must not change, and how much was matched
SELECT
    location_type,
    COUNT(*)                                         AS delay_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_rows,
    SUM(min_delay)                                   AS total_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (), 1) AS pct_of_minutes
FROM staging.delays_with_station
GROUP BY location_type
ORDER BY delay_count DESC;
