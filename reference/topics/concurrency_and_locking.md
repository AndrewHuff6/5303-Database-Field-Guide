# Concurrency and Locking

What happens when two requests touch the same data at the same time. Every
unit's `08_concurrency/` measures this for one engine; this page is the
vocabulary they share.

## The problem

Two requests read a product's inventory (5), each sells one, and each writes
back 4. Two sales, but the inventory dropped by one. That's a **lost
update**, and it's one of several ways concurrent work goes wrong:

| Anomaly                 | What happens                                                                   |
| ----------------------- | ------------------------------------------------------------------------------ |
| **Dirty read**          | You read another transaction's change before it commits, and then it rolls back. |
| **Non-repeatable read** | You read a row twice in one transaction and get two different values.          |
| **Phantom**             | You run the same query twice and new rows have appeared.                       |
| **Lost update**         | Two writers read the same value, and one write silently overwrites the other.  |

Databases prevent these with **transactions** (a group of operations that
commits all at once or not at all), using one of two strategies.

## Two strategies

### Locking

Before touching data, take a lock on it.

- A **shared** (read) lock lets other readers in but keeps writers out.
- An **exclusive** (write) lock keeps everyone else out.

What matters most is **how much** one lock covers, its *granularity*: the
whole database, a table, a page, a row, a document. The bigger the lock, the
more requests wait in line behind it.

A request that can't get a lock **waits**. If it waits too long, it gets a
**timeout** error. If two requests each wait for a lock the other holds, it's
a **deadlock**, and the database must cancel one.

### MVCC (multi-version concurrency control)

Instead of making readers wait, keep **old versions** of changed rows. Each
transaction reads a consistent **snapshot**: the data as it was when the
snapshot was taken. So:

- **Readers never block writers, and writers never block readers.**
- Writers still conflict with other writers on the **same** row.
- Old versions pile up and must be cleaned away (Postgres calls this
  `VACUUM`).

## Isolation levels

The SQL standard names four levels by which anomalies they allow:

| Level                | Dirty read | Non-repeatable read | Phantom |
| -------------------- | :--------: | :-----------------: | :-----: |
| Read uncommitted     | possible   | possible            | possible |
| **Read committed**   | —          | possible            | possible |
| Repeatable read      | —          | —                   | possible |
| **Serializable**     | —          | —                   | —       |

Stronger isolation means fewer anomalies, and more waiting or more
transactions that fail and must be retried. Engines often prevent more than
the standard requires at a given level; check the engine's docs, not just
this table.

## How each engine does it

| Engine   | Strategy                          | Unit of locking                     | Default isolation                | What a blocked writer sees |
| -------- | --------------------------------- | ----------------------------------- | -------------------------------- | -------------------------- |
| SQLite   | locking (+ WAL for readers)       | **the whole database file**         | serializable                     | waits up to `busy_timeout`, then `database is locked` |
| DuckDB   | MVCC, optimistic                  | row (a conflicting change fails at once) | each transaction sees a snapshot | a transaction conflict error; also, only one **process** may open the file for writing |
| Postgres | MVCC + row locks for writes       | row                                 | read committed                   | waits; deadlocks are detected and one side is cancelled |
| MongoDB  | MVCC (WiredTiger), optimistic     | document                            | single-document operations are atomic; multi-document transactions use snapshots | write conflicts are retried, or surface as a transient transaction error |
| Redis    | **none needed**: one command at a time | n/a                            | each command is atomic           | nothing to see: commands queue and run in order |

### SQLite: one writer, full stop

Any number of readers, but **one writer for the whole file**. WAL mode lets
readers keep reading while that writer works, but it doesn't add a second
writer. More API workers mean more processes waiting for the same lock.
[SQLite 08](../../engines/01_sqlite/08_concurrency/README.md) measures this, and
[wal_mode.md](../../engines/01_sqlite/08_concurrency/wal_mode.md) shows how WAL
works.

### Postgres: readers and writers don't wait for each other

MVCC gives every statement (in read committed) or transaction (in repeatable
read and serializable) a snapshot. Two writers only wait for each other when
they change the **same row**. `SELECT ... FOR UPDATE` takes a row lock on
purpose, the standard fix for the lost-update example above.

### MongoDB: the document is the unit

One write to one document is atomic, which is why embedding related data in a
single document is often enough. Transactions across documents exist, but
need a replica set and cost more.

### Redis: single-threaded on purpose

Redis runs commands one at a time on one thread, so each command is atomic
with no locks at all. `INCR stock:42` can't lose an update. For several
commands as a group, `MULTI`/`EXEC` runs them back to back (with no rollback),
and a Lua script runs atomically.

### DuckDB: built for one writer process

DuckDB uses MVCC inside one process: several threads can work at once, and
two transactions that change the same row conflict. But only **one process**
may open a database file for writing. It's built for analytics in one
program, not a server with many writers.

## Try it: two shells, one SQLite file

Open two terminals on the same scratch database:

```bash
cp datasets/store/generated/sqlite/idx_10k.db /tmp/locks.db
sqlite3 /tmp/locks.db        # in both terminals
```

```sql
-- terminal 1
BEGIN IMMEDIATE;             -- take the write lock now
INSERT INTO departments VALUES ('Snacks');

-- terminal 2
SELECT count(*) FROM departments;            -- (a)
INSERT INTO departments VALUES ('Pets');     -- (b)

-- terminal 1
COMMIT;
```

**Before running (a) and (b), predict** which one waits, which one fails,
and what (a) returns: does it include `Snacks`? Then try (b) again after
`.timeout 10000` in terminal 2, and commit terminal 1 while (b) is waiting.

## See also

- [Load scenarios](../../lab/load_scenarios.md): the traffic shapes every
  `08_concurrency/` uses
- [Concept map](../concept_map.md) rows: *Transactions*, *Unit of locking*,
  *Durability knob*
- [Glossary](../../engines/00_foundations/glossary.md)
