# Replication and Caching

Keeping **more than one copy** of the data, and what that does and doesn't
buy you. A cache is a copy. A replica is a copy. They run into the same
problem: when the data changes, every copy has to find out.

## Why keep copies?

| Reason            | Example                                                             |
| ----------------- | ------------------------------------------------------------------- |
| **Read capacity** | Ten copies can answer ten times as many reads                       |
| **Survival**      | A machine dies, and another copy takes over                         |
| **Locality**      | A copy near the user (or in the app's memory) answers faster        |

Notice what's missing: **write capacity**. That's the whole story of this
page.

## Copies help reads, not writes

**Reads** scale with copies, because each copy can answer on its own. The
only question is how **stale** a copy may be.

**Writes** don't. If every copy accepts writes, two copies can change the
same thing differently, and something has to decide who wins. There are
three ways out, and none of them is free:

| Approach         | How it works                                         | Real examples                       | Write throughput                           |
| ---------------- | ---------------------------------------------------- | ----------------------------------- | ------------------------------------------ |
| **One primary**  | All writes go to one copy; the others follow it      | Postgres replicas, LiteFS, MongoDB replica sets | Same as one database: still one writer |
| **Consensus**    | The copies vote on the order of every write          | rqlite and dqlite (SQLite + Raft)   | *Lower*: every write waits for a majority  |
| **Merge later**  | Every copy writes freely; conflicts merge by rules   | cr-sqlite (CRDTs on SQLite)         | High, but the rules decide who wins, not you |

The only thing that multiplies write throughput is **sharding**: each copy
*owns* different data (customers A–M here, N–Z there), so writers never
collide. The price is every query and transaction that spans shards. The
[distributed track](../../tracks/distributed/README.md) measures it.

## The cache analogy

Caches and replicas face the same choice: when a write happens, does it wait
for the copies?

| Cache term        | Replication term          | The write returns…                  | Trade-off                                                  |
| ----------------- | ------------------------- | ----------------------------------- | ---------------------------------------------------------- |
| **Write-through** | synchronous replication   | after the copies have it            | Consistent, but every write waits for the slowest copy     |
| **Write-back**    | asynchronous replication  | immediately; copies catch up later  | Fast, but a crash can lose writes, and reads may be stale  |

Every server engine exposes this as a setting, because there's no right
answer for every application: Postgres's `synchronous_commit` and
synchronous standbys, MongoDB's write concern (`w: "majority"`), Redis's
`WAIT`.

### Words for "how stale"

| Term                       | Means                                                                 |
| -------------------------- | --------------------------------------------------------------------- |
| **Replication lag**        | How far behind a copy is, in time or in writes                        |
| **Stale read**             | Reading a copy that hasn't caught up                                  |
| **Read-your-writes**       | After *you* write, *your* reads see it, even if others' don't yet    |
| **Eventual consistency**   | If writes stop, every copy ends up the same. No promise about *when*  |

## How each engine does it

| Engine   | Built-in replication                                                | Notes                                                                                     |
| -------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| SQLite   | **none**                                                            | Add-ons: Litestream streams the WAL to backup storage; LiteFS keeps read replicas and sends writes to one primary; rqlite and dqlite add consensus; libSQL (Turso) puts read replicas inside each app |
| DuckDB   | **none**                                                            | Read-only copies of a file, or shared Parquet files, are the usual pattern: one job writes, many read |
| Postgres | **streaming** (whole-database copies) and **logical** (chosen tables) | Replicas are read-only; each can be synchronous or asynchronous; failover needs a tool such as Patroni |
| MongoDB  | **replica sets**: one primary, several secondaries                  | Automatic election when the primary fails; reads can go to secondaries, which may be stale |
| Redis    | **asynchronous replicas**                                           | Sentinel handles failover; Redis Cluster shards keys across nodes. Redis is also the most common *cache* in front of other databases |

## What actually helps one writer

Copies don't help SQLite's single writer. These do:

1. **Batch writes.** Many rows in one transaction cost about one commit. See
   run E in [SQLite 08](../../engines/01_sqlite/08_concurrency/README.md).
2. **One writer queue.** Send every write through one thread or process, so
   nobody fights for the lock.
3. **Short transactions.** Hold the lock for as little time as possible.

## Try it: three SQLite copies

These use plain file copies to act out what replication systems do
automatically. From any scratch folder:

```bash
cp datasets/store/generated/sqlite/idx_10k.db primary.db   # or $DATA_DIR/idx_10k.db
```

**1. Read copies.** Make a replica, then write to the primary.

```bash
sqlite3 primary.db ".backup replica.db"
sqlite3 primary.db "INSERT INTO purchases (customer_id, card_id, product_id, department, amount, purchase_date)
                    VALUES (1, 1, 1, 'Games', 9.99, '2026-08-31');"
sqlite3 primary.db "SELECT count(*) FROM purchases"
sqlite3 replica.db "SELECT count(*) FROM purchases"
```

**Predict** both counts before you run the last two lines. Which cache term
describes what you built?

**2. Write-back.** The application writes to a local copy and plans to sync
it to the primary later.

```bash
sqlite3 primary.db ".backup cache.db"
sqlite3 cache.db "INSERT INTO purchases (customer_id, card_id, product_id, department, amount, purchase_date)
                  VALUES (2, 3, 5, 'Books', 19.99, '2026-08-31');"
rm cache.db      # the machine crashes before the sync runs
sqlite3 primary.db "SELECT count(*) FROM purchases WHERE customer_id = 2 AND amount = 19.99"
```

**Predict** the count. The customer saw "purchase complete." What happened
to it, and what would have prevented it?

**3. Two writable copies.** Two app servers each take a purchase on their own
copy.

```bash
sqlite3 primary.db ".backup a.db"
sqlite3 primary.db ".backup b.db"
sqlite3 a.db "INSERT INTO purchases (customer_id, card_id, product_id, department, amount, purchase_date)
              VALUES (3, 5, 7, 'Toys', 5.00, '2026-08-31') RETURNING purchase_id;"
sqlite3 b.db "INSERT INTO purchases (customer_id, card_id, product_id, department, amount, purchase_date)
              VALUES (4, 7, 9, 'Tools', 50.00, '2026-08-31') RETURNING purchase_id;"
```

**Predict** the two `purchase_id`s before you run them. Then try to merge
both new purchases back into the primary:

```bash
sqlite3 primary.db "ATTACH 'a.db' AS a; ATTACH 'b.db' AS b;
  INSERT INTO purchases SELECT * FROM a.purchases ORDER BY purchase_id DESC LIMIT 1;
  INSERT INTO purchases SELECT * FROM b.purchases ORDER BY purchase_id DESC LIMIT 1;"
```

What happened, and which row of the "three ways out" table would have
avoided it?

## See also

- [Concurrency and locking](concurrency_and_locking.md): what happens *inside*
  one copy when writers collide
- [Distributed track](../../tracks/distributed/README.md): Postgres replicas,
  MongoDB replica sets and shards, Redis replicas and Sentinel
- [Concept map](../concept_map.md) rows: *Replication model*, *Sharding model*,
  *Durability knob*
