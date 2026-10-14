# 07 — Explain & measure: SQLite

> **Fixed question:** What does the engine say it did, and how long did it take?
>
> **Student artifact:** `driver.py` results, plan summaries, predictions, and answers

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

| Operation       | What happens                                                                   | Cost                                         |
| --------------- | ------------------------------------------------------------------------------ | -------------------------------------------- |
| **Seek**        | Descend the tree to one key                                                    | ~log(n): 3–4 page reads at 1M rows           |
| **Range walk**  | Seek, then step through the next *k* entries                                   | log(n) + k                                   |
| **Lookup**      | For each index entry, seek into the table by rowid for the other columns       | +1 seek **per row**, jumping around the file |
| **Full scan**   | Read every leaf of the table in order                                          | n (each row cheap, but all of them)          |
| **Temp B-tree** | Sort rows that no index delivers in order (`ORDER BY`, `GROUP BY`, `DISTINCT`) | n·log(n) on the rows fed in                  |

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

| Plan says                                            | Plain English                                                             | Grows with                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------ |
| `SEARCH t USING INTEGER PRIMARY KEY (rowid=?)`       | jump straight to one row                                                  | nothing                        |
| `SEARCH t USING INDEX i (col=?)`                     | seek/range on an index, **then a table lookup per match**                 | matching rows                  |
| `SEARCH t USING COVERING INDEX i (…)`                | seek/range on an index, no lookups                                        | matching rows                  |
| `SCAN t`                                             | read **every row** of the table                                           | **the table**                  |
| `SCAN t USING INDEX i`                               | walk the *whole* index, with a lookup per row                             | **the table**, with random I/O |
| `SCAN t USING COVERING INDEX i`                      | walk the whole index, no lookups                                          | **the table**, fewer pages     |
| `USE TEMP B-TREE FOR ORDER BY / GROUP BY / DISTINCT` | sort everything that reached this point                                   | rows fed in (n·log n)          |
| `CORRELATED SCALAR SUBQUERY n`                       | run the subquery **once per outer row**                                   | outer rows × subquery cost     |
| `CO-ROUTINE x`                                       | a subquery/CTE streamed into its parent                                   | —                              |
| `MATERIALIZE x`                                      | a subquery/CTE computed once into a temp table                            | its size                       |
| `AUTOMATIC COVERING INDEX`                           | SQLite built a throwaway index for this query: a hint you want a real one | —                              |

**Red flags:** a `SCAN` of a big table, a `TEMP B-TREE` fed by a big table,
`SCAN … USING INDEX` (a whole-index walk with lookups), or a `CORRELATED`
subquery under a big outer loop. An endpoint with any of these gets slower as
the data grows.

### Three questions the plans answer

One worked example, then two for you.

1. **Can the planner choose badly?** Yes. Revenue per department for one
   month walked the *entire* department index (327 ms) to avoid a sort.
   Writing `GROUP BY +department` (the unary `+` disables that index) let it
   use the date index instead: 29 ms, 11× faster. Other levers are
   `INDEXED BY`, `NOT INDEXED`, and keeping statistics fresh with `ANALYZE`.
2. **Does `LIMIT` save you from a scan?** Q10 answers this. Its plan, and its
   time at three sizes, tell you whether asking for 10 rows means reading 10.
3. **Can an index make a query slower?** Q09's experiment and Q14's two
   columns answer this. Explain *why* using the costs in §1.

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

### Predict before you run the driver

Fill in the middle column **before** your first full driver run, then the
last column after. A wrong prediction you can explain is worth more than a
right one you can't.

| Queries                   | Your prediction: how much faster is `idx_*` than `noidx_*` at 1m? | What happened (cite a number) |
| ------------------------- | ----------------------------------------------------------------- | ----------------------------- |
| Q01, Q02                  |                                                                   |                               |
| Q03, Q04, Q05, Q06, Q08   |                                                                   |                               |
| Q07, Q09, Q10             |                                                                   |                               |
| Q11–Q14, slow versions    |                                                                   |                               |
| Q11–Q14, `/fast` versions |                                                                   |                               |

### Rules of thumb for times

| Time       | Meaning                                             |
| ---------- | --------------------------------------------------- |
| under 1 ms | the database barely did anything                    |
| 1–50 ms    | real work, but a user wouldn't notice               |
| 100 ms +   | a user notices if a page makes a few of these calls |
| 1,000 ms + | a user notices on a single call                     |

---

## 4. Diagnosing a slow query

1. **Get the plan.**
2. **Find the line that grows with the table** (see the red flags above).
3. **Measure at two sizes** (100k and 1M). Flat means the cost follows the
   result. ~10× means linear in the table. More than 10× means a sort is involved.
4. **Pick a fix category:**

   | Fix                                                    | Examples                                                                          |
   | ------------------------------------------------------ | --------------------------------------------------------------------------------- |
   | **Index**: make the access a seek or a covering walk   | composite index for a probe, covering index for a report                          |
   | **Rewrite**: same answer, fewer rows touched           | keyset instead of `OFFSET`, `NOT EXISTS` instead of `NOT IN`                      |
   | **Precompute**: pay at write time instead of read time | summary table, counter table, FTS5 index                                          |
   | **Change the contract**: answer a cheaper question     | "1,000+" instead of an exact count; next page only                                |
   | **Accept it**                                          | some reports are inherently O(table): cache them or run them off the request path |

5. **Write it up** in four parts: *what* the plan does, *why* that's the plan,
   *the evidence* (plan lines + times at two sizes), and *the fix* along with
   its cost.

## Your artifact

1. `results.md` from a full driver run.
2. A plan summary for each query: the one or two plan lines that explain its
   time. Describe *how SQLite runs it*, not what the query does.
3. Your completed prediction table from §3.
4. An answer to each query's **Think about it** prompt in
   [06_queries/](../06_queries/README.md), and to questions 2 and 3 in §2.
   Each answer cites a number or a plan line.
