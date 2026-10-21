-- =============================================================================
-- rebuild.sql  --  One command to recreate the classroom database from the CSV
-- =============================================================================
-- Usage (must be run from engines/01_sqlite/05_load/ so the relative paths
-- to the schema and the classroom CSV resolve):
--
--     cd engines/01_sqlite/05_load
--     rm -f store_classroom.db
--     sqlite3 store_classroom.db ".read rebuild.sql"
--
-- or from an interactive prompt:
--
--     sqlite3 store_classroom.db
--     sqlite> .read rebuild.sql
--
-- It is safe to re-run: schema.sql drops every object before creating it.
-- =============================================================================

-- Dot commands take the whole line: no trailing "-- comment" after them.
-- .bail on = stop at the first error instead of plowing ahead.
.bail on
.echo off

SELECT '== 1/2  creating schema ==' AS step;
.read ../04_model/schema.sql

SELECT '== 2/2  loading + normalizing data ==' AS step;
.read load_classroom.sql

-- ---- verification -----------------------------------------------------------
SELECT '== verification ==' AS step;

-- Foreign keys were declared with the FK pragma on; confirm nothing dangles.
PRAGMA foreign_key_check;

-- Round-trip check: the fact table must still hold every source row, and its
-- revenue total must match the raw file's.
SELECT
    (SELECT count(*) FROM purchases)                     AS purchase_rows,
    (SELECT round(sum(amount), 2) FROM purchases)        AS total_revenue,
    (SELECT count(DISTINCT customer_id) FROM purchases)  AS customers_with_purchases;

SELECT '== rebuild complete ==' AS step;
