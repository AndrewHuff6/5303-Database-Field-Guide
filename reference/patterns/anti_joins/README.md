# Anti-Joins

> **Queries:** Q08
>
> **The idea:** "Rows with no match": `NOT EXISTS`, `LEFT JOIN … IS NULL`, `NOT IN`

## The problem (engine-neutral)

An ordinary join finds rows that **have** a partner. An **anti-join** finds
rows that **don't**: products never bought, customers who never bought a
book, states where a product never sold.

```
All products                 Products bought in TX

[A][B][C][D][E][F]           [B][D][F]
          anti-join result
                ↓
            [A][C][E]
```

Proving that something *doesn't* exist is the expensive part. A partner can
be confirmed the moment one is found, but "no partner" means checking
everywhere a partner could be. So the cost is:

> **(number of outer rows) × (cost of proving there's no partner)**

The whole job is making that proof cheap: ideally one index seek per outer
row.

### Three spellings, one trap

```sql
-- NOT EXISTS: the clearest statement of intent
WHERE NOT EXISTS (SELECT 1 FROM purchases pu WHERE pu.product_id = pr.product_id)

-- LEFT JOIN … IS NULL: keep the outer rows whose join found nothing
LEFT JOIN purchases pu ON pu.product_id = pr.product_id WHERE pu.purchase_id IS NULL

-- NOT IN: be careful
WHERE product_id NOT IN (SELECT product_id FROM purchases)
```

**The `NOT IN` trap:** if the subquery returns even one `NULL`,
`x NOT IN (…)` is never true, so you silently get **zero rows**.
`SELECT 3 NOT IN (1, 2, NULL)` is `NULL`, not true. `NOT EXISTS` has no such
trap, which makes it the safe default.

### Which direction does the probe go?

There are two ways to answer "products never bought in a state," and each
wants a different index:

| Strategy                                                              | Starts from            | Helpful index on `purchases`      |
| --------------------------------------------------------------------- | ---------------------- | --------------------------------- |
| For each product, probe: "any purchase of it in this state?"          | every product          | `(product_id, …)`                 |
| Build the set of products bought in the state **once**, then subtract | customers in the state | `(customer_id, product_id)`       |

```sql
-- build-once version
WITH bought_here AS (
    SELECT DISTINCT pu.product_id
    FROM zipcodes z
    JOIN customers c  ON c.zipcode = z.zipcode
    JOIN purchases pu ON pu.customer_id = c.customer_id
    WHERE z.state_code = :state
)
SELECT pr.product_id, pr.product_name
FROM products pr
LEFT JOIN bought_here b ON b.product_id = pr.product_id
WHERE b.product_id IS NULL;
```

Neither is always better. It depends on how many outer rows there are, how
selective each probe is, and what the plan actually does. Measure, don't
guess.

## SQLite

**Fit: ✓.** Script: [sqlite.sql](sqlite.sql). These numbers are from
`idx_1m`.

SQLite runs `NOT EXISTS` as a correlated subquery: one probe per outer row.
What matters is what each probe costs:

| Question                                                 | Probe plan                                                                                         |   Time |
| :------------------------------------------------------- | :------------------------------------------------------------------------------------------------- | -----: |
| Products never sold (5,000 outer rows)                   | `SEARCH pu USING COVERING INDEX idx_purchases_product (product_id=?)`: one seek each               |   6 ms |
| Customers who never bought **Books** (50,000 outer rows) | `SEARCH pu USING INDEX idx_purchases_customer (customer_id=?)`, then reads **every** purchase of that customer to check its department | 451 ms |
| Same, with index `(customer_id, department)`             | `SEARCH … COVERING INDEX (customer_id=? AND department=?)`: one seek each                          |  32 ms |

The middle row is where skew hurts. Each probe costs that customer's
purchase count, and one customer has about 28,000. A composite index
**containing every column the probe tests with `=`** turns each probe back
into a single seek.

When the partner is several joins away (purchase → customer → zipcode →
state), the probe becomes a join inside `NOT EXISTS`. Read that plan closely:
which table does the probe *start* from, does every step `SEARCH`, and how
many outer rows multiply it?

## DuckDB

**Fit: ✓.** DuckDB *decorrelates* subqueries: it rewrites `NOT EXISTS` into
a hash **anti join** that builds the partner set once, instead of probing per
row. It also accepts the operation by name:

```sql
SELECT pr.* FROM products pr ANTI JOIN purchases pu ON pu.product_id = pr.product_id;
```

`SEMI JOIN` is the opposite: rows that *do* have a partner.

## PostgreSQL

**Fit: ✓.** The planner turns `NOT EXISTS` and `LEFT JOIN … IS NULL` into a
`Hash Anti Join` or `Merge Anti Join`, and `EXPLAIN` names it. It does **not**
do that for `NOT IN`, which also has the `NULL` trap. In Postgres especially,
prefer `NOT EXISTS`.

## MongoDB

**Fit: ~.** There's no join to negate. Either `$lookup` the partners and keep
documents whose looked-up array is empty:

```js
{ $lookup: { from: "purchases", localField: "_id", foreignField: "product_id", as: "p" } },
{ $match:  { p: { $size: 0 } } }
```

or collect the partner ids first (`distinct`) and query with `$nin`. Both work,
and neither is how MongoDB wants to be used. If "never bought in a state" is
a common question, store the answer in the documents.

## Redis

**Fit: ~.** Redis has no joins, but if you maintain sets, an anti-join is
**set difference**:

```
SDIFF products:all products:bought:TX
```

That's instant to read. The cost moved to the writes: every purchase must
also `SADD` the product to its state's set.

## In the catalog

**Q08**, products never bought in a state, is the *build-once vs. probe*
question with the partner three joins away. Its **Think about it** prompt in
[SQLite 06](../../../engines/01_sqlite/06_queries/q08.sql) asks how each database
proves "no partner." Answer it from your own plans and timings.
