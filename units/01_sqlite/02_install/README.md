# 02 — Install & verify: SQLite

> **Fixed question:** Can I run it and prove it's running?
>
> **Student artifact:** Output of the verify commands below

## Docker? Not for SQLite, and here's why

Every other engine in the field guide gets a Docker path *and* a native path.
SQLite gets neither in the usual sense: **there is no server to run.** The
engine is a library, and you already have it. Python ships with SQLite
compiled in. The only thing you install is the `sqlite3` **command-line
shell**, and that's optional for Python work but required for this unit.

## Install the CLI

| Platform        | Command                                                                                                                                        |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS           | Ships at `/usr/bin/sqlite3` (often a bit old). Newer: `brew install sqlite`, installed "keg-only" at `$(brew --prefix)/opt/sqlite/bin/sqlite3` |
| Debian / Ubuntu | `sudo apt install sqlite3`                                                                                                                     |
| Fedora          | `sudo dnf install sqlite`                                                                                                                      |
| Windows         | `winget install SQLite.SQLite`, or the "sqlite-tools" bundle from <https://sqlite.org/download.html>                                           |

**Required version: 3.37 or newer.** That covers everything this unit uses
(`.import --csv --skip`, `.mode box`, `STRICT` tables, `RETURNING`).

## Verify

```bash
sqlite3 --version
python3 -c "import sqlite3; print(sqlite3.sqlite_version)"
sqlite3 :memory: "SELECT 'it works', sqlite_version();"
```

> **Two copies of SQLite.** The CLI and Python's `sqlite3` module are
> *separate builds* of the same library. They can be different versions with
> different features compiled in. Always check both, and when a query works in
> one and not the other, compare versions first.

## Already built in (no install needed)

These are often assumed to be add-ons, but the official builds, Homebrew, and
CPython all include them:

| Feature                      | Since              | You'll meet it in                                               |
| ---------------------------- | ------------------ | --------------------------------------------------------------- |
| Window functions             | 3.25               | Q06, Q07                                                        |
| CTEs (`WITH`)                | 3.8.3              | Q06, Q07, Q14                                                   |
| `RETURNING`                  | 3.35               | Q15                                                             |
| `STRICT` tables              | 3.37               | [§4](../04_model/)                                              |
| JSON functions, `->` / `->>` | on by default 3.38 | concept comparison with MongoDB                                 |
| FTS5 full-text search        | module             | [full_text_search](../../../patterns/full_text_search/) pattern |
| R\*Tree index                | module             | spatial track                                                   |

## Optional

- **A GUI**: [DB Browser for SQLite](https://sqlitebrowser.org/) or the VS Code
  SQLite extensions are handy for looking at data. They're not required, and
  [QueryMux](../../../00_setup/querymux.md) covers day-to-day querying.
- **Extension bundles** (`sqlean`), encryption (SQLCipher), and spatial
  (SpatiaLite) exist but aren't used in this unit.

## Your artifact

Paste the output of the three verify commands. If your CLI and Python versions
differ, note both.
