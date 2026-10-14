# Multi-CTE Reports

> **Queries:** Q14
>
> **The idea:** Multi-level aggregate reports built in readable stages

## The problem (engine-neutral)

A real report is several questions stacked: "revenue by state, department,
and month, only for groups with at least 10 purchases, plus each
department's total." Written as one query, it's unreadable. Written as
**stages**, each a named CTE (`WITH name AS (…)`), it reads top to bottom:

```sql
WITH base AS (          -- 1. pick and join the raw rows
    SELECT ... FROM purchases JOIN ... WHERE purchase_date >= :start
),
grouped AS (            -- 2. aggregate at the finest grain
    SELECT state_code, department, month, count(*) AS n, sum(amount) AS revenue
    FROM base GROUP BY state_code, department, month
)
SELECT * FROM grouped   -- 3. filter and present
WHERE n >= :min_purchases
ORDER BY revenue DESC;
```

### `WHERE` vs. `HAVING`, stage by stage

| Clause                       | Filters                     | When                    |
| ---------------------------- | --------------------------- | ----------------------- |
| `WHERE` in the base stage    | raw rows                    | before any grouping     |
| `HAVING` on a `GROUP BY`     | groups                      | after aggregating       |
| `WHERE` on an earlier CTE    | rows that stage produced    | any time later          |

`HAVING` never reduces the rows that had to be **read**. Only a `WHERE` on
the raw rows does. Put every row filter as early as it can go.

### The question to ask of any report

> **How many times does it read the big table?**

A CTE **names** a step. It doesn't make anything faster by itself. Two CTEs
that each read `purchases` means two full passes. Often the second level can
be computed from the first stage's *small* result instead, with a window
function or a second `GROUP BY` over a few hundred rows rather than a
million.

### Subtotals: `ROLLUP` and `CUBE`

"Totals per department *and* a grand total" is a **rollup**. "Totals for
every combination of state and department, including all states and all
departments" is a **cube**. Some engines have `GROUP BY ROLLUP(…)` and
`CUBE(…)`; in the others, you `UNION ALL` several groupings, ideally all
built from one fine-grained stage.

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). These numbers are from
`idx_1m`.

- **Count the passes.** Revenue by (department, card type) *and* each
  department's total, written as two CTEs, shows two scans in the plan
  (1,366 ms). Computing the department total from the first CTE's small
  result with `sum(revenue) OVER (PARTITION BY department)` needs one pass
  (1,021 ms). The saving is the whole second pass, and it grows with the
  table.
- **Inlined vs. materialized.** SQLite may inline a CTE into the query that
  uses it (`CO-ROUTINE`) or compute it once into a temp table
  (`MATERIALIZE`). A CTE used more than once is normally materialized. Force
  either with `AS MATERIALIZED (…)` or `AS NOT MATERIALIZED (…)`.
- **No `ROLLUP` or `CUBE`.** Build subtotals as `UNION ALL`s from **one
  materialized fine-grained CTE** (department × year: 66 rows), not by
  re-reading 1M rows per level.
- **Make the unavoidable pass cheap.** Revenue per department: 241 ms as a
  plain scan with a sort, versus **35 ms** with a covering index
  `(department, amount)` that's already in `GROUP BY` order.

Look at the plans in the script. Nearly every one says `SCAN pu USING INDEX
idx_purchases_department`: walking a non-covering index (see
[window_ranking](../window_ranking/README.md#sqlite)). As an exercise, rerun
them with `+pu.department` in the `GROUP BY`, or `NOT INDEXED`, and compare.

## DuckDB

**Fit: ✓, its home ground.** `GROUP BY CUBE (…)`, `ROLLUP (…)`, and
`GROUPING SETS (…)` are built in, and multi-level aggregation over millions
of rows is what a parallel column store is for. `GROUP BY ALL` groups by
every non-aggregated column, which keeps long reports short.

## PostgreSQL

**Fit: ✓.** `ROLLUP`, `CUBE`, and `GROUPING SETS` are built in;
`GROUPING(col)` tells a subtotal row from a detail row. Since version 12,
CTEs are inlined unless you write `AS MATERIALIZED`.

## MongoDB

**Fit: ~.** An aggregation pipeline *is* a sequence of stages: `$match`
(`WHERE`), `$group`, `$match` again (`HAVING`), `$sort`. `$facet` runs
several groupings over one input in one pass. It works well; it's just a
different notation.

## Redis

**Fit: ✗** for ad hoc reports. There's no `GROUP BY` over stored data. You'd
precompute every cell you'll ever ask for on write
(`HINCRBYFLOAT revenue:TX:Books:2026-03 total 9.99`), which works for a fixed
dashboard and fails the moment someone asks a new question.

## In the catalog

**Q14** is a three-level report (state × department × month) with a
threshold, once from the raw purchases and once from the `monthly_sales`
summary table. Its **Think about it** prompt in
[q14.sql](../../../engines/01_sqlite/06_queries/q14.sql) asks you to compare it in
`idx_*` and `noidx_*`. The examples above group differently on purpose; the
question to ask transfers directly.
