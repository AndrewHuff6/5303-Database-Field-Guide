# Random Sampling

> **Queries:** Q12
>
> **The idea:** Picking random rows without shuffling the whole table

## The problem (engine-neutral)

```sql
SELECT * FROM purchases ORDER BY random() LIMIT 10;
```

That asks the database to:

1. give **every** row a random number,
2. **sort** all of them by it,
3. keep 10.

`LIMIT 10` doesn't help: the 10 smallest random numbers aren't known until
every row has one. The full cost of the table, on every call. Filtering
first (`WHERE department = 'Books' ORDER BY random()`) only shrinks the
problem to the filtered set.

### Cheaper approaches

All of them use the fact that looking up one row by its key is a seek, not a
scan.

| Technique                                                                | Cost          | Caveat                                                                     |
| :----------------------------------------------------------------------- | :------------ | :------------------------------------------------------------------------- |
| **Random probe**: `WHERE id >= <random in [1, max]> ORDER BY id LIMIT 1` | one seek      | Rows right after a gap in the ids get picked more often                    |
| **N random ids**, then `WHERE id IN (…)`                                 | N seeks       | Missing ids return fewer rows, so ask for a few extra. Duplicates are possible |
| **A stored random key**: an indexed column of random values, then seek to a random point in it | one seek | Fixed when the row is written; every row needs one        |
| **A precomputed sample table**, refreshed periodically                  | instant       | Not fresh on every call                                                    |
| **A random sample from a *filtered* set**                                | hard          | Random ids mostly miss the filter. Probe repeatedly, or keep a list of eligible ids |
| **Reservoir sampling** in the application, over a stream                 | one pass      | Uniform, but still reads everything once                                   |

### Say which "random" you mean

"Random" has a statistical meaning. Each of the techniques above gives a
different guarantee: **uniform** (every row equally likely),
**approximately uniform**, or **random-ish**. Say which one your endpoint
provides.

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). The examples sample
`customers`.

`ORDER BY random() LIMIT 5` shows up as `SCAN` + `USE TEMP B-TREE FOR ORDER
BY`: a random number for every row, then a sort of all of them. Its cost
grows with the table, while a rowid probe (`SEARCH … USING INTEGER PRIMARY
KEY (rowid>?)`) stays at one seek. The script builds N random ids with a
recursive CTE and fetches them with `IN (…)`.

## DuckDB

**Fit: ✓, built in.** `USING SAMPLE 10 ROWS` (reservoir: exact count,
uniform), `USING SAMPLE 1%`, or `TABLESAMPLE`, with a choice of method:
`reservoir`, `bernoulli` (each row independently), or `system` (whole blocks
at once, fastest and least random).

## PostgreSQL

**Fit: ✓.** `TABLESAMPLE SYSTEM (1)` samples whole pages (fast, clumpy), and
`TABLESAMPLE BERNOULLI (1)` samples rows (slower, more uniform). Both return
a *percentage*. For an exact number of rows, the `tsm_system_rows` extension
adds `SYSTEM_ROWS(n)`.

## MongoDB

**Fit: ✓.** The `$sample` stage: `{ $sample: { size: 10 } }`. When it's the
first stage and the size is small relative to the collection, MongoDB picks
documents with a random cursor instead of sorting everything.

## Redis

**Fit: ✓, natively.** `SRANDMEMBER`, `ZRANDMEMBER`, and `HRANDFIELD` pick
random members of a set, sorted set, or hash, and `RANDOMKEY` picks a random
key. These are constant-time operations, because the data structures support
them directly.

## In the catalog

**Q12** samples 10 purchases, once with `ORDER BY random()` and once with ids
chosen in Python. Its **Think about it** prompt in
[q12.sql](../../../engines/01_sqlite/06_queries/q12.sql) asks how many rows each
touches, and what has to be true about `purchase_id` for the fast version to
be fair. The caveats column above is where to look.
