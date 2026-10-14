# Starter code: the measurement API

The `store` query catalog behind FastAPI, running on SQLite. Every route
returns the [result envelope](../02_route_contract/README.md): rows, plus how
long the database took and the plan it used.

Sixteen routes are written for you. **You write three: Q03, Q08, and Q15.**
Search `app/main.py` for `TODO`.

## Layout

```
starter_code/
├── pyproject.toml          dependencies: fastapi, uvicorn, pydantic, httpx (+ pytest)
├── .env.example            DATA_DIR, BUSY_TIMEOUT_MS
├── app/
│   ├── main.py             the routes, one per catalog row  <- your three go here
│   ├── experiment.py       ?db= selection, run_query(), run_write(), the envelope
│   └── models.py           NewPurchase, the JSON body for Q15
├── driver.py               calls every route on every database -> results/
└── tests/
    ├── conftest.py         builds a small temp database for the tests
    ├── test_smoke.py       passes out of the box
    └── test_your_routes.py fails until your three routes work
```

The SQL isn't in `main.py`. Each route loads its query from
[engines/01_sqlite/06_queries/](../../../engines/01_sqlite/06_queries/README.md),
so the `.sql` file is the only copy. Change the file, and the route changes.

## Setup

From the repo root:

```bash
python3 datasets/store/generator/make_dbs.py      # ~10 s: the six test databases

cd lab/api/starter_code
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
pytest tests/test_smoke.py -q                     # should pass before you start
```

Then write your three routes until this passes:

```bash
pytest tests/test_your_routes.py -v
```

## Run it

```bash
python -m app.main             # http://127.0.0.1:8001/docs
```

Try a route in the browser:
<http://127.0.0.1:8001/customers?customer_id=7&db=idx_1m>

In a second terminal, run the experiment:

```bash
python driver.py --sizes 10k   # quick check
python driver.py               # all six databases -> results/results.md
```

**Always run from this folder.** `python -m app.main` and
`uvicorn app.main:app --port 8001` both work. `python app/main.py` does not,
because the `app.` package-relative imports need the package context.

| Variable          | Default                          | Read by                          |
| ----------------- | -------------------------------- | -------------------------------- |
| `DATA_DIR`        | `datasets/store/generated/sqlite/` | `experiment.py`, `driver.py`   |
| `FIELD_GUIDE`     | the clone this folder sits in    | `experiment.py`, `driver.py`, tests: where to find `06_queries/` when this folder is copied into your own repo |
| `BUSY_TIMEOUT_MS` | `5000`                           | `experiment.py` (08_concurrency) |
| `HOST`, `PORT`    | `127.0.0.1`, `8001`              | `python -m app.main`             |
| `RELOAD`          | `1` (set `0` to turn off)        | `python -m app.main`             |

## Editor setup (VS Code / Pyright)

`app/` is a package, and its modules import each other **relatively**
(`from .experiment import run_query`). Don't let an "organize imports" action
rewrite these to `from experiment import ...`. That form resolves in the
editor but crashes at runtime with `ModuleNotFoundError`.

Select the `.venv` interpreter: Command Palette → *Python: Select Interpreter*
→ `./.venv`.

## How it all fits

| Page                                                  | Covers                                             |
| ----------------------------------------------------- | -------------------------------------------------- |
| [01 FastAPI basics](../01_fastapi_basics/README.md)   | Decorators, parameters, validation, `Depends`      |
| [02 Route contract](../02_route_contract/README.md)   | The paths and the envelope every engine follows    |
| [03 experiment.py](../03_experiment_py/README.md)     | What the harness does, and what changes per engine |
| [04 driver.py](../04_driver/README.md)                | How the experiment runs and what it writes         |
| [loadtest](../../loadtest/README.md)                  | Many requests at once, for 08_concurrency          |
