# 01 — Why it exists: SQLite

> **Fixed question:** What problem was this built for, and what does it give up?
>
> **Student artifact:** One paragraph (then read SQLite's column of the [concept map](../../../concept_map.md))

## The problem SQLite solves

Programs need to store structured data. Before SQLite, the choices were
mostly "write your own file format" or "install and run a database server."
SQLite gives you a third option: **a full SQL database inside a single
ordinary file, with the engine compiled into your program.**

The SQLite authors describe it this way: SQLite doesn't compete with Oracle or
PostgreSQL. It competes with `fopen()`.

## The mental model: library, not server

```
┌──────────────────────── your Python process ────────────────────────┐
│                                                                     │
│   FastAPI route ──► sqlite3 module ──► SQLite engine (C library)    │
│                                              │                      │
└──────────────────────────────────────────────┼──────────────────────┘
                                               │ ordinary file reads/writes
                                               ▼
                               store.db   (+ -wal, -shm in WAL mode)
```

- **There is no server.** `sqlite3.connect("store.db")` opens a file. A query
  is a function call inside your own process, so a primary-key lookup takes
  microseconds, with no network round trip at all.
- **Every process that opens the file has its own copy of the engine.** They
  coordinate through **file locks** on that one file. This is the root of
  SQLite's biggest limitation (see below).
- **Nothing runs while nobody has the file open.** There are no background
  jobs, no scheduler, and no process checking passwords.

## What you get

| Strength                              | Why it matters                                                         |
| ------------------------------------- | ---------------------------------------------------------------------- |
| No server, no setup, no administrator | `pip install` and go; nothing to keep running or patch                 |
| The database is one file              | Email it, check it into a test fixture, ship it inside an app          |
| No network                            | Single-user point lookups are *faster* than any client/server database |
| `:memory:` databases                  | A brand-new database for each test, in microseconds                    |
| Tiny footprint                        | Runs on phones, in browsers (WASM), on embedded devices                |
| Real SQL                              | Joins, CTEs, window functions, triggers, JSON, full-text search        |

SQLite is the most widely deployed database in the world. It's in every
smartphone, every major browser, and most desktop applications.

## What it gives up

| Trade-off                                    | Consequence                                                                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **One writer at a time, for the whole file** | Two clients inserting unrelated rows into different tables still take turns. You'll measure this in [§8](../08_concurrency/). |
| No users, roles, or `GRANT`                  | Access control is whatever the operating system's file permissions allow                                                      |
| Loose typing by default                      | A column declared `INTEGER` will happily store `'hello'` unless you opt into `STRICT` tables                                  |
| Foreign keys are off by default              | `PRAGMA foreign_keys = ON` is needed on *every* connection                                                                    |
| No network access                            | Other machines can't reach it without an app in front of it (that app is what you build in [§6](../06_queries/))              |
| Few server-side features                     | Triggers, yes; stored procedures, no                                                                                          |

## Your artifact

Write one paragraph: *what SQLite is for, and the single trade-off you'd worry
about first for a web application.* Then read SQLite's column of the
[concept map](../../../concept_map.md) and the detail in
[concept_answers.md](../concept_answers.md).
