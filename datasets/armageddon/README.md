# Armageddon Dataset

Earthquakes, airports, UFO sightings, meteorites, volcanoes, country and county
outlines, and more: 20 files of real-world geographic data. Used by the
[spatial track](../../tracks/spatial/).

Each file is stored as its own `.zip` so the repo stays small. The data inside
is GeoJSON (points, lines, polygons with properties) or, for two files, plain
JSON.

## The files

| File | Rows | Geometry | Sample properties |
| ---- | ---: | -------- | ----------------- |
| `usa-border_crossings` | 171 | Point | port, state, year, counts of trucks, trains, buses, pedestrians |
| `usa-country_outline` | 326 | LineString | state FIPS codes on each side |
| `usa-state_capitals` | 50 | Point | state, name |
| `usa-state_counties` | 3,220 | Polygon / MultiPolygon | state and county FIPS, `GEOID`, name |
| `usa-us_military_bases` | 824 | Polygon / MultiPolygon | site name, state, operational status, joint base |
| `usa-world_military_bases` | 331 | Point | country, name, notes |
| `world-airports` | 29,304 | Point | ICAO, IATA, name, city, country |
| `world-cities` | 10 | Point | city name, country code, time zone |
| `world-country_capitals` | 241 | Point | country, city, ISO codes |
| `world-country_codes` | 217 | none | country, region, name |
| `world-country_indicators` | 5,899 | none | country, year, GDP, corruption index, homicide rate, ... |
| `world-country_outline` | 255 | Polygon / MultiPolygon | name, ISO A3 |
| `world-country_outline2` | 245 | Polygon / MultiPolygon | ISO 2-letter code |
| `world-earthquakes` | 23,119 | Point | date, depth, magnitude |
| `world-meteorites` | 32,187 | Point | name, class, mass, fell or found |
| `world-pirate_attacks` | 7,510 | Point | date, attack type, nearest country |
| `world-railroads_10m` | 25,413 | LineString | track count, electrified, category |
| `world-shipping_lanes` | 3 | MultiLineString | lane type |
| `world-ufos` | 87,184 | Point | date, city, state, country, shape, duration |
| `world-volcanos` | 1,546 | Point | name, country, region, explosivity index, hazard and risk ratings |

All coordinates are longitude/latitude (SRID 4326).

## Load it into PostGIS

[load_postgis.py](load_postgis.py) reads every `.zip` directly, so there's
nothing to unzip first. It creates one table per file
(`world-earthquakes.zip` → `world_earthquakes`), each with a `gid` key, one
column per property in `snake_case`, a `geom` column, and a spatial (GiST)
index. You need a running PostGIS server first: see
[setup/docker.md](../../setup/docker.md).

```bash
cd datasets/armageddon
pip install "psycopg[binary]"
python load_postgis.py                      # all 20 files, ~10 s
python load_postgis.py world-ufos           # just one
python load_postgis.py --dsn postgresql://student:student@localhost:5433/course
```

The connection comes from `--dsn`, then `$DATABASE_URL`, then the course
default `postgresql://student:student@localhost:5432/course`. Re-running is
safe: each table is dropped and recreated.

**These are staging tables.** Values load as-is: dates stay text
(`'10/10/1949 21:00'`), missing values stay `'NA'`, and so on. Cleaning the
types and designing the real schema is part of the work. The loader also
reports polygons PostGIS considers invalid (`usa_us_military_bases` and
`world_country_outline2` have a few); `ST_MakeValid` repairs them.

## Unzip for other tools

To work with the files outside PostGIS (DuckDB's spatial extension, MongoDB,
a notebook), unzip them in place:

```bash
cd datasets/armageddon
python zip_manager.py unzip                 # restores world-ufos.geojson, ...
```

The unzipped files are git-ignored. `world-volcanos.geojson` has trailing
commas, which strict JSON parsers reject; `load_postgis.py` repairs them on
the fly, but other tools may need the same fix.

## For maintainers

- **To change a file:** unzip it, edit the `.geojson`/`.json`, then run
  `python zip_manager.py zip`. That rebuilds the zip and hides the original as
  a dot-file. Commit only the `.zip`.
- [json_to_geojson.py](json_to_geojson.py) converts a JSON or NDJSON file with
  latitude/longitude fields into GeoJSON. It's how several of these files
  were made; edit its `FIELD_MAPPINGS` for a new source.
- Ported from `5303-Adv-Database/Assignments/02_postgres_api/Armageddon_Data/`
  on 2026-10-14.
