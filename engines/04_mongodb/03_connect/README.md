# 03 — Connect three ways: MongoDB

> **Fixed question:** The same "hello" query from the CLI, a GUI, and Python.
>
> **Student artifact:** The hello query's output from each way you can run it

The hello query asks the same thing as in every other engine: how many
purchases, and their total. There's no SQL, so it's an **aggregation
pipeline**: a list of stages, each one transforming the documents the
previous one produced.

```js
db.purchases.aggregate([
  { $group: { _id: null, purchases: { $sum: 1 }, revenue: { $sum: "$amount" } } }
])
```

Read it as SQL's `SELECT count(*), sum(amount) FROM purchases`: `$group` with
`_id: null` puts every document in one group; `"$amount"` (with the `$`)
means "the value of the field `amount`".

Run it against the `idx_10k` **database**. In MongoDB, each experiment
database really is a separate database ([§5](../05_load/)).

## 1. mongosh

```bash
mongosh "mongodb://localhost:27017/?directConnection=true"
```

```js
show dbs
use idx_10k
show collections
db.purchases.findOne()
db.purchases.aggregate([{ $group: { _id: null, purchases: { $sum: 1 }, revenue: { $sum: "$amount" } } }])
db.customers.findOne({ _id: 7 })
exit
```

`mongosh` is a JavaScript shell: `db` is the current database, and every
collection is a property of it (`db.purchases`). `findOne()` shows one whole
document. Look at how a customer's cards appear: inside the customer, as a
list.

## 2. A GUI: MongoDB Compass

QueryMux doesn't speak MongoDB yet (see [setup/querymux.md](../../../setup/querymux.md)).
Use **MongoDB Compass** instead: connect with the same URL, open
`idx_10k` → `purchases` → **Aggregations**, and paste the pipeline's one
stage. Compass also has an **Explain** button: you'll use it in [§7](../07_explain/).

## 3. Python

```python
from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017/?directConnection=true")
db = client["idx_10k"]

print(list(db.purchases.aggregate([
    {"$group": {"_id": None, "purchases": {"$sum": 1}, "revenue": {"$sum": "$amount"}}}
])))

# a query is a dict, not a string: no placeholders, no SQL injection
print(db.customers.find_one({"_id": 7}))
```

Three differences from the SQL drivers:

- **A query is a Python dict.** Values go straight in; there's no SQL text
  and no `%(name)s` placeholders.
- **Values come back as BSON types.** `revenue` is a `Decimal128`, dates are
  `datetime` objects, and `_id` is whatever you stored there.
- **A collection you've never created already "exists".**
  `db.purchasez.find_one()` (a typo) returns `None` instead of an error.
  Watch for that.

## Your artifact

The hello query's output from all three, plus `db.customers.findOne({ _id: 7 })`.
Point out one thing in that document that would have taken a second table,
and a join, in SQLite.
