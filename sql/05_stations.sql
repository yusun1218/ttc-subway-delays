-- 05_stations.sql
-- Official TTC station list, used to match the messy station names

DROP SCHEMA IF EXISTS reference CASCADE;
CREATE SCHEMA reference;

CREATE TABLE reference.stations (
    station text,
    lines   text
);

\copy reference.stations FROM 'data/reference/ttc_stations.csv' WITH (FORMAT csv, HEADER true)