# 03 — experiment.py: The Per-Engine Harness

[starter_code/app/experiment.py](../starter_code/app/experiment.py) is the
only file that knows which database engine is behind the API. Routes,
the driver, and the load test don't.

## Its two jobs

### 1. Hand a route a connection: `get_exp_db`

```python
def q01_customer(customer_id: int, db: ExpDB = Depends(get_exp_db)):
```

For every request, `get_exp_db`:

1. reads `?db=` and checks it against the allowed names (a bad name is a 422);
2. finds the file in `DATA_DIR`, or answers 404 if it hasn't been built;
3. opens a connection and sets the per-connection options:
   `foreign_keys = ON`, `busy_timeout`, `synchronous = NORMAL`;
4. yields an `ExpDB` (the connection plus the database's name), and closes
   the connection after the response goes out.

### 2. Run, time, and explain a query: `run_query` and `run_write`

```python
return run_query(db, "Q07", {"start": start, "end": end})
```

1. Load the SQL from `units/01_sqlite/06_queries/q07.sql`. `"Q11-fast"`
   becomes `q11_fast.sql`.
2. Collect the plan with `EXPLAIN QUERY PLAN`, which doesn't execute anything.
3. Start the timer, `execute()` **and** `fetchall()`, stop the timer.
4. Build the [envelope](../02_route_contract/README.md#result-envelope).

`run_write` does the same for Q15, inside a transaction it commits. Any
`sqlite3.Error` becomes a 503 carrying SQLite's own message.

Dates arrive as `datetime.date` objects. The harness converts them to ISO
text (`2025-03-01`), because that's how the schema stores dates.

## Connection strategy differs by engine

| Engine            | Strategy                       | Why                                                                                  |
| ----------------- | ------------------------------ | ------------------------------------------------------------------------------------ |
| SQLite, DuckDB    | open per request               | It's a file. Opening one costs microseconds.                                         |
| Postgres, MongoDB, Redis | **one pool, opened at startup** | Connecting over a network costs milliseconds. Per request, you'd be timing connection setup instead of the query. |

## Porting to a new engine

| Changes                                                     | Stays the same                          |
| ----------------------------------------------------------- | --------------------------------------- |
| how `get_exp_db` connects, and what `?db=` points at       | every route in `main.py`                |
| how the plan is collected (that unit's `07_explain/`)       | the envelope's fields                   |
| which errors become 503s                                    | `driver.py`, `loadtest.py`              |
| where `load_sql` finds the query files, and their extension | the query IDs                           |

That's the payoff of the contract: one new file per engine, and the whole
experiment runs against it.
