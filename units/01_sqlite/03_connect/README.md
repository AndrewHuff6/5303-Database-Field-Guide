# 03 — Connect three ways: SQLite

> **Fixed question:** The same "hello" query from the CLI, QueryMux, and Python.
>
> **Student artifact:** The hello query's output from all three

Every unit runs the same **hello query** three ways. For the `store` dataset:

```sql
SELECT department, COUNT(*) AS purchases
FROM purchases
GROUP BY department
ORDER BY purchases DESC
LIMIT 5;
```

Build the classroom database first ([§5](../05_load/)), then work from
`units/01_sqlite/05_load/`.

---

## 1. The CLI: `sqlite3`

```bash
sqlite3 store_classroom.db
```

```
sqlite> .mode box
sqlite> .headers on
sqlite> SELECT department, COUNT(*) AS purchases FROM purchases GROUP BY department ORDER BY purchases DESC LIMIT 5;
sqlite> .quit
```

### Two kinds of lines

The `sqlite>` prompt (and any `.sql` script) accepts two different things:

1. **SQL statements** such as `SELECT`, `CREATE TABLE` and `INSERT`. They end
   with `;`. Any SQLite driver in any language runs these.
2. **Dot commands** such as `.read`, `.mode` and `.import`. They start with `.`
   in column 1, take the **whole line** (no `;`, no trailing `-- comment`),
   and belong to the *shell only*. Python's `sqlite3` module doesn't
   understand them.

`PRAGMA foreign_keys = ON;` looks like a setting but **is SQL**: a
SQLite-specific statement that any driver can run.

### Four ways to feed it a script

```bash
sqlite3 store_classroom.db                              # (a) interactive, then .read file.sql
sqlite3 store_classroom.db ".read rebuild.sql"          # (b) one command as an argument
sqlite3 store_classroom.db < rebuild.sql                # (c) redirect a file onto stdin
sqlite3 store_classroom.db <<'EOF'                      # (d) heredoc
.mode box
SELECT * FROM departments LIMIT 3;
EOF
```

> **Common mistake:** `store_classroom.db < script.sql` does nothing useful.
> `<` feeds a file to a *program*, and a `.db` file isn't a program. Always
> name `sqlite3` first.

### Dot commands you'll use constantly

| Command                                                | Use                                                                 |
| ------------------------------------------------------ | ------------------------------------------------------------------- |
| `.tables` / `.schema purchases` / `.indexes purchases` | What's in here?                                                     |
| `.mode box` + `.headers on`                            | Readable output                                                     |
| `.read FILE`                                           | Run a script (paths are relative to where you *launched* `sqlite3`) |
| `.eqp on`                                              | Print the query plan before every query ([§7](../07_explain/))      |
| `.timer on`                                            | Print how long every statement took                                 |
| `.bail on`                                             | Stop a script at the first error                                    |
| `.dump`                                                | Emit SQL that rebuilds the database (a text backup)                 |

---

## 2. QueryMux

```bash
querymux --backend sqlite --db store_classroom.db
```

Type the hello query on the left and press **F5**. Rows appear on the right.
The same keys work for every engine in the course. Only the query language
changes.

> QueryMux runs SQL only. Dot commands such as `.tables` are `sqlite3` shell
> features, so use the SQL equivalent instead:
> `SELECT name FROM sqlite_master WHERE type = 'table';`

---

## 3. Python

```python
import sqlite3

con = sqlite3.connect("store_classroom.db")
con.row_factory = sqlite3.Row                 # rows behave like dicts
con.execute("PRAGMA foreign_keys = ON")       # every connection, every time

rows = con.execute("""
    SELECT department, COUNT(*) AS purchases
    FROM purchases
    GROUP BY department
    ORDER BY purchases DESC
    LIMIT :n
""", {"n": 5}).fetchall()

for r in rows:
    print(r["department"], r["purchases"])
con.close()
```

What to notice:

- **Placeholders.** `:name` (with a dict) or `?` (with a tuple). **Never**
  paste values into the SQL string; that's how SQL injection happens.
- **No server, no password.** `connect()` opens a file. If the file doesn't
  exist, SQLite *creates an empty one*, so a typo in the path gives you a
  blank database instead of an error.
- **`PRAGMA foreign_keys = ON`** is per connection. Forget it, and foreign
  keys are silently not enforced.

## Your artifact

The hello query's output from all three. They should match exactly. If they
don't, the most likely cause is that you opened a different (possibly empty)
file. Check the path.
