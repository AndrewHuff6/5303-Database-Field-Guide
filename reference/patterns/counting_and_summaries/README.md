# Counting and Summaries

> **Queries:** Q05, Q13
>
> **The idea:** Why `COUNT(*)` isn't free, and keeping precomputed summaries fresh

## The problem (engine-neutral)

"How many purchases are there?" sounds like the database should just know.
Most don't. A count is computed by **walking** something: the table, or an
index with one entry per row. The bigger the table, the longer the walk.

That bites hardest in a common API shape: **a page of results plus a
total**.

```
GET /purchases?page=1   →   { "rows": [ … 50 rows … ], "total": 412,903 }
```

The page **stops early**: once 50 matching rows are found, it's done. The
total **never stops early**: it must find every match. Adding `total` can
make an endpoint many times slower, and the gap grows with the table.

Every summary, a count, a sum per month, revenue per state, has the same
shape: either **compute it when asked** (always correct, costs a full pass)
or **compute it ahead of time** (instant, but stale until refreshed).

### Cheaper answers, from exact to approximate

| Technique                                                        | Read cost        | Trade-off                                                                |
| :--------------------------------------------------------------- | :--------------- | :----------------------------------------------------------------------- |
| **Summary or counter table, kept by triggers**                   | instant          | Every write also updates the summary: more work and contention per write |
| **Summary table, rebuilt on a schedule**                         | instant          | Stale between rebuilds                                                   |
| **Capped count**: `SELECT count(*) FROM (SELECT 1 … LIMIT 1001)` | stops at 1,001   | The UI shows "1,000+"                                                    |
| **Has-more**: fetch `LIMIT n+1` rows                             | same as the page | No total at all, just "next →"                                           |
| **Planner estimate** (the statistics the optimizer keeps)        | instant          | Approximate, and whole-table only                                        |
| **Cache the total** in the application, with an expiry           | instant, mostly  | Can be wrong for a while after writes                                    |

Which one is right is a **product** question: does anyone actually need the
exact number, right now?

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). These numbers are from
`idx_1m`. SQLite stores no row count, so every `count(*)` walks something:

| Query                                       | Plan                                                                                            |  Time |
| :------------------------------------------ | :---------------------------------------------------------------------------------------------- | ----: |
| `count(*) FROM purchases`                   | `SCAN … USING COVERING INDEX idx_purchases_product`: the smallest B-tree with one entry per row |  7 ms |
| `count(*) WHERE department = 'Books'`       | `SEARCH … COVERING INDEX (department=?)`: only the matching range                               |  1 ms |
| `count(*) WHERE amount BETWEEN 100 AND 200` | `SCAN purchases`                                                                                | 34 ms |
| …a *page* of those same rows (`LIMIT 5`)    | `SCAN`, stops after 5 hits                                                                      | <1 ms |

The last two rows are "page + total" in miniature.

SQLite has no stored procedures or materialized views, so keeping a summary
table fresh is up to triggers or a scheduled job. The handout
[triggers_and_procedures.md](../../../engines/01_sqlite/05_load/triggers_and_procedures.md)
builds all three approaches for `monthly_sales`, and what each costs a write.

## DuckDB

**Fit: ✓, and it changes the question.** Counting and summing whole columns
is what a column store is built for. It reads only the columns involved, in
compressed blocks, with every core. Many summaries that need a precomputed
table in SQLite are fast enough in DuckDB to compute on demand. Measure
before you build a summary table here.

## PostgreSQL

**Fit: ✓.** `count(*)` still scans. Because of MVCC, each row's visibility
depends on the transaction asking, so there's no single stored count.
Postgres does keep an **estimate** (`reltuples` in `pg_class`, and the
`rows=` figure in `EXPLAIN`), and offers **materialized views**: a saved query
result you refresh with `REFRESH MATERIALIZED VIEW` (add `CONCURRENTLY` to
keep it readable during the refresh).

## MongoDB

**Fit: ✓.** Two different calls: `countDocuments(filter)` is exact and walks
the matches, while `estimatedDocumentCount()` reads collection metadata and
is instant but approximate. For summaries, an aggregation pipeline can
`$merge` its results into a summary collection.

## Redis

**Fit: ✓, natively.** Counters are what Redis is for: `INCR`, `HINCRBY`, and
`HINCRBYFLOAT` update a total atomically in one step. **HyperLogLog**
(`PFADD`, `PFCOUNT`) counts *distinct* items, such as unique visitors, in
about 12 KB with roughly 1% error. The catch: Redis can't compute a count
from raw data you didn't count on the way in.

## In the catalog

**Q05** counts one department. **Q13** totals revenue by month, once by
reading every purchase and once from the `monthly_sales` summary table. Their
**Think about it** prompts ([q05.sql](../../../engines/01_sqlite/06_queries/q05.sql),
[q13.sql](../../../engines/01_sqlite/06_queries/q13.sql)) ask what the index
saves, and what the summary table gives up. Section 8's summary-table check
shows you.
