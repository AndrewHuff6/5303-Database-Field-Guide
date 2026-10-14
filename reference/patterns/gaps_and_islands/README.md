# Gaps and Islands

> **Queries:** Q06
>
> **The idea:** Finding consecutive runs (streaks) and the breaks between them

## The problem (engine-neutral)

"Islands" are runs of consecutive values: days in a row, months in a row,
ids with no holes. "Gaps" are the holes between them. Streaks, outages,
sessions, and attendance runs are all this problem.

### The classic trick: value minus row number

```
n    row_number   n - row_number
1        1             0   ┐
2        2             0   ├ island "0"
3        3             0   ┘
7        4             3   ┐ island "3"
8        5             3   ┘
12       6             6   ┐
13       7             6   │ island "6"
14       8             6   │
15       9             6   ┘
```

Inside a run, the value and its row number both go up by 1, so **their
difference is constant**, and it changes at every gap. `GROUP BY` that
difference to get one row per island: `min` is the start, `max` the end, and
`count` the length.

Two preparation steps make or break it:

1. **One row per distinct value.** A customer who bought twice on the same
   day breaks the "+1 per row" arithmetic. Reduce to distinct days first.
2. **Make "consecutive" mean "+1".** Dates must become numbers: a day number,
   or `year*12 + month` for months.

### The `LAG` variant

Compare each row with the previous one: start a new island when
`value - lag(value) > 1`, then a running `sum()` of those "new island" flags
numbers the islands. Use it when "consecutive" is looser than +1, such as "no
more than 3 days apart."

### The pre-window way: a self-join

Before window functions, you found island starts by self-joining: "rows with
no row exactly one day before them." It works, and its cost grows with the
square of the rows per group. Window functions do it in one ordered pass.

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). These numbers are from
`idx_1m`.

`julianday()` turns an ISO date into a day number. For months, build
`year*12 + month`. Here are the consecutive months in which customer 54
bought something:

| first_month | last_month | months_in_a_row |
| :---------- | :--------- | --------------: |
| 2025-03     | 2026-02    |              12 |
| 2026-04     | 2026-08    |               5 |
| 2024-11     | 2025-01    |               3 |

**Why it scales badly:** for one customer it's an index `SEARCH` plus a few
tiny sorts (<1 ms). For **every** customer at once, it's a `DISTINCT` over 1M
rows, then a `PARTITION BY` sort, then three `GROUP BY`s: five temp B-trees
stacked over the whole table, **1.5 s**. Count the `TEMP B-TREE` lines in that
plan.

## DuckDB

**Fit: ✓.** Real date types: a date minus an integer is a date, so
`day - CAST(row_number() OVER (ORDER BY day) AS INTEGER)` gives the island key
directly, with no conversion to numbers. Whole-table versions (every customer at once) are
where a column store's parallel sorts pay off.

## PostgreSQL

**Fit: ✓.** `date - integer` is a date, so
`day - (row_number() OVER (ORDER BY day))::int` is the island key. `LAG`,
`LEAD`, and `generate_series` (for listing the gap days themselves) are all
built in.

## MongoDB

**Fit: ~.** `$setWindowFields` provides `$documentNumber` (row number) and
`$shift` (like `LAG`), so both variants are possible in an aggregation
pipeline. They're longer and harder to read than the SQL.

## Redis

**Fit: ~.** A **bitmap** per customer, one bit per day (`SETBIT
active:7 <day number> 1`), stores activity compactly, and `BITPOS` finds the
next set or clear bit. Finding every run is a loop in your program, not a
query.

## In the catalog

**Q06** finds one customer's purchase streaks in days. Its **Think about it**
prompt in [q06.sql](../../../engines/01_sqlite/06_queries/q06.sql) asks you to
work the trick by hand, then find which step is expensive. The example above
uses months on purpose: the method transfers, the answer doesn't.
