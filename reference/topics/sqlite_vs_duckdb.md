# SQLite vs. DuckDB

Two embedded databases. Both are a library inside your program, both keep a
whole database in one file, and neither has a server, users, or a network
port. From the outside they look like the same tool.

They're opposites inside, and that's why DuckDB gets so much attention: the
same data and the same SQL can run **dramatically faster or slower** depending
on which one you pick. This page explains why, so that when you measure both
in [DuckDB 07](../../engines/02_duckdb/07_explain/README.md), you can predict the
results before you see them.

## The core difference

> **SQLite stores rows. DuckDB stores columns.**

```
SQLite: one row's values sit together
  [7 | 1 | 42 | Games | 9.99 | 2025-03-01] [8 | 3 | 17 | Books | 24.50 | 2025-03-01] ...

DuckDB: one column's values sit together, in blocks
  purchase_id:    7, 8, 9, 10, 11, ...
  department:     Games, Books, Games, Toys, Games, ...
  amount:         9.99, 24.50, 12.00, 5.25, 31.10, ...
```

Everything else follows from that layout and from what each engine was
built to do:

|                                        | SQLite                                                      | DuckDB                                                                                |
| -------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Built for**                          | many small reads and writes: one customer, one order (OLTP) | big questions over many rows: totals, trends, reports (OLAP)                          |
| **Reads, for a total over one column** | every whole row                                             | only that column                                                                      |
| **Runs a query on**                    | one CPU core, one row at a time                             | every core, a block of about 2,048 values at a time ("vectorized")                    |
| **Storage**                            | each value as written                                       | compressed per column: repeated and ordered values shrink a lot                       |
| **Finds rows with**                    | B-tree indexes; a missing index means a full scan           | per-block min/max values that skip whole blocks; indexes are optional and rarely used |
| **Writes**                             | small transactions are cheap; one writer at a time per file | bulk loads are fast; single-row inserts are slow; one writing **process** per file    |
| **Types**                              | loose by default (`STRICT` opt-in); no date type            | strict; real `DATE`, `TIMESTAMP`, `DECIMAL`, plus lists and structs                   |
| **Reads files directly**               | no: `.import` into a table first                            | yes: CSV, Parquet, JSON, and even SQLite files, in place                              |
| **Age and footprint**                  | since 2000; in every phone and browser                      | since 2019; stable file format since 1.0 (2024)                                       |

## Why a column store wins analytics

A report like "average amount by card type" touches every purchase but only
two of its columns. A column store gets four advantages at once:

1. **Less to read.** Two columns instead of every whole row.
2. **Less to read, again.** Those columns are compressed. A column of 22
   department names across a million rows becomes tiny codes.
3. **Faster to process.** Working on a block of values at a time keeps the
   CPU busy with simple loops instead of per-row bookkeeping.
4. **More hands.** The scan is split across every core.

## Why a row store wins lookups and small writes

"Show purchase 777,777" wants one whole row. SQLite descends a B-tree to it
in a few page reads. DuckDB has to gather that row's values from separate
columns, and it pays a fixed cost for planning and starting a parallel query,
which is noticeable when the actual work is tiny.

Writes are similar. SQLite appends one row to one place. DuckDB has to touch
every column's storage, and it's built to do that efficiently for thousands
of rows at once, not one.

## The same query, ported

Most of the catalog runs unchanged. The differences, from porting all 20
queries:

| What                  | SQLite                                                | DuckDB                                                               |
| --------------------- | ----------------------------------------------------- | -------------------------------------------------------------------- |
| Parameters            | `:name`                                               | `$name`                                                              |
| Dates                 | ISO text: `substr(purchase_date, 1, 7)` for the month | `DATE`: `strftime(purchase_date, '%Y-%m')`, `date_trunc('month', …)` |
| Date arithmetic       | `julianday(day) - …`                                  | `day - CAST(… AS INTEGER)`                                           |
| `GROUP BY`            | accepts a column that isn't grouped (picks a value)   | **rejects it**: every non-aggregated column must be grouped          |
| Filtering on a window | wrap it in a CTE                                      | `QUALIFY`                                                            |
| Subtotals             | `UNION ALL` of several groupings                      | `GROUP BY CUBE / ROLLUP / GROUPING SETS`                             |
| Anti-joins            | `NOT EXISTS`                                          | `NOT EXISTS`, or `ANTI JOIN` by name                                 |

