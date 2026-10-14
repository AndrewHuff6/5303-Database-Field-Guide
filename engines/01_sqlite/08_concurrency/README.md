# 08 — Concurrency & load: SQLite

> **Fixed question:** How does it behave under the load scenarios that apply to it?
>
> **Student artifact:** Load results table + the exact error text

## The one rule

**SQLite allows one writer at a time, for the whole database file.**

- Any number of readers can run at once.
- A second writer waits up to `busy_timeout` milliseconds for the lock, then
  fails with **`database is locked`**.
- Two clients inserting unrelated rows into *different tables* still take
  turns, because the lock covers the file, not the row or the table.

Everything in this section is a consequence of that rule.

---

## 1. Journals: how a commit stays all-or-nothing

A commit may change dozens of 4 KB pages. If the power fails halfway through,
the file would hold a mix of old and new pages. A **journal** prevents that.
SQLite has two kinds:

| | Rollback journal (`journal_mode = DELETE`, the default) | Write-ahead log (`journal_mode = WAL`) |
| - | ------------------------------------------------------- | -------------------------------------- |
| On commit | copy originals to `-journal`, **overwrite pages in place** | **append** new pages to `-wal`; the main file is untouched |
| Readers during a write | blocked: they could see half-written pages | keep reading their **snapshot** |
| Writer during a long read | waits for every reader to finish | commits immediately |
| Writers at once | one | **still one** |
| Files | `store.db` (+ `-journal` during commit) | `store.db` + `store.db-wal` + `store.db-shm` |

**WAL helps reads during writes. It never allows two writers.** All
experiment databases are built in WAL mode.

### WAL details that bite

- **Checkpoints** copy WAL pages back into the main file, automatically at
  1,000 pages and when the last connection closes.
- **Never copy just the `.db` file of a live WAL database.** Committed rows may
  exist only in `-wal`, and the copy silently loses them. Use `.backup` or
  `VACUUM INTO`.
- **`BEGIN IMMEDIATE`** for read-then-write transactions. A plain `BEGIN` takes
  a snapshot, and if someone else commits before you write, your write fails
  instantly with `database is locked`, without waiting. `IMMEDIATE` takes the
  write lock up front.
- **`PRAGMA journal_mode = WAL` returns the mode it ended up in.** If it
  answers `delete`, the switch failed.

---

## 2. The knobs

| Knob | Where | Effect |
| ---- | ----- | ------ |
| `busy_timeout` | `PRAGMA busy_timeout = 5000` per connection (the API reads `BUSY_TIMEOUT_MS`) | How long a writer waits for the lock before failing |
| `journal_mode` | `PRAGMA journal_mode = WAL`, stored in the file | Whether readers block writers |
| `synchronous` | `PRAGMA synchronous = NORMAL` | How often SQLite forces data to disk (durability vs. speed) |
| Server workers | `uvicorn --workers 4` | More processes sending requests at once |

---

## 3. The experiment

SQLite runs the write-centric [load scenarios](../../../lab/load_scenarios.md).
Read-heavy (S1) is uninteresting here, because readers never block.

| Scenario | Runs on SQLite? | Why |
| -------- | :-------------: | --- |
| S1 read-heavy | — | WAL readers don't block; nothing to see |
| **S2 write-heavy** | ✓ | the one-writer rule in its purest form |
| S3 hot row | — | waiting on an `UPDATE` route; in SQLite every write is "hot" anyway, since the whole file is the lock |
| **S4 mixed 90/10** | ✓ | shows WAL letting reads continue during writes |
| S5 burst | optional | same story as S2, louder |

### S2: four runs, one knob at a time

Every run writes into a scratch copy so the experiment databases stay clean.
From the repo root:

```bash
cp datasets/store/generated/sqlite/idx_100k.db datasets/store/generated/sqlite/writes.db
```

Then work from [lab/api/starter_code/](../../../lab/api/starter_code/README.md)
with its `.venv` active. Your Q15 route must be working first. For each run,
stop the API, restart it as shown, then fire the load twice (`--n 200` and
`--n 500`):

| Run | Start the API with | What changes |
| --- | ------------------ | ------------ |
| A | `BUSY_TIMEOUT_MS=0 RELOAD=0 python -m app.main` | writers give up **instantly** |
| B | `BUSY_TIMEOUT_MS=5000 RELOAD=0 python -m app.main` | writers **wait** up to 5 s |
| C | `BUSY_TIMEOUT_MS=0 uvicorn app.main:app --port 8001 --workers 4` | 4 processes, no waiting |
| D | `BUSY_TIMEOUT_MS=5000 uvicorn app.main:app --port 8001 --workers 4` | 4 processes, waiting |

```bash
python ../../loadtest/loadtest.py --method POST --path "/purchases?db=writes" --n 200
python ../../loadtest/loadtest.py --method POST --path "/purchases?db=writes" --n 500
```

### Record

| Run | n | succeeded (201) | failed (503) | seconds | writes/sec | p95 ms | example error |
| --- | - | --------------- | ------------ | ------- | ---------- | ------ | ------------- |

Take `p95 ms` from the *successes* line of the [loadtest](../../../lab/loadtest/README.md) output.

### Run E: the same purchases, batched

Runs A–D change **who waits and how many processes compete**. Run E changes
something else: how many purchases share one commit.
`POST /purchases/fast` (already written for you) takes a JSON array and
inserts every purchase in it inside **one transaction**.

Start the API as in run B, then send the same 500 purchases as 20 requests
of 25:

```bash
python ../../loadtest/loadtest.py --method POST --path "/purchases/fast?db=writes" --n 20 --batch 25
```

**Predict first:** compared with run B at `--n 500`, will purchases written
per second be about the same, a bit higher, or much higher? Then record it:

| Run | requests | purchases per request | succeeded | seconds | purchases written/sec |
| --- | -------- | --------------------- | --------- | ------- | --------------------- |
| B   | 500      | 1                     |           |         |                       |
| E   | 20       | 25                    |           |         |                       |

### Then check the summary table

```bash
sqlite3 ../../../datasets/store/generated/sqlite/writes.db "SELECT COUNT(*) FROM purchases; SELECT SUM(num_purchases) FROM monthly_sales;"
```

**Predict before you run it:** will the two numbers match? Question 3 asks
you to explain what you see, and what it means for the Q13/Q14 `/fast` routes
(see [counting_and_summaries](../../../reference/patterns/counting_and_summaries/)).

---

## 4. Questions to answer

1. What does `busy_timeout` actually do, and why did run B succeed where run A failed?
2. Did 4 worker processes (C, D) let SQLite write **faster**? Why or why not?
3. Do the two summary-table numbers match? Explain what you see, and what it costs the Q13/Q14 `/fast` routes.
4. Compare runs B and E. Where does the time go in a single-purchase write, and why does batching change it so much (or so little)? When would batching **not** be acceptable for an application?

## Going deeper

- [wal_mode.md](wal_mode.md): how WAL lets readers and one writer work at
  once, with two demos you can run.
- [triggers_and_procedures.md](../05_load/triggers_and_procedures.md): three
  ways to keep `monthly_sales` fresh, and what each one costs a write.
- [Concurrency and locking](../../../reference/topics/concurrency_and_locking.md): the
  same questions across all five engines.
- [Replication and caching](../../../reference/topics/replication_and_caching.md): why
  more copies of the file wouldn't have helped the writes either.

## Your artifact

The filled-in table, the **exact** error text, and short answers to the three
questions, each citing a number from your table.
