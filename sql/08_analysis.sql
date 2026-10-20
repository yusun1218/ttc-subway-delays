-- 08_analysis.sql
-- Business questions answered from analytics.delays
-- Period: Jan 2023 to Aug 2026. "Delay" = an incident with min_delay > 0.
-- "Long delay" = 10 minutes or more.


-- Q1. How big is the problem overall?
-- Most logged incidents don't hold up a train, so count both.
SELECT
    COUNT(*)                                                       AS incidents_logged,
    COUNT(*) FILTER (WHERE caused_delay)                           AS incidents_with_delay,
    ROUND(100.0 * COUNT(*) FILTER (WHERE caused_delay) / COUNT(*), 1) AS pct_with_delay,
    ROUND(SUM(min_delay) / 60.0)                                   AS total_delay_hours,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY min_delay)
        FILTER (WHERE caused_delay)                                AS median_delay_min,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY min_delay)
        FILTER (WHERE caused_delay)                                AS p90_delay_min
FROM analytics.delays;


-- Q2. Is it getting better or worse?
-- 2026 only has data to August, so compare January-August of each year.
-- LAG() pulls the previous year's value onto the same row.
WITH yearly AS (
    SELECT
        year,
        COUNT(*) FILTER (WHERE caused_delay)   AS delays,
        COUNT(*) FILTER (WHERE min_delay >= 10) AS long_delays
    FROM analytics.delays
    WHERE month <= 8
    GROUP BY year
)
SELECT
    year,
    delays,
    ROUND(100.0 * (delays - LAG(delays) OVER (ORDER BY year))
          / LAG(delays) OVER (ORDER BY year), 1)            AS delays_change_pct,
    long_delays,
    ROUND(100.0 * (long_delays - LAG(long_delays) OVER (ORDER BY year))
          / LAG(long_delays) OVER (ORDER BY year), 1)       AS long_delays_change_pct
FROM yearly
ORDER BY year;


-- Q3. How do the lines compare?
-- Line 1 is much longer than Line 4, so also look at delays per station.
-- Line 3 closed in July 2023, so it is left out.
SELECT
    d.line,
    s.station_count,
    COUNT(*) FILTER (WHERE d.caused_delay)                        AS delays,
    ROUND(COUNT(*) FILTER (WHERE d.caused_delay)::numeric / s.station_count, 1) AS delays_per_station,
    COUNT(*) FILTER (WHERE d.min_delay >= 10)                     AS long_delays,
    ROUND(AVG(d.min_delay) FILTER (WHERE d.caused_delay), 1)      AS avg_delay_min
FROM analytics.delays AS d
JOIN (
    SELECT 'Line ' || n AS line, COUNT(*) AS station_count
    FROM reference.stations, unnest(ARRAY[1, 2, 4]) AS n
    WHERE lines LIKE '%Line ' || n || '%'
    GROUP BY n
) AS s ON s.line = d.line
GROUP BY d.line, s.station_count
ORDER BY d.line;


-- Q4. What are a commuter's odds of hitting a long delay?
-- For each weekday and time window: did the line have at least one 10+ minute delay?
-- Then the share of weekdays where that happened.
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
    ROUND(100.0 * COUNT(ld.delay_date) / COUNT(*), 1) AS pct_of_weekdays_with_long_delay
FROM weekdays
CROSS JOIN lines AS l
CROSS JOIN windows AS w
LEFT JOIN long_delay_days AS ld
  ON ld.delay_date = weekdays.day
 AND ld.line = l.line
 AND ld.time_window = w.time_window
GROUP BY l.line, w.time_window
ORDER BY l.line, w.time_window;


-- Q5. When in the day do long delays happen?
-- Long delays per hour of the day on weekdays (all lines).
SELECT
    hour,
    COUNT(*) FILTER (WHERE min_delay >= 10) AS long_delays
FROM analytics.delays
WHERE NOT is_weekend
  AND line LIKE 'Line%'
GROUP BY hour
ORDER BY hour;


-- Q6. Which stations account for the most delay?
-- RANK() orders the stations; the running SUM() shows how concentrated the problem is.
WITH by_station AS (
    SELECT
        station,
        COUNT(*) FILTER (WHERE caused_delay)    AS delays,
        COUNT(*) FILTER (WHERE min_delay >= 10) AS long_delays,
        SUM(min_delay)                          AS delay_minutes
    FROM analytics.delays
    WHERE location_type = 'Station'
    GROUP BY station
)
SELECT
    RANK() OVER (ORDER BY delay_minutes DESC) AS rank,
    station,
    delays,
    long_delays,
    delay_minutes,
    ROUND(100.0 * SUM(delay_minutes) OVER (ORDER BY delay_minutes DESC)
          / SUM(delay_minutes) OVER (), 1)    AS cumulative_pct_of_minutes
FROM by_station
ORDER BY rank
LIMIT 15;


-- Q7. What causes the delays: frequent short ones or rare long ones?
SELECT
    cause_group,
    COUNT(*) FILTER (WHERE caused_delay)                              AS delays,
    SUM(min_delay)                                                    AS delay_minutes,
    ROUND(100.0 * SUM(min_delay) / SUM(SUM(min_delay)) OVER (), 1)     AS pct_of_minutes,
    ROUND(AVG(min_delay) FILTER (WHERE caused_delay), 1)              AS avg_delay_min
FROM analytics.delays
WHERE cause_group <> 'Other'
GROUP BY cause_group
ORDER BY delay_minutes DESC;

SELECT
    code,
    code_description,
    COUNT(*)                                                    AS delays,
    SUM(min_delay)                                              AS delay_minutes,
    ROUND(AVG(min_delay), 1)                                    AS avg_delay_min
FROM analytics.delays
WHERE caused_delay
GROUP BY code, code_description
ORDER BY delay_minutes DESC
LIMIT 10;
