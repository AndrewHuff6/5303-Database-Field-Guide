# Topics

Short overviews that don't belong to a single unit: one idea, compared
across the engines, with one hands-on check. Read them alongside the units.

| Topic                                                 | Covers                                                                   | Most useful during     |
| ----------------------------------------------------- | ------------------------------------------------------------------------ | ---------------------- |
| [Users, roles, and schemas](users_roles_schemas.md)   | Who can connect, what they can touch, and the three meanings of "schema" | Postgres 02–04         |
| [Concurrency and locking](concurrency_and_locking.md) | Locks vs. MVCC, isolation levels, each engine's unit of locking          | every unit's 08        |
| [Procedures and triggers](procedures_and_triggers.md) | What code can run inside each database, and whether it should            | SQLite 05, Postgres 04 |
| [SQLite vs. DuckDB](sqlite_vs_duckdb.md)              | The two embedded engines: row store vs. column store, and when each wins | the start of DuckDB    |
| [SQLite vs. PostgreSQL](sqlite_vs_postgres.md)        | The two SQL engines side by side, and what porting a query involves      | the start of Postgres  |
| [Replication and caching](replication_and_caching.md)  | Copies for reads vs. writes, write-through vs. write-back, three SQLite copies | SQLite 08, the distributed track |

## How topics differ from the other folders

| Folder                              | Holds                                                           |
| ----------------------------------- | --------------------------------------------------------------- |
| [engines/](../../engines/)                 | One engine, nine fixed sections                                 |
| [tracks/](../../tracks/)               | One theme (spatial, vector, distributed) with all nine sections |
| [patterns/](../patterns/)           | One query technique, engine-independent                         |
| **topics/**                         | One concept, compared across engines, one page each             |
| [concept_map.md](../concept_map.md) | The same 19 questions for every engine, in one table            |

## Candidates for later

Durability and backups, and indexes across engines.
