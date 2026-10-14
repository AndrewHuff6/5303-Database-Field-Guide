# SQLite — Concept Map Answers

SQLite's column of the [concept map](../../reference/concept_map.md), with the detail
that doesn't fit in a table cell. Same questions, same order, for every engine.

| Question                   | SQLite                                                                                                                                                      |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Process model**          | In your process. The engine is a C library linked into your program; there is no server.                                                                    |
| **Top-level container**    | The file. One database = one file (plus `-wal`/`-shm` in WAL mode).                                                                                         |
| **Namespace inside it**    | None beyond the file. `ATTACH 'other.db' AS other` lets one connection query several files as `other.table`.                                                |
| **Unit of data**           | Row, in a table B-tree keyed by `rowid`.                                                                                                                    |
| **Who are the users?**     | None. There are no accounts or passwords; anyone who can open the file can read it.                                                                         |
| **Permission granularity** | The file, via operating-system permissions. Read-only access = open with `?mode=ro` or file permissions.                                                    |
| **Schema enforcement**     | Loose by default: *type affinity* means a declared type is a preference. `STRICT` tables (3.37+) enforce types. `CHECK`, `NOT NULL`, `UNIQUE` are enforced. |
| **Relationships**          | Foreign keys, **off by default**. `PRAGMA foreign_keys = ON` per connection. Foreign-key columns are **not** indexed automatically.                         |
| **Index types**            | B-tree (including partial and expression indexes). FTS5 (full-text) and R\*Tree (bounding boxes) as virtual tables.                                         |
| **How to see the plan**    | `EXPLAIN QUERY PLAN <query>`, or `.eqp on` in the shell. Shows the strategy, not row counts or actual times. Use `.timer on` for time.                      |
| **Transactions**           | Yes, full ACID, serializable. `BEGIN` / `BEGIN IMMEDIATE` / `COMMIT`. Python's `with con:` wraps one.                                                       |
| **Unit of locking**        | The whole file. Many readers; **one writer**. WAL lets readers continue during a write.                                                                     |
| **Code inside the DB**     | Triggers. No stored procedures; application-defined functions are registered from the host language (`con.create_function`).                                |
| **Durability knob**        | `journal_mode` (`DELETE`, `WAL`, …) and `synchronous` (`FULL`, `NORMAL`, `OFF`).                                                                            |
| **Replication model**      | None built in. Third-party tools (Litestream, LiteFS) stream the WAL to other storage.                                                                      |
| **Sharding model**         | None. One file; split data across files yourself.                                                                                                           |
| **Backup**                 | `.backup` / `VACUUM INTO 'copy.db'` / `.dump` to SQL text. **Never** plain-copy a live WAL database.                                                        |
| **CLI**                    | `sqlite3`                                                                                                                                                   |
| **Python driver**          | `sqlite3` (standard library)                                                                                                                                |

## Notes

- **"No users" is a feature, not a gap**, for the jobs SQLite is built for.
  A phone app's database has one user: the app. The concept map's "who are
  the users?" row is where SQLite's design and PostgreSQL's diverge most.
- **Encryption** is entirely application-side (password hashing, field
  encryption) or whole-file via SQLCipher, a separate build.
