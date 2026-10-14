# Concept Map

The same questions asked of every engine. Each cell is the short answer;
each unit's `concept_answers.md` has the detail, and the
[topics](topics/README.md) compare one row in depth. "N/A, because…" is a
valid answer.

| Question                   | SQLite                                   | PostgreSQL                                     | MongoDB                                          | Redis                                            | DuckDB                                     |
| -------------------------- | ---------------------------------------- | ---------------------------------------------- | ------------------------------------------------ | ------------------------------------------------ | ------------------------------------------ |
| **Process model**          | library in your process                  | client-server; a process per connection        | client-server (`mongod`)                         | client-server; one thread runs commands          | library in your process                    |
| **Top-level container**    | one file                                 | cluster (one server) of databases              | deployment of databases                          | one server instance                              | one file                                   |
| **Namespace inside it**    | tables (`ATTACH` adds files)             | database → schema → table                      | database → collection                            | numbered databases (0–15) + key prefixes         | schema → table                             |
| **Unit of data**           | row                                      | row                                            | document (BSON)                                  | key → value (string, hash, list, set, sorted set, …) | row, stored by column                  |
| **Who are the users?**     | none                                     | roles with `LOGIN`                             | users in an auth database                        | ACL users + `default`                            | none                                       |
| **Permission granularity** | the file (OS permissions)                | database, schema, table, column, row           | database or collection, per action               | commands, key patterns, channels                 | the file (OS permissions)                  |
| **Schema enforcement**     | loose (type affinity); `STRICT` opt-in   | strict                                         | none by default; optional `$jsonSchema`          | none                                             | strict                                     |
| **Relationships**          | foreign keys, **off** unless enabled     | foreign keys, enforced                         | embed, or reference + `$lookup`; not enforced    | by key-naming convention only                    | foreign keys (no cascading)                |
| **Index types**            | B-tree; FTS5, R\*Tree                    | B-tree, hash, GIN, GiST, BRIN, …               | single, compound, multikey, text, 2dsphere, …    | the key itself; sorted sets as hand-built indexes | automatic min/max per block; ART          |
| **How to see the plan**    | `EXPLAIN QUERY PLAN`                     | `EXPLAIN (ANALYZE)`                            | `.explain("executionStats")`                     | none: commands are their own plan (`SLOWLOG`)    | `EXPLAIN` / `EXPLAIN ANALYZE`              |
| **Transactions**           | ACID, serializable                       | ACID, MVCC; read committed by default          | one document is atomic; multi-document on replica sets | `MULTI`/`EXEC` (no rollback), Lua scripts  | ACID, MVCC                                 |
| **Unit of locking**        | **the whole file** (one writer)          | row                                            | document                                         | none needed (one command at a time)              | row, optimistic; one writing process       |
| **Code inside the DB**     | triggers; no procedures                  | functions, procedures, triggers                | none in the server; change streams outside       | Lua scripts, functions                           | macros                                     |
| **Durability knob**        | `journal_mode`, `synchronous`            | `synchronous_commit`, WAL settings             | write concern (`w`, `j`)                         | RDB snapshots, AOF + `appendfsync`               | WAL + checkpoints                          |
| **Replication model**      | none built in (Litestream, LiteFS)       | streaming and logical replication              | replica sets, automatic failover                 | async replicas; Sentinel for failover            | none built in                              |
| **Sharding model**         | none                                     | none built in (Citus extension)                | sharded clusters, by shard key                   | Redis Cluster: 16,384 hash slots                 | none                                       |
| **Backup**                 | `.backup`, `VACUUM INTO`                 | `pg_dump`, `pg_basebackup`                     | `mongodump`                                      | copy the RDB or AOF file                         | `EXPORT DATABASE`                          |
| **CLI**                    | `sqlite3`                                | `psql`                                         | `mongosh`                                        | `redis-cli`                                      | `duckdb`                                   |
| **Python driver**          | `sqlite3` (standard library)             | `psycopg`                                      | `pymongo`                                        | `redis` (redis-py)                               | `duckdb`                                   |

## Where to read more

| Rows                                                                         | Read                                                                 |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Top-level container, Namespace inside it, Who are the users?, Permission granularity | [Users, roles, and schemas](topics/users_roles_schemas.md)   |
| Transactions, Unit of locking, Durability knob                               | [Concurrency and locking](topics/concurrency_and_locking.md)         |
| Code inside the DB                                                           | [Procedures and triggers](topics/procedures_and_triggers.md)         |
| SQLite and PostgreSQL columns                                                | [SQLite vs. PostgreSQL](topics/sqlite_vs_postgres.md)                |
| Replication model, Sharding model                                            | [Distributed track](tracks/distributed/README.md)                    |
| Index types, How to see the plan                                             | each unit's `07_explain/`                                            |
| One engine's whole column, in detail                                         | [SQLite](units/01_sqlite/concept_answers.md) · [Postgres](units/02_postgres/concept_answers.md) · [MongoDB](units/03_mongodb/concept_answers.md) · [Redis](units/04_redis/concept_answers.md) · [DuckDB](units/05_duckdb/concept_answers.md) |
