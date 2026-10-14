# 06 — Run the query catalog: SQLite

> **Fixed question:** Translate Q01–Q15, or say why one can't or shouldn't be translated.
>
> **Student artifact:** Your three routes (Q03, Q08, Q15) passing their tests, and all 19 routes answering

Files: `qNN.sql` per query, `qNN_fast.sql` for rewrites. Routes follow the
[route contract](../../../lab/api/02_route_contract/).

SQLite is the reference implementation: the catalog was *written* in SQLite,
so every query is a natural fit (✓). Each file holds the SQL plus a header
with the route, the pattern, and **why it behaves the way it does**. Read the
"why" *after* you've run the query and looked at your own numbers.

## The catalog in SQLite

| ID | Query | Fit | Pattern | File(s) |
| -- | ----- | :-: | ------- | ------- |
| Q01 | One customer by id | ✓ | plan basics | [q01.sql](q01.sql) |
| Q02 | One page of products | ✓ | keyset_pagination | [q02.sql](q02.sql) |
| Q03 | Purchases in a date range | ✓ | plan basics | [q03.sql](q03.sql) |
| Q04 | A customer's purchase history | ✓ | plan basics | [q04.sql](q04.sql) |
| Q05 | Count purchases in one department | ✓ | counting_and_summaries | [q05.sql](q05.sql) |
| Q06 | A customer's purchase streaks | ✓ | gaps_and_islands | [q06.sql](q06.sql) |
| Q07 | 90-day spending leaderboard | ✓ | window_ranking | [q07.sql](q07.sql) |
| Q08 | Products never bought in a state | ✓ | anti_joins | [q08.sql](q08.sql) |
| Q09 | Revenue by state | ✓ | plan basics | [q09.sql](q09.sql) |
| Q10 | Top 10 products by revenue | ✓ | plan basics | [q10.sql](q10.sql) |
| Q11 | Deep pagination: OFFSET vs keyset | ✓ | keyset_pagination | [q11.sql](q11.sql) · [q11_fast.sql](q11_fast.sql) |
| Q12 | Random sample | ✓ | random_sampling | [q12.sql](q12.sql) · [q12_fast.sql](q12_fast.sql) |
| Q13 | Revenue by month: scan vs summary | ✓ | counting_and_summaries | [q13.sql](q13.sql) · [q13_fast.sql](q13_fast.sql) |
| Q14 | State × department × month report | ✓ | multi_cte_reports | [q14.sql](q14.sql) · [q14_fast.sql](q14_fast.sql) |
| Q15 | Insert a purchase | ✓ | — ([§8](../08_concurrency/)) | [q15.sql](q15.sql) |

## SQLite-isms to watch for when you port these later

These are the spots where the SQL is SQLite-flavored. Each one gets
translated differently in the next units:

| Query | SQLite-ism | Why it's there |
| ----- | ---------- | -------------- |
| Q06 | `julianday(day) - ROW_NUMBER()` | No date type, so dates become day numbers for arithmetic |
| Q13, Q14 | `substr(purchase_date, 1, 7)` for the month | Dates are ISO text, so the month is a prefix |
| Q12 | `ORDER BY random()` | Same in Postgres; other engines have dedicated sampling |
| Q14 | Multi-CTE instead of `CUBE` / `GROUPING SETS` | SQLite has no `CUBE` |
| Q15 | `RETURNING` | SQLite 3.35+; Postgres has it too |
| all | `:name` placeholders | Python's `sqlite3` style; `psycopg` uses `%(name)s` |

## Running a query by hand

```bash
cd units/01_sqlite/05_load
sqlite3 store_classroom.db
```

```
sqlite> .param set :customer_id 7
sqlite> .read ../06_queries/q01.sql
```

`.param set` binds a `:name` placeholder in the shell. In QueryMux, paste the
SQL and replace each `:name` with a literal value.

## In the API

Each query is one route in
[lab/api/starter_code/app/main.py](../../../lab/api/starter_code/app/main.py),
following the [route contract](../../../lab/api/02_route_contract/). The route
doesn't hold the SQL: `run_query(db, "Q07", ...)` loads `q07.sql` from this
folder (see [03 experiment.py](../../../lab/api/03_experiment_py/)). Edit a
file here, and the API runs the edited query.

Sixteen routes are written for you. You write three: **Q03**, **Q08**, and
**Q15**. Each needs something the others don't: two date parameters, a
validated string, and a JSON body.

## Your artifact

1. Your three routes, with `pytest tests/test_your_routes.py` passing.
2. Every route answering in `/docs` against `idx_10k`, and every `/fast` route
   returning the same rows as its slow twin. Q12 is random, so it's the
   exception.
