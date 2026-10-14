# Naming Conventions: Tables, Collections, Keys

Names for the things *inside* each database: SQL tables and columns, MongoDB
collections and fields, Redis keys. (Repo, file, and route naming live in
[STRUCTURE.md](../STRUCTURE.md).)

No database engine enforces any of this. A table, column, or key name is just
a string to SQLite, DuckDB, PostgreSQL, MongoDB, and Redis. Consistent naming
is for the people reading the schema later, not a rule the database checks.

## What this course uses

The [`store` schema](../datasets/store/schema.md) follows these rules. Copy
them when you design your own.

| Thing | Convention | Example from `store` |
| ----- | ---------- | -------------------- |
| Case | `snake_case`, all lowercase | `purchase_date`, `card_types` |
| Tables | plural: a table holds many rows | `customers`, `purchases` |
| Primary key (surrogate) | `<singular>_id` | `customers.customer_id` |
| Primary key (small lookup table) | the value itself | `states.state_code`, `departments.department` |
| Foreign key | **the same name** as the key it references | `purchases.customer_id` → `customers.customer_id` |
| Dates | `_date` suffix | `purchase_date` |
| Timestamps | `_at` suffix | `created_at` (none in `store` yet) |
| Booleans | a verb prefix | `is_active`, `has_paid` |
| Junction (many-to-many) table | both names | `student_course` |
| Views | what a row is | `purchase_details` |
| Summary tables | grain + measure | `monthly_sales` |
| Indexes | `idx_<table>_<columns>` | `idx_purchases_customer`, `idx_purchases_date_cust_amount` |
| MongoDB collections | same name as the table | `purchases` |
| Redis keys | `<entity>:<id>[:<field>]` | `customer:7` |

### Why `customer_id` and not just `id`

Many frameworks name every primary key `id`. This course doesn't, because a
foreign key then has the **same name in both tables**:

```sql
-- customer_id everywhere: the join reads itself, and USING works
SELECT * FROM purchases JOIN customers USING (customer_id);

-- id as the key: every join needs both names spelled out
SELECT * FROM purchases p JOIN customers c ON p.customer_id = c.id;
```

It also means a query that joins five tables never returns five columns all
called `id`. Both styles are common; pick one per schema and never mix them.

### Staging tables are the exception

Tables loaded straight from a raw file keep the file's names, made safe:
`staging_raw` in the `store` loaders, and the Armageddon tables from
[load_postgis.py](../datasets/armageddon/load_postgis.py) (`gid` key, every
property converted to `snake_case`). They're scratch space. Rename things
when you design the real schema.

## SQL: general rules

- **Pick one casing for the whole schema.** `snake_case` dominates in
  PostgreSQL, SQLite, and DuckDB; PascalCase shows up in SQL Server shops.
  Mixing styles is worse than consistently choosing the "wrong" one.
- **Avoid reserved words as names.** `order`, `group`, `select`, `table`,
  `user` are legal, but every reference then needs quoting, and the quote
  character differs by engine: double quotes in PostgreSQL, SQLite, DuckDB,
  and standard SQL; backticks in MySQL; square brackets in SQL Server.
- **Avoid abbreviations** unless everyone knows them, and avoid spaces and
  special characters. Both force quoting on every reference.

### The cross-engine gotcha: case

This is the one that bites when the same query runs on two engines, which is
the whole point of this course.

| Engine | `CREATE TABLE Users (Name text)` |
| ------ | -------------------------------- |
| SQLite | Stored as `Users`. `SELECT name FROM users` still works: matching ignores ASCII case |
| DuckDB | Same as SQLite: stored as `Users`, matched case-insensitively |
| PostgreSQL | **Folded to lowercase**: the table is `users`. Only `"Users"` in double quotes keeps the capital, and then every query must quote it too |
| MySQL | Depends on the server's operating system: case-sensitive on Linux, not on macOS or Windows by default |

Create a mixed-case table in SQLite and in PostgreSQL, then run the same
queries against both in QueryMux. It's a five-minute lesson on its own, and
the reason this course uses lowercase everywhere.

## MongoDB

- **No enforced schema.** Nothing stops one document from having `email` and
  the next from having `emailAddress`. In SQL, `CREATE TABLE` fixes the
  column names; in MongoDB, naming consistency is entirely up to you.
- **Field names can't start with `$`** (reserved for operators like `$gt`)
  and shouldn't contain `.` (dot notation addresses nested fields).
- **`_id` is reserved.** MongoDB generates an `ObjectId` if you don't supply
  one. You can supply your own: `_id: 7` for customer 7.
- **Collection and field names are case-sensitive.** No folding.
- **No reserved-word problem.** Fields are JSON keys, so a field named
  `"select"` is fine.

## Redis

- **No tables or collections**, just one flat namespace of keys. The
  convention is a colon-separated hierarchy that mimics `table:row:field`:
  `customer:7`, `customer:7:purchases`, `session:abc123`.
- **Keys are case-sensitive** and may contain any bytes, including spaces.
  Don't use that; it makes the CLI and debugging miserable.
- **Commands are a fixed vocabulary** (`GET`, `SET`, `HGETALL`), separate from
  key names. A key named `get` is just a key.

## Quick reference

| | Case sensitivity | Quoting a reserved or odd name |
| - | ---------------- | ------------------------------ |
| SQLite | Insensitive matching, stored as typed | `"name"` |
| DuckDB | Insensitive matching, stored as typed | `"name"` |
| PostgreSQL | Unquoted names folded to lowercase | `"name"` |
| MongoDB | Case-sensitive | Not needed: field names are JSON keys |
| Redis | Case-sensitive | Not needed: key names are data |
