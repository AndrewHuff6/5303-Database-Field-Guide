# Keyset Pagination

> **Queries:** Q11, Q02
>
> **The idea:** Paging deep into a result without paying for every skipped row

## The problem (engine-neutral)

`LIMIT 5 OFFSET 900000` sounds like "skip to row 900,000." It isn't. The
database still has to **produce** the first 900,000 rows, in order, before it
can throw them away. Page 1 is cheap; page 180,001 reads 900,000 rows to
return 5.

**Keyset (or "seek") pagination** asks a different question. Instead of "skip
*N* rows," it says "start **after this key**":

```sql
-- OFFSET: walk past N rows
SELECT ... ORDER BY purchase_id LIMIT 50 OFFSET :offset;

-- keyset: seek to the last key the client saw
SELECT ... WHERE purchase_id > :after_id ORDER BY purchase_id LIMIT 50;
```

Each response includes the last key on the page, and the client sends it back
to get the next page. The database **seeks** straight to that key, so every
page costs the same.

### When the sort column isn't unique

Sorting newest-first by date? Many purchases share a date, so a date-only
cursor skips or repeats rows at page boundaries. Add the primary key as a
tie-breaker and compare both together as a **row value**:

```sql
WHERE (purchase_date, purchase_id) < (:last_date, :last_id)
ORDER BY purchase_date DESC, purchase_id DESC
LIMIT 50;
```

### Stability when data changes

Suppose page 1 showed `A B C D E`, and then a new row arrives before `A`.
`OFFSET 5` now returns `E F G H I`: **`E` appears twice**, because the
positions shifted underneath the number. A keyset request for "after `E`"
returns `F G H I J` no matter what was inserted earlier.

### The trade-off

| OFFSET                              | Keyset                                   |
| ----------------------------------- | ---------------------------------------- |
| "Skip **N rows**"                   | "Start **after this key**"               |
| Jump to any page number             | Next and previous from a known row only  |
| Gets slower the deeper you go       | Same cost on every page                  |
| Rows can repeat or vanish as data changes | Stable under inserts and deletes   |
| Fine for small or admin datasets    | Built for large or live datasets, APIs, infinite scroll |

There's no "jump to page 7,423" with a cursor. For a feed, that's fine. For a
UI with numbered pages, it's a product decision.

> **OFFSET tells the database how many rows to walk past. Keyset tells it
> where to start.**

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). These numbers are from
`idx_1m`. The plan is the same for every page; only the time changes:

| Query                                                        | Plan                    |   Time |
| :----------------------------------------------------------- | :---------------------- | -----: |
| `ORDER BY purchase_id LIMIT 5 OFFSET 0` (+ join to products) | `SCAN pu`               |  <5 ms |
| `… LIMIT 5 OFFSET 900000`                                    | `SCAN pu`               | 118 ms |
| `… WHERE purchase_id > 900000 ORDER BY purchase_id LIMIT 5`  | `SEARCH pu … (rowid>?)` |  <1 ms |

Because every index entry ends with the rowid, `idx_purchases_date` is
already in `(purchase_date, purchase_id)` order. It serves the row-value
`ORDER BY` above with no sort and seeks straight to the cursor.

## DuckDB

**Fit: ✓, for a different reason.** DuckDB's indexes are for constraints and
point lookups, not range scans. A keyset query is fast anyway because DuckDB
keeps the **minimum and maximum** of every column for each block of rows, and
skips blocks that can't match `purchase_id > :after_id`. That works well when
the data is stored roughly in key order, as generated data is. `OFFSET` still
has to produce every skipped row.

## PostgreSQL

**Fit: ✓.** The textbook case. A B-tree on the sort key serves the seek, and
row-value comparisons like `(purchase_date, purchase_id) < (…)` can use a
composite index on those two columns. `EXPLAIN ANALYZE` shows `OFFSET`'s cost
directly: the "rows" it read versus the rows it returned.

## MongoDB

**Fit: ✓.** `skip()` is `OFFSET`, with the same cost. The keyset version:

```js
db.purchases.find({ _id: { $gt: lastId } }).sort({ _id: 1 }).limit(50)
```

For a non-unique sort field, sort on `{ purchase_date: -1, _id: -1 }` and
filter with `$or` on the two fields, backed by a compound index.

## Redis

**Fit: ~.** A **sorted set** is an ordered index, so "the next 50 after this
score" is natural:

```
ZRANGE purchases:by_date (1756684800 +inf BYSCORE LIMIT 0 50
```

Redis's own `SCAN` command over keys is cursor-based by design, but it returns
keys in no useful order and may repeat some, so it's for walking a keyspace,
not for paging a sorted result.

## In the catalog

**Q11** is the deep-page case: the same 50 rows fetched with `OFFSET` and
with keyset. **Q02** is the shallow case. Their **Think about it** prompts
([q11.sql](../../../engines/01_sqlite/06_queries/q11.sql),
[q02.sql](../../../engines/01_sqlite/06_queries/q02.sql)) ask what `OFFSET` does
with the rows it skips, and what keyset costs the client. Answer from your
own numbers at two sizes.
