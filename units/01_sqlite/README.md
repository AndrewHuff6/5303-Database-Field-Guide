# 01 — SQLite

Relational · embedded · row store

SQLite is the first engine in the field guide, and the baseline every later
engine is compared against. It is a **library**, not a server: the whole
database is one file, and the engine runs inside your program. That one fact
explains almost everything in this unit, from "nothing to install" to "one
writer at a time."

**You'll come out of this unit able to:**

- build the `store` database from a flat CSV, and explain every design decision;
- query it three ways: the `sqlite3` CLI, QueryMux, and Python;
- read `EXPLAIN QUERY PLAN` and say *why* a query is fast or slow;
- measure where SQLite breaks under concurrent writes;
- decide when SQLite is the right choice, and back the decision with your own numbers.

## The nine sections

| # | Section | Fixed question |
| - | ------- | -------------- |
| 01 | [Why it exists](01_why/) | What problem was this built for, and what does it give up? |
| 02 | [Install & verify](02_install/) | Can I run it and prove it's running? |
| 03 | [Connect three ways](03_connect/) | The same "hello" query from the CLI, QueryMux, and Python. |
| 04 | [Model the data](04_model/) | How does the `store` dataset *want* to look in this engine? |
| 05 | [Load it](05_load/) | Get the generated `store` data in, reproducibly. |
| 06 | [Run the query catalog](06_queries/) | Translate Q01–Q15, or say why one can't or shouldn't be translated. |
| 07 | [Explain & measure](07_explain/) | What does the engine say it did, and how long did it take? |
| 08 | [Concurrency & load](08_concurrency/) | How does it behave under the load scenarios that apply to it? |
| 09 | [When to choose it](09_when/) | Yes or no on the standard scenarios, citing your own numbers. |
| — | [concept_answers.md](concept_answers.md) | SQLite's column of the [concept map](../../concept_map.md), in detail |

## Quick start

```bash
cd units/01_sqlite/05_load
sqlite3 store_classroom.db ".read rebuild.sql"        # build the 1k classroom database
querymux --backend sqlite --db store_classroom.db      # poke at it
```

## Where this unit sits

- **Before:** [00_foundations](../00_foundations/) (vocabulary, first SQL).
- **During:** the measurement API is introduced between §5 and §6. See [lab/api](../../lab/api/).
- **After:** [02_postgres](../02_postgres/), written as "what changed from SQLite."