The `GROUP BY` row matters beyond DuckDB. Q10 selects `product_name` while
grouping only by `product_id`. SQLite runs it, DuckDB refuses, and
PostgreSQL accepts it only because `product_id` is the primary key. Write the
strict form and it runs everywhere.

**Ties.** Comparing engines exposed queries whose `ORDER BY … LIMIT` could
keep either of two tied rows. Each engine was "right," but they disagreed.
Every catalog query now has a tiebreaker, so both engines return the same
rows.

## Try it: three side examples

These are **not** catalog queries. Your catalog numbers come in DuckDB 07.
Open both shells on the `1m` files:

```bash
sqlite3 ~/5303_data/sqlite/idx_1m.db           # or datasets/store/generated/sqlite/
duckdb -readonly ~/5303_data/duckdb/idx_1m.duckdb
```

Turn on timing in each (`.timer on`), and run each query **twice**. Use the
second time, since the first run loads data into memory.

**1. A whole-table report.**

```sql
SELECT cd.card_type, round(avg(pu.amount), 2) AS avg_amount, count(*) AS n
FROM purchases pu JOIN cards cd ON cd.card_id = pu.card_id
GROUP BY cd.card_type
ORDER BY avg_amount DESC;
```

**2. One row by its key.**

```sql
SELECT * FROM purchases WHERE purchase_id = 777777;
```

**3. The report again, in DuckDB, on one core.**

```sql
SET threads = 1;
-- now rerun query 1
```

**Predict before you run anything:**

- Query 1: which engine is faster, and by roughly how much: 2×, 10×, 100×?
- Query 2: which is faster, and does the gap matter for one request?
- Query 3: how much of DuckDB's advantage in query 1 came from using many
  cores? If it all did, one core should erase the gap with SQLite. Does it?

Then explain each result using the sections above.

## Choosing between them

Neither is "better." They're for different jobs, and many projects use both:
SQLite (or Postgres) for the application's live data, and DuckDB for the
reports run over a copy of it.

| Lean toward SQLite when…                   | Lean toward DuckDB when…                                         |
| ------------------------------------------ | ---------------------------------------------------------------- |
| the work is many small lookups and writes  | the work is scans, joins, and aggregates over many rows          |
| an app on a phone or desktop owns the data | an analyst or a notebook asks questions of the data              |
| writes trickle in one at a time            | data arrives in batches, or already sits in CSV or Parquet files |
| the footprint must be tiny                 | the machine has cores and memory to use                          |

[DuckDB 09](../../engines/02_duckdb/09_when/README.md) asks you to make these calls
for specific scenarios, citing your own numbers.

## See also

- [SQLite unit](../../engines/01_sqlite/README.md) · [DuckDB unit](../../engines/02_duckdb/README.md)
- [SQLite vs. PostgreSQL](sqlite_vs_postgres.md): the other comparison, row
  store against row store, library against server
- [Concept map](../concept_map.md): the SQLite and DuckDB columns, side by side
- Patterns where DuckDB has a built-in shortcut:
  [anti_joins](../patterns/anti_joins/README.md),
  [window_ranking](../patterns/window_ranking/README.md),
  [multi_cte_reports](../patterns/multi_cte_reports/README.md),
  [random_sampling](../patterns/random_sampling/README.md)


<img src="https://res.cloudinary.com/cqd6nje4/image/upload/v1791958431/row_vs_col_fhhw4l.png">s