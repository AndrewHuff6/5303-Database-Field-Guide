# 07 — Explain & measure: SQLite

> **Fixed question:** What does the engine say it did, and how long did it take?
>
> **Student artifact:** Plan decoder + `driver.py` results

This section climbs the [measurement ladder](../../../lab/measurement_ladder.md):
**look** (right rows?), **ask** (what's the plan?), **time** (how long, at
three sizes, with and without indexes?). The fourth rung, **stress**, is
[§8](../08_concurrency/).

---

## 1. How SQLite finds rows

Everything in a SQLite file is a **B-tree**: a sorted, balanced tree of pages.

- **A table** is a B-tree keyed by its `rowid`. An `INTEGER PRIMARY KEY` such
  as `purchase_id` *is* the rowid, and the leaves hold the full rows.
- **An index** is a *separate* B-tree keyed by the indexed columns, and every
  entry **ends with the rowid** of its row.

```
idx_purchases_date                         purchases (table B-tree)
┌───────────────────────────┐              ┌─────────────────────────────────┐
│ ('2026-08-01', 3004)      │──rowid──►    │ 3004 │ cust │ card │ prod │ ... │
│ ('2026-08-01', 7719)      │──rowid──►    │ 7719 │ ...                      │
│ ('2026-08-02', 1122)      │   ...        │ ...                             │
└───────────────────────────┘              └─────────────────────────────────┘
```

Every plan is a combination of five costs:

| Operation | What happens | Cost |
| --------- | ------------ | ---- |
| **Seek** | Descend the tree to one key | ~log(n): 3–4 page reads at 1M rows |
| **Range walk** | Seek, then step through the next *k* entries | log(n) + k |
| **Lookup** | For each index entry, seek into the table by rowid for the other columns | +1 seek **per row**, jumping around the file |
| **Full scan** | Read every leaf of the table in order | n (each row cheap, but all of them) |
| **Temp B-tree** | Sort rows that no index delivers in order (`ORDER BY`, `GROUP BY`, `DISTINCT`) | n·log(n) on the rows fed in |

### Covering indexes

A **covering index** contains every column the query needs, so the lookup step
disappears: SQLite answers from the index alone and never opens the table.

- **The rowid comes free.** Every index entry already ends with it.
- **Column order matters.** Put `=` columns first, then the column you range
  over or sort by, then columns you only *read*.
- **It isn't free.** Every `INSERT`, `UPDATE`, and `DELETE` maintains one more
  B-tree. Build covering indexes for the queries that matter.

---

## 2. Reading `EXPLAIN QUERY PLAN`: the SQLite plan decoder

```
sqlite> .eqp on          -- print the plan before every query
sqlite> .timer on        -- print how long each one took
```

| Plan says | Plain English | Grows with |
| --------- | ------------- | ---------- |
| `SEARCH t USING INTEGER PRIMARY KEY (rowid=?)` | jump straight to one row | nothing |
| `SEARCH t USING INDEX i (col=?)` | seek/range on an index, **then a table lookup per match** | matching rows |
| `SEARCH t USING COVERING INDEX i (…)` | seek/range on an index, no lookups | matching rows |
| `SCAN t` | read **every row** of the table | **the table** |
| `SCAN t USING INDEX i` | walk the *whole* index, with a lookup per row | **the table**, with random I/O |
| `SCAN t USING COVERING INDEX i` | walk the whole index, no lookups | **the table**, fewer pages |
| `USE TEMP B-TREE FOR ORDER BY / GROUP BY / DISTINCT` | sort everything that reached this point | rows fed in (n·log n) |
| `CORRELATED SCALAR SUBQUERY n` | run the subquery **once per outer row** | outer rows × subquery cost |
| `CO-ROUTINE x` | a subquery/CTE streamed into its parent | — |
| `MATERIALIZE x` | a subquery/CTE computed once into a temp table | its size |
| `AUTOMATIC COVERING INDEX` | SQLite built a throwaway index for this query: a hint you want a real one | — |

**Red flags:** a `SCAN` of a big table, a `TEMP B-TREE` fed by a big table,
`SCAN … USING INDEX` (a whole-index walk with lookups), or a `CORRELATED`
subquery under a big outer loop. An endpoint with any of these gets slower as
the data grows.

### Three lessons the plans teach

1. **`LIMIT` doesn't save you from a scan.** `ORDER BY amount DESC LIMIT 5`
   still reads every row, because the top 5 aren't known until all rows are seen.
2. **The planner can choose badly.** Revenue per department for one month
   walked the *entire* department index (327 ms) to avoid a sort. Writing
   `GROUP BY +department` (the unary `+` disables that index) let it use the
   date index instead: 29 ms, 11× faster. Other levers are `INDEXED BY`,
   `NOT INDEXED`, and keeping statistics fresh with `ANALYZE`.
3. **An index can make a query slower.** When a query touches *every* row,
   walking a non-covering index turns one sequential scan into a million
   random lookups. In one measurement: 786 ms (index walk) vs. 231 ms (plain
   scan) vs. 36 ms (covering index). Q09 and Q14 show this.

---

## 3. Measuring

Timing goes through the measurement API: each route returns the
[result envelope](../../../lab/api/02_route_contract/) with `elapsed_ms` and
`plan`, and [driver.py](../../../lab/api/04_driver/) calls every route against
every database, keeps the **median of 5**, and writes `results.md` and
`results.csv`.

> **Timing gotcha:** Python's `cursor.execute()` returns when the *first* row
> is ready. Always time `execute()` **plus** `fetchall()`, or a slow query will
> look fast.

### What to expect (the shape of A01's results)

| Queries | `idx_*` vs `noidx_*` | Why |
| ------- | -------------------- | --- |
| Q01, Q02 | flat everywhere | primary-key access, or a scan that stops early |
| Q03, Q04, Q05, Q06, Q08 | **big** wins with indexes | touch a *few* rows: a seek beats a scan |
| Q07, Q09, Q10 | smaller wins (~2×) | must read every row in range anyway; a covering index only makes each read cheaper |
| Q11–Q14 slow versions | about the same either way; **Q14 slower with indexes** | no index fixes "read everything." The `/fast` rewrites stay flat as data grows. |

### Rules of thumb for times

| Time | Meaning |
| ---- | ------- |
| under 1 ms | the database barely did anything |
| 1–50 ms | real work, but a user wouldn't notice |
| 100 ms + | a user notices if a page makes a few of these calls |
| 1,000 ms + | a user notices on a single call |

---

## 4. Diagnosing a slow query

1. **Get the plan.**
2. **Find the line that grows with the table** (see the red flags above).
3. **Measure at two sizes** (100k and 1M). Flat means the cost follows the
   result. ~10× means linear in the table. More than 10× means a sort is involved.
4. **Pick a fix category:**

   | Fix | Examples |
   | --- | -------- |
   | **Index**: make the access a seek or a covering walk | composite index for a probe, covering index for a report |
   | **Rewrite**: same answer, fewer rows touched | keyset instead of `OFFSET`, `NOT EXISTS` instead of `NOT IN` |
   | **Precompute**: pay at write time instead of read time | summary table, counter table, FTS5 index |
   | **Change the contract**: answer a cheaper question | "1,000+" instead of an exact count; next page only |
   | **Accept it** | some reports are inherently O(table): cache them or run them off the request path |

5. **Write it up** in four parts: *what* the plan does, *why* that's the plan,
   *the evidence* (plan lines + times at two sizes), and *the fix* along with
   its cost.

## Your artifact

`results.md` from a full driver run, plus a plan summary for each query: the
one or two plan lines that explain its time. Describe *how SQLite runs it*,
not what the query does.
