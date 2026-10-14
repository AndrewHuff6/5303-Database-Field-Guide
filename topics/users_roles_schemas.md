# Users, Roles, and Schemas

Who can connect, what they can touch, and how names are organized inside a
database. This is where the five engines differ most, and where PostgreSQL
surprises people coming from SQLite or MySQL.

## The vocabulary

| Term              | Meaning                                                                                   |
| ----------------- | ----------------------------------------------------------------------------------------- |
| **Authentication** | Proving who you are: a password, a certificate, or "you're the OS user `griffin`."      |
| **Authorization**  | Deciding what you may do once you're in: read this table, write that one.               |
| **User**           | An identity that can log in.                                                             |
| **Role**           | A named bundle of permissions. In some engines a user *is* a role.                       |
| **Privilege**      | One permission on one object: `SELECT` on `purchases`, `CREATE` in a schema.             |
| **Namespace**      | A container for names, so two things can share a name without colliding.                |

### "Schema" means three different things

| Where                    | "Schema" means                                                                      |
| ------------------------ | ----------------------------------------------------------------------------------- |
| Everyday database talk   | The **design**: the tables, columns, types, and keys. "Draw the schema."            |
| SQLite                   | The design, too: `.schema` prints the `CREATE` statements.                          |
| MySQL                    | **A database.** `CREATE SCHEMA` and `CREATE DATABASE` are the same command.         |
| PostgreSQL, DuckDB       | **A namespace inside a database**: a folder of tables. `public` (Postgres) or `main` (DuckDB) is the default. |

When a MySQL user runs `CREATE SCHEMA store` in Postgres, they expect a new
database. They get a folder inside the current one.

## How each engine does it

| Engine   | Who logs in                                  | What gets permissions                         | Names are organized as                        |
| -------- | -------------------------------------------- | --------------------------------------------- | --------------------------------------------- |
| SQLite   | Nobody. No accounts.                         | The file, via OS permissions                  | file → table (`ATTACH` adds more files)       |
| Postgres | Roles with `LOGIN`                           | database, schema, table, column, even row     | cluster → database → schema → table           |
| MongoDB  | Users, stored in an authentication database  | database or collection, per action            | deployment → database → collection            |
| Redis    | ACL users (6.0+), plus a `default` user      | commands, key patterns, pub/sub channels      | numbered databases (0–15) and key prefixes    |
| DuckDB   | Nobody. No accounts.                         | The file, via OS permissions                  | file (catalog) → schema → table               |

### SQLite and DuckDB: the file is the permission

Both are libraries inside your program, so there's no server to log in to.
If the operating system lets you read the file, you can read every table.
Read-only access means opening the file read-only. That's not a missing
feature: a phone app's database has exactly one user, the app.

DuckDB does have schemas in the Postgres sense (`CREATE SCHEMA staging;`,
then `staging.raw_people`), just no users to grant them to.

### PostgreSQL: everything is a role

- **A user is a role with `LOGIN`.** `CREATE USER api` is shorthand for
  `CREATE ROLE api LOGIN`.
- **A group is a role other roles belong to.** `GRANT readers TO api` gives
  `api` everything `readers` has.
- **Roles belong to the whole cluster**, not one database, so the same role
  can connect to any database it's been granted.
- **Every object has an owner**, the role that created it. The owner can do
  anything to it, including things `GRANT` can't give away, like `DROP`.

Permissions are layered. To read `store.purchases`, a role needs **all
three**:

| Level    | Privilege                                  |
| -------- | ------------------------------------------ |
| database | `CONNECT`                                  |
| schema   | `USAGE` on `store` (to see inside it)      |
| table    | `SELECT` on `store.purchases`              |

Two things trip people up:

- **`search_path`** decides which schemas an unqualified name is looked up in.
  By default it's `"$user", public`, so `SELECT * FROM purchases` looks in a
  schema named after you, then `public`. A table in `store` needs
  `store.purchases`, or `SET search_path = store, public`.
- **PostgreSQL 15 changed `public`.** Before 15, every role could create
  tables in `public`. From 15 on, only the database owner can, by default. A
  tutorial written for an older version fails with
  `permission denied for schema public`.

And one thing hides all of it: **Docker's `POSTGRES_USER` is a superuser.**
If your API connects as that user, nothing is ever denied, and you never see
any of the above.

### MongoDB: users live in a database

A user is created **in** a database, usually `admin`, and that's where it
authenticates. Roles grant actions (`find`, `insert`, ...) on resources (a
database or one collection). Built-in roles cover most needs: `read`,
`readWrite`, `dbAdmin`, `root`.

Access control is **off** unless the server is started with it on. The
official Docker image turns it on when you set `MONGO_INITDB_ROOT_USERNAME`.

### Redis: users are command filters

Redis ACLs say which **commands** a user may run and which **keys** they may
touch:

```
ACL SETUSER reporter on >secret ~stats:* +@read
```

`reporter` can run read commands, only on keys starting with `stats:`. With
no ACL setup, everyone is the `default` user, with every permission. Redis
has no tables or schemas; keys are organized by naming convention
(`customer:7`, `cart:7`).

## Try it: a read-only role for the API

An API that only reads shouldn't connect as a superuser. In Postgres:

```bash
docker run --name pg-roles -e POSTGRES_PASSWORD=pw -d postgres:17
docker exec -it pg-roles psql -U postgres
```

```sql
CREATE DATABASE shop;
\c shop
CREATE SCHEMA store;
CREATE TABLE store.purchases (purchase_id int PRIMARY KEY, amount numeric);
INSERT INTO store.purchases VALUES (1, 9.99);

CREATE ROLE api_reader LOGIN PASSWORD 'pw';
GRANT CONNECT ON DATABASE shop TO api_reader;
GRANT SELECT ON store.purchases TO api_reader;   -- note what's missing

\c shop api_reader
SELECT * FROM store.purchases;
INSERT INTO store.purchases VALUES (2, 1.00);
```

**Before running the last two statements, predict** which one fails and
what the error says. Then run them. If your prediction was wrong, the
"layered permissions" table above is why. Fix it with one more `GRANT`, run
as `postgres`, so that the `SELECT` works and the `INSERT` still fails.

Useful `psql` commands: `\du` (roles), `\dn+` (schemas and their
privileges), `\dp store.*` (table privileges), `\conninfo` (who am I).

```bash
docker rm -f pg-roles    # clean up
```

## See also

- [Concept map](../concept_map.md) rows: *Top-level container*, *Namespace
  inside it*, *Who are the users?*, *Permission granularity*
- [SQLite vs. PostgreSQL](sqlite_vs_postgres.md)
- [SQLite 09: scenario 7](../units/01_sqlite/09_when/README.md), several
  applications sharing one database with different permissions
