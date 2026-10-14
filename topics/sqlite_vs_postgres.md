# SQLite vs. PostgreSQL

The two SQL engines students meet first. They run nearly the same SQL, and
most of the query catalog ports from one to the other with small changes.
Underneath, they're built for different jobs, and the differences show up
in setup, types, users, and concurrency, not in `SELECT`.

## The core difference

> **SQLite is a library. PostgreSQL is a server.**

SQLite is code linked into your program. "Opening the database" means
opening a file. PostgreSQL is a separate program that owns its data
directory; your program connects to it over a socket, as a user, and asks it
to do work.

Almost every other row below follows from that.

## Side by side

| Topic                    | SQLite                                                         | PostgreSQL                                                     |
| ------------------------ | -------------------------------------------------------------- | -------------------------------------------------------------- |
| **Process model**        | in your process; no server                                     | client-server; one server process per connection               |
| **Setup**                | none; the file is created on first use                         | install or run a container, create a database and roles        |
| **Where data lives**     | one file you can copy (when it's closed)                       | a data directory only the server touches                       |
| **Users and permissions** | none; OS file permissions                                     | roles, `GRANT`, schemas ([details](users_roles_schemas.md))    |
| **Namespaces**           | file → table                                                   | cluster → database → schema → table                            |
| **Types**                | *affinity*: a declared type is a preference (`STRICT` enforces) | strict: `'abc'` in an `integer` column is an error             |
| **Dates and times**      | no date type; ISO text, or numbers                             | `date`, `timestamp`, `timestamptz`, `interval`                 |
| **Exact money**          | no decimal type                                                | `numeric(10,2)`                                                |
| **Foreign keys**         | off unless `PRAGMA foreign_keys = ON`, per connection          | always enforced                                                |
| **Concurrency**          | many readers, **one writer for the whole file**                | MVCC: readers and writers don't block each other; writers conflict per row ([details](concurrency_and_locking.md)) |
| **Plans**                | `EXPLAIN QUERY PLAN`: the strategy                             | `EXPLAIN (ANALYZE, BUFFERS)`: strategy, row counts, real times |
| **Code inside**          | triggers; no procedures ([details](procedures_and_triggers.md)) | functions, procedures, triggers                               |
| **Index types**          | B-tree, plus FTS5 and R\*Tree as extensions                    | B-tree, hash, GIN, GiST, BRIN, and more                        |
| **Grouping extras**      | no `CUBE` / `GROUPING SETS`                                    | `CUBE`, `ROLLUP`, `GROUPING SETS`                              |
| **Changing a table**     | limited `ALTER TABLE`; big changes mean rebuilding the table   | most changes in place                                          |
| **Replication**          | none built in                                                  | streaming and logical replication                              |
| **Extensions**           | compile-time options, loadable extensions                      | a large ecosystem: PostGIS, pgvector, ...                      |
| **Python driver**        | `sqlite3`, in the standard library                             | `psycopg`                                                      |
| **Placeholders**         | `:name` or `?`                                                 | `%(name)s` or `%s` (psycopg)                                   |

## The same query, ported

Most of the catalog moves over unchanged. The differences cluster where
SQLite stores dates as text:

| Query | SQLite                                       | PostgreSQL                                    |
| ----- | -------------------------------------------- | --------------------------------------------- |
| Q06   | `julianday(day) - ROW_NUMBER() OVER (...)`   | `day - ROW_NUMBER() OVER (...)::int` (date minus integer is a date) |
| Q13   | `substr(purchase_date, 1, 7)`                | `date_trunc('month', purchase_date)` or `to_char(...)` |
| Q14   | three CTEs                                   | one `GROUP BY CUBE (...)` is possible         |

The [SQLite 06 table of SQLite-isms](../units/01_sqlite/06_queries/README.md#sqlite-isms-to-watch-for-when-you-port-these-later)
lists every spot.

## What it costs to get each one running

|                           | SQLite                       | PostgreSQL                                          |
| ------------------------- | ---------------------------- | --------------------------------------------------- |
| First query, from nothing | `sqlite3 test.db "SELECT 1"` | `docker run ... postgres`, wait, `psql -U ...`      |
| Things that can go wrong  | the file path                | ports, passwords, `pg_hba.conf`, roles, Docker      |
| Backing up                | `.backup copy.db`            | `pg_dump`                                           |
| Running in production     | ship the file with the app   | a server to patch, monitor, and back up             |

That's not a point against Postgres. It's what a server costs, and in
return you get many users, many concurrent writers, and a network.

## Questions to settle with your own numbers

These have answers in your §7 and §8 results, not on this page:

- How much faster is a SQLite point lookup than the same lookup in Postgres
  through Docker, and why?
- Under S2 (write-heavy), how do the two compare in successes, failures, and
  writes/sec?
- Which queries got faster when they moved to Postgres, which got slower, and
  what does each plan say?

## See also

- [SQLite unit](../units/01_sqlite/README.md) · [PostgreSQL unit](../units/02_postgres/README.md)
- [Concept map](../concept_map.md): the SQLite and PostgreSQL columns
