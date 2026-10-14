# Full-Text Search

> **Queries:** Q16 (proposed: needs a table of text worth searching, such as
> `reviews` or the people_products `description`)
>
> **The idea:** Finding words inside text: `LIKE '%x%'` vs. an inverted index

## The problem (engine-neutral)

"Find products whose name mentions *blender*" looks simple:

```sql
SELECT * FROM products WHERE product_name LIKE '%blender%';
```

A normal index can't help. A B-tree is sorted by the **start** of each
string, so it can find names that *begin* with something. With a leading
`%`, a match could be anywhere in the sort order, so every row has to be read
and tested.

A **full-text index** flips the problem around. Instead of storing
"row → text," it stores **token → list of rows**:

```
"blender"   → 17, 342, 4410
"portable"  → 17, 99, 2051, 3020
"kettle"    → 88, 342
```

Finding a word is now a lookup, no matter where in the text it appears.

### It matches words, not substrings

That's the most important difference, and it changes the answer:

| Search                         | `LIKE '%ove%'`             | full-text `ove`           |
| ------------------------------ | -------------------------- | ------------------------- |
| matches "lovelace"             | yes: the letters are in it | no: "ove" isn't a word    |
| matches "Oven"                 | depends on case rules      | no                        |
| matches "oven" in "Dutch Oven" | yes                        | only if you search `oven` |

Full-text search adds things `LIKE` can't do: `AND`/`OR`/`NOT`, prefix
search (`blend*`), phrases, and **ranking** results by relevance. Before you
switch, decide which behavior your endpoint promises.

### It has to be kept current

The index is a second structure. When the text changes, the index must
change too, either automatically or by your own triggers or rebuild jobs.
That's extra work on every write.

## SQLite

**Fit: ✓** with FTS5. Script: [sqlite.sql](sqlite.sql). The examples search
`customers` (50k rows in `idx_1m`).

**When can `LIKE` use a normal index?** Only when the pattern pins down the
start, *and* the index's collation matches `LIKE`'s case rules:

| Pattern                                                | Can seek?                                  | Why                                                                                                                |
| :----------------------------------------------------- | :----------------------------------------- | :----------------------------------------------------------------------------------------------------------------- |
| `LIKE '%hopper%'`                                      | ❌                                          | Leading wildcard: a match could be anywhere in the sort order                                                      |
| `email LIKE 'grace%'` on a normal index                | ❌                                          | SQLite's `LIKE` is case-**in**sensitive, but the index is sorted case-sensitively, so a seek could miss `'Grace…'` |
| `last_name LIKE 'Hop%'` with an index `COLLATE NOCASE` | ✅ `SEARCH … (last_name>? AND last_name<?)` | Collation matches, so the prefix becomes a range                                                                   |
| `last_name LIKE '%per'` with the same index            | ❌                                          | Leading wildcard again. It scans the (smaller) index                                                               |

**FTS5** is SQLite's inverted index:

```sql
CREATE VIRTUAL TABLE customers_fts USING fts5(
    first_name, last_name, email,
    content = 'customers', content_rowid = 'customer_id'   -- external content
);
INSERT INTO customers_fts(customers_fts) VALUES ('rebuild');   -- index existing rows

SELECT c.* FROM customers_fts f JOIN customers c ON c.customer_id = f.rowid
WHERE customers_fts MATCH 'grace AND hop*'   -- boolean ops, prefix queries
ORDER BY f.rank                              -- bm25 relevance
LIMIT 5;
```

- **External content** (`content='customers'`) stores only the index, not a
  second copy of the text. Join back by rowid for the other columns.
- **Tokens, not substrings.** The default tokenizer splits
  `grace.hopper.45@example.com` into `grace | hopper | 45 | example | com`.
  `MATCH 'ove'` finds **0** rows, while `LIKE '%ove%'` finds 2,494.
- **Indexed substring search** is available with `tokenize='trigram'`. It
  indexes every 3-character slice, and plain `LIKE '%ove%'` then uses it. The
  index is bigger, and patterns under 3 characters fall back to a scan.
- **It doesn't update itself.** With external content you add
  `AFTER INSERT/UPDATE/DELETE` triggers (in the script), or the index goes
  stale. That's extra work on every write.
- **The build is a one-time cost**: about 35 ms here, about 320 ms for trigram.
  The plan reads `SCAN customers_fts VIRTUAL TABLE INDEX 0:M…`. For a virtual
  table, "SCAN" just means "asked the module," and the module did an index
  lookup.

## DuckDB

**Fit: ~.** The `fts` extension builds an index (`PRAGMA create_fts_index`)
and ranks with `match_bm25`. The index **doesn't update** when the table
changes; you rebuild it. That fits DuckDB's batch-loaded analytics, not a
table that changes all day.

## PostgreSQL

**Fit: ✓.** Built in: `to_tsvector('english', text) @@ to_tsquery('blend:*')`
with a **GIN** index, ranked by `ts_rank`. It also handles language rules
such as stemming ("blenders" matches "blender"). For substring search, the
`pg_trgm` extension gives `LIKE '%x%'` an index, like SQLite's trigram
tokenizer.

## MongoDB

**Fit: ✓.** A **text index** (one per collection) answers
`{ $text: { $search: "blender" } }` with a relevance score. Atlas, the cloud
service, adds a separate, much richer search engine.

## Redis

**Fit: ✓** with the **Redis Query Engine** (built into Redis 8; a separate
module in older versions): `FT.CREATE` defines an index over hashes or JSON,
and `FT.SEARCH` queries it, kept current as keys change.

## In the catalog

Nothing yet. **Q16** is proposed for when the dataset has text worth
searching: reviews, or the product descriptions in
[people_products](../../../datasets/people_products/README.md).
