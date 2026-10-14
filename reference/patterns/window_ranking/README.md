# Window Ranking

> **Queries:** Q07
>
> **The idea:** Ranking and running totals over a sliding window

## The problem (engine-neutral)

`GROUP BY` collapses rows: one row per customer. A **window function**
computes a value for each row *from a set of related rows*, without
collapsing them. That's how you rank, number, compare to the previous row, or
keep a running total.

```
function(...) OVER ( PARTITION BY <restart for each group>
                     ORDER BY     <order within the group>
                     <frame>      <which rows around the current one> )
```

### Three ways to rank

|    v | `row_number()` | `rank()` | `dense_rank()` |
| ---: | -------------: | -------: | -------------: |
|   50 |              1 |        1 |              1 |
|   40 |              2 |        2 |              2 |
|   40 |              3 |        2 |              2 |
|   10 |              4 |        4 |              3 |

Pick based on what a tie should mean in your result.

### Two rules that trip people up

- **You can't filter on a window in the same query's `WHERE`.** `WHERE` runs
  before windows are computed. Wrap the query in a CTE or subquery and filter
  outside it (`WHERE rnk <= 10`).
- **Aggregate first, window second.** Rank products by revenue *after*
  `GROUP BY` has shrunk a million purchases to a few thousand product rows.
  The window's sort then runs over thousands of rows, not millions.

### Frames: `ROWS` vs. `RANGE`

The frame picks which rows around the current one feed the function:

```sql
-- running total: everything from the start of the partition to here
sum(amount) OVER (ORDER BY purchase_date, purchase_id
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)

-- trailing 30 DAYS ending at this row
sum(amount) OVER (ORDER BY julianday(purchase_date)
                  RANGE BETWEEN 29 PRECEDING AND CURRENT ROW)
```

- **`ROWS n PRECEDING`** counts *rows*: "the previous 29 purchases."
- **`RANGE n PRECEDING`** measures distance *in the ORDER BY value*:
  "purchases within 29 days."

### What a window costs

A window is only as cheap as the rows it must order. Over one customer's
purchases (an index seek, a few dozen rows), it's microseconds. Over the
whole table, it's a sort of the whole table.

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). These numbers are from
`idx_1m`.

`RANGE` needs a single **number** to measure distance, and SQLite stores
dates as text, so order by `julianday(purchase_date)`. Here's customer 1,
where the trailing 30-day sum resets whenever purchases are more than 29 days
apart:

| purchase_date | amount | running_total |                          spend_last_30_days |
| :------------ | -----: | ------------: | ------------------------------------------: |
| 2025-06-26    |  91.18 |        490.63 |                                       91.18 |
| 2025-07-23    | 399.76 |        890.39 | **490.94** ← 27 days after the previous row |
| 2025-12-05    | 109.11 |        999.50 |                                      109.11 |

Each customer's largest purchase, across the whole table, four ways:

| Version                                                                            | Plan highlights                                                                       |     Time |
| :--------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------ | -------: |
| `row_number() OVER (PARTITION BY customer_id ORDER BY amount DESC)`, then `rn = 1` | `SCAN … USING INDEX idx_purchases_customer` + `TEMP B-TREE FOR LAST TERM OF ORDER BY` | 1,175 ms |
| `GROUP BY customer_id` + `max(amount)`                                             | `SCAN … USING INDEX idx_purchases_customer` (no sort)                                 |   786 ms |
| Same, `FROM purchases NOT INDEXED`                                                 | `SCAN purchases` + `TEMP B-TREE FOR GROUP BY`                                         |   231 ms |
| Same, with index `(customer_id, amount)`                                           | `SCAN … USING COVERING INDEX`                                                         |    36 ms |

Three lessons in that table:

1. A window over the whole table sorts the whole table, and the time grows
   faster than the data.
2. **Walking a non-covering index in order is often slower than scanning and
   sorting.** A million random lookups lose to one sequential read plus an
   in-memory sort.
3. When a whole-table pass is unavoidable, a **covering index in the right
   order** removes both the lookups and the sort. It isn't free: every insert
   maintains one more B-tree.

## DuckDB

**Fit: ✓.** Full window support, plus **`QUALIFY`**, which filters on a
window result directly and removes the wrap-it-in-a-CTE step:

```sql
SELECT customer_id, amount
FROM purchases
QUALIFY row_number() OVER (PARTITION BY customer_id ORDER BY amount DESC) = 1;
```

Real date types mean `RANGE BETWEEN INTERVAL 29 DAYS PRECEDING AND CURRENT ROW`
works without converting to numbers.

## PostgreSQL

**Fit: ✓.** Full window support, including `RANGE` frames with intervals
(`RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW`). No `QUALIFY`,
so filtering on a rank still needs a CTE or subquery.

## MongoDB

**Fit: ~.** The `$setWindowFields` stage provides `$rank`, `$denseRank`,
`$documentNumber`, and running sums, with windows measured in documents or in
time (`range: [-29, 0], unit: "day"`). It works, and it's verbose.

## Redis

**Fit: ~.** A **sorted set** *is* a leaderboard. `ZINCRBY leaderboard 9.99
customer:7` on every purchase, then `ZREVRANGE leaderboard 0 9 WITHSCORES`
returns the top 10 instantly. The hard part is the sliding window: "the last
90 days" needs one sorted set per day, combined with `ZUNIONSTORE`, and
expired days dropped.

## In the catalog

**Q07** ranks customers by spend in a 90-day window. Its **Think about it**
prompt in [q07.sql](../../../engines/01_sqlite/06_queries/q07.sql) asks why the
index helps less here than elsewhere. The lessons above are your tools;
the answer comes from your own plans.
