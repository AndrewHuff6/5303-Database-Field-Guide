# 05 — Load it: SQLite

> **Fixed question:** Get the generated `store` data in, reproducibly.
>
> **Student artifact:** One rebuild command that produces the same database every time

There are two loading paths. They produce the **same schema** at different
sizes and for different jobs:

| Path | Size | Source | Use |
| ---- | ---- | ------ | --- |
| **A. Classroom** | 1,000 purchases | the flat CSV in `datasets/store/classroom/` | Live demos, QueryMux, learning the ETL steps |
| **B. Generated** | 10k / 100k / 1M purchases, `idx` and `noidx` variants | the seeded generator in `datasets/store/generator/` | Experiments in [§7](../07_explain/) and [§8](../08_concurrency/) |

Run everything **from this folder** (`engines/01_sqlite/05_load/`). Script paths
are relative to where you launch `sqlite3`.

---

## A. Classroom build (from CSV)

```bash
cd engines/01_sqlite/05_load
rm -f store_classroom.db
sqlite3 store_classroom.db ".read rebuild.sql"
```

Expected tail of the output:

```
purchases,1000
"== verification =="
1000,28275.04,1000
"== rebuild complete =="
```

### What `rebuild.sql` does

| Step | Script | What happens |
| ---- | ------ | ------------ |
| 1 | [../04_model/schema.sql](../04_model/schema.sql) | Drops and recreates every table, index, and the `purchase_details` view. Safe to re-run. |
| 2 | [load_classroom.sql](load_classroom.sql) | The ETL: staging → lookups → parents → children (details below). |
| 3 | `rebuild.sql` itself | Verifies: `PRAGMA foreign_key_check`, plus a row-count and revenue round trip against the CSV. |

### The ETL pattern: never load a CSV straight into a constrained schema

1. **Stage.** Create `staging_raw`, every column `TEXT`, no constraints. It
   accepts the file no matter how dirty it is. `.import --skip 1` loads it.
2. **Parents first.** `INSERT … SELECT DISTINCT` fills `states`,
   `card_types`, `departments`, and `zipcodes`, so the children's foreign
   keys have something to point at.
3. **Then the rest, in dependency order:** `customers` → `cards` →
   `products` → `purchases`. `purchases` looks up surrogate ids by joining
   back on the natural keys (`email`, `card_number`, `product_name`).
4. **Transform on the way in.** Dates arrive as `M/D/YYYY`, and a CTE splits
   and zero-pads them into ISO `YYYY-MM-DD`.
5. **Drop staging**, so nobody queries the un-normalized copy by accident.

This staging-then-transform shape carries over to every engine. Only the
syntax changes (`COPY` in Postgres, `insertMany` in MongoDB).

### Explore before you design

[data_quality.sql](data_quality.sql) holds the functional-dependency checks
from the [§4 walkthrough](../04_model/), with their results. Run them against a
staging-only database (steps A–B of `load_classroom.sql`) before designing
anything.

> **Classroom-size caveat:** the CSV has exactly **one purchase per
> customer**. Per-customer queries (Q04 history, Q06 streaks) run, but return
> almost nothing. Use the generated data for those.

---

## B. Generated builds (for experiments)

The experiment databases come from a seeded, skewed generator. Skewed means a
few "whale" customers do most of the buying. For each size it builds two files
with **identical rows**:

| File | Indexes |
| ---- | ------- |
| `idx_<size>.db` | foreign-key indexes from the schema + [covering_indexes.sql](covering_indexes.sql) |
| `noidx_<size>.db` | only what SQLite creates automatically (`PRIMARY KEY`, `UNIQUE`); [drop_indexes.sql](drop_indexes.sql) removes the rest |

Both also get the `monthly_sales` rollup from
[summary_tables.sql](summary_tables.sql), which the `/fast` versions of Q13
and Q14 read.

| Size | Purchases | Customers | Products |
| ---- | --------- | --------- | -------- |
| `10k` | 10,000 | 500 | 100 |
| `100k` | 100,000 | 5,000 | 500 |
| `1m` | 1,000,000 | 50,000 | 5,000 |

```bash
python3 ../../../datasets/store/generator/make_dbs.py   # ~10 s, ~290 MB
```

The databases land in `datasets/store/generated/sqlite/`. See the
[generator README](../../../datasets/store/generator/README.md) for the
options and how the skew works.

## Keeping summary tables fresh

[summary_tables.sql](summary_tables.sql) builds `monthly_sales` once. It goes
stale on the first new purchase. [triggers_and_procedures.md](triggers_and_procedures.md)
shows three ways to keep it fresh in SQLite, which has no stored procedures,
and what each costs.

## Not in version control

`*.db`, `*.db-wal`, and `*.db-shm` are build artifacts, covered by the repo
`.gitignore`. Rebuild them from the scripts; never commit them.

## Your artifact

The one command you used to build each database, and the row counts it printed.
