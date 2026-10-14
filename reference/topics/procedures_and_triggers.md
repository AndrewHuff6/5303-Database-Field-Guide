# Procedures and Triggers: Code Inside the Database

Some logic can run **inside** the database instead of in your application:
code you call by name (a procedure or function), or code that runs on its
own when data changes (a trigger). The five engines range from "a lot" to
"none at all."

## The vocabulary

| Term                         | What it is                                                                                         |
| ---------------------------- | -------------------------------------------------------------------------------------------------- |
| **Function**                 | Named code stored in the database that returns a value, usable inside a query: `SELECT tax(amount)`. |
| **Stored procedure**         | Named code stored in the database that you `CALL`. It can run several statements, and in some engines commit along the way. |
| **Trigger**                  | Code that runs automatically **before** or **after** an insert, update, or delete.                 |
| **Application-defined function** | A function written in your program's language (Python) and registered with the database connection. It lives in your program, not the database. |
| **Change stream / notification** | The database tells your program that something changed, and your program reacts. The code runs outside the database. |

## How each engine does it

| Engine   | Functions                                           | Procedures                           | Triggers                                     | React to changes from outside           |
| -------- | --------------------------------------------------- | ------------------------------------ | -------------------------------------------- | --------------------------------------- |
| SQLite   | application-defined only (`con.create_function`)   | **none**                             | **yes**: `BEFORE`/`AFTER`/`INSTEAD OF`, per row | —                                    |
| DuckDB   | **macros** (`CREATE MACRO`), and Python functions registered from your program | **none**  | **none**                                | —                                       |
| Postgres | **yes**: SQL, PL/pgSQL, and other languages         | **yes** (`CREATE PROCEDURE`, `CALL`) | **yes**: per row or per statement; a trigger calls a function | `LISTEN` / `NOTIFY`, logical replication |
| MongoDB  | aggregation expressions; no stored functions you'd write by habit | **none**                  | **none** in the server (Atlas, the cloud service, adds them) | **change streams** (needs a replica set) |
| Redis    | **Lua scripts** (`EVAL`) and **functions** (7.0+, `FCALL`) | scripts and functions fill this role | **none**                             | keyspace notifications (pub/sub)        |

### SQLite: triggers yes, procedures no

SQLite's triggers are full-featured: they can check a condition with `WHEN`,
and they run inside the same transaction as the write that fired them. But
there's no `CREATE PROCEDURE`. The usual substitutes are a `.sql` script you
`.read`, or a Python function. The handout
[triggers_and_procedures.md](../../engines/01_sqlite/05_load/triggers_and_procedures.md)
works through all of them, using the stale `monthly_sales` table as the
problem to solve.

### Postgres: the full set

Functions, procedures, and triggers, in SQL or PL/pgSQL (and Python, if the
server has PL/Python installed). The difference that matters: a **function**
runs inside the caller's transaction, while a **procedure** can `COMMIT`
partway through, which is useful for batch jobs.

### MongoDB: react from outside

The server has no triggers. Instead, a program opens a **change stream** and
receives every insert, update, and delete as it happens. The logic lives in
your application, which can be restarted, scaled, and tested like any other
code.

### Redis: scripts run atomically

A Lua script or function runs as **one atomic step**: no other command runs
in the middle. That makes "check a value, then change it" safe without
locks. Keyspace notifications tell subscribers a key changed, but if no one
is listening, the message is lost.

### DuckDB: macros for reuse

A macro is a reusable expression or query with parameters:
`CREATE MACRO revenue(qty, price) AS qty * price;`. DuckDB is built for
analytics, where data is usually loaded in batches, so it has no triggers.

## Should logic live in the database?

| In the database                                              | In the application                                       |
| ------------------------------------------------------------ | -------------------------------------------------------- |
| Runs no matter which program writes the data                 | Easy to version, test, debug, and deploy                 |
| One round trip instead of many                               | Portable: switching engines doesn't mean rewriting it    |
| A trigger can't be forgotten by a careless client            | Visible: nothing happens behind your back                |
| Hidden cost: **every write pays for the trigger**            | Hidden cost: every client must remember to do it         |

A common middle ground: constraints (`NOT NULL`, `CHECK`, foreign keys)
inside the database, because they protect the data, and business logic in
the application.

## Try it: what does a trigger cost?

In SQLite, on a scratch copy:

```bash
cp datasets/store/generated/sqlite/idx_100k.db /tmp/trig.db
sqlite3 /tmp/trig.db
```

```sql
.timer on

-- 50,000 inserts with no trigger. Run this statement three times.
INSERT INTO purchases (customer_id, card_id, product_id, department, amount, purchase_date)
SELECT customer_id, card_id, product_id, department, amount, purchase_date
FROM purchases LIMIT 50000;

-- add a trigger that logs every new purchase
CREATE TABLE purchase_log (purchase_id INTEGER, logged_at TEXT);
CREATE TRIGGER log_purchase AFTER INSERT ON purchases
BEGIN
    INSERT INTO purchase_log VALUES (NEW.purchase_id, datetime('now'));
END;

-- now run the same INSERT three more times
```

Compare the middle time of each set of three. The first run of anything is
often slower, because the data isn't in memory yet.

**Before adding the trigger, predict** how the times will compare: about
the same, about double, or something else? Then explain the number you got.
Hint: count what else changes on every insert into `purchases`
(`.indexes purchases`).

## See also

- [Concept map](../concept_map.md) row: *Code inside the DB*
- [counting_and_summaries](../patterns/counting_and_summaries/README.md): why
  summary tables exist
