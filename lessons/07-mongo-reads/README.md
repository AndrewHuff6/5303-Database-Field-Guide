# 07 – Replace hard-coded responses with MongoDB queries

**The page doesn't change in this lesson.** `index.html` is lesson 06b with a
new title; run `diff ../06-first-fastapi/06b-load-with-x-init.html index.html`
to check. Only `api.py` changes: the routes keep their URLs and their JSON
shape, but the data now comes from MongoDB instead of Python lists.

## Run it

```bash
cd lessons/07-mongo-reads
python api.py
```

| URL                                         | Shows                                           |
| ------------------------------------------- | ----------------------------------------------- |
| http://127.0.0.1:8000                       | The purchase form, now with all 500 customers and 100 products |
| http://127.0.0.1:8000/api/customers         | Customers from MongoDB as `{id, name}`          |
| http://127.0.0.1:8000/api/products          | Products as `{id, name, price}`                 |
| http://127.0.0.1:8000/api/examples/raw-products | **A 500 error, on purpose** (see below)     |
| http://127.0.0.1:8000/api/examples/monthly-sales | Converting `ObjectId` and `Decimal128`     |

## Connecting

```python
client = MongoClient(os.getenv("MONGO_URL", "mongodb://localhost:27017"))
db = client[os.getenv("MONGO_DB", "noidx_10k")]
```

- The connection is made **once**, when `api.py` starts, and shared by every
  request. Don't connect inside a route.
- `os.getenv("MONGO_DB", "noidx_10k")` reads an environment variable, or uses
  the default. That lets you point the same code at a copy of the database.
- `db.customers` selects the `customers` collection. `db["customers"]` does the same.

## Querying: `find(filter, projection)`

```python
db.customers.find({}, {"first_name": 1, "last_name": 1}).sort([("last_name", 1), ("first_name", 1)])
```

| Part                                  | Meaning                                                       |
| ------------------------------------- | ------------------------------------------------------------- |
| `{}` (filter)                         | Which documents. Empty = all. `{"state_code": "TX"}` would be only Texans. |
| `{"first_name": 1, "last_name": 1}`   | **Projection**: which fields come back. `_id` is included unless you add `"_id": 0`. |
| `.sort([("last_name", 1), ...])`      | `1` = ascending, `-1` = descending. A list sorts by several fields in order. |
| `.limit(n)`                           | At most `n` documents.                                        |

`find()` returns a **cursor**, which hands documents over one at a time as you
loop. The list comprehension `[customer_out(doc) for doc in docs]` loops over
it and converts each one.

The projection matters: without it every customer would include their
`cards` array and card numbers. Send the browser only what it needs.

## Converting documents: the `_out` functions

```python
def customer_out(doc):
    return {"id": doc["_id"], "name": f"{doc['first_name']} {doc['last_name']}"}

def product_out(doc):
    return {"id": doc["_id"], "name": doc["product_name"], "price": str(doc["unit_price"])}
```

The page expects `{id, name}` and `{id, name, price}`, the shape lesson 06
sent. MongoDB stores `_id`, `first_name`/`last_name`, `product_name` and
`unit_price`. These small functions translate between the two, so the
database's field names never leak into the page.

### Why they're necessary

Open http://127.0.0.1:8000/api/examples/raw-products. It fails with
**500 Internal Server Error**, and the terminal shows
`TypeError: 'Decimal128' object is not iterable`. FastAPI knows how to turn
Python's `int`, `str`, `list`, `dict`, `float`, `bool` and `None` into JSON,
but `Decimal128` (and `ObjectId`) are BSON types from MongoDB that it doesn't
know. Convert them yourself:

| BSON type     | Example value                         | Convert with | JSON result                  |
| ------------- | ------------------------------------- | ------------ | ---------------------------- |
| `Decimal128`  | `Decimal128('202.11')`                | `str(x)`     | `"202.11"`                   |
| `ObjectId`    | `ObjectId('6ad664be1034af039c5af658')`| `str(x)`     | `"6ad664be1034af039c5af658"` |
| `datetime`    | `ISODate('2026-04-30…')`              | (automatic)  | `"2026-04-30T00:00:00"`      |
| `int` `_id`   | `1`                                   | (nothing)    | `1`                          |

`noidx_10k` uses integer `_id`s for customers, products and purchases, so only
prices need converting. `monthly_sales` uses `ObjectId`s, so
`/api/examples/monthly-sales` shows that conversion too.

## Something to notice in the dropdown

Scroll the customer list: there are **three different "Dennis Allen"s**
(IDs 90, 301 and 373). This is why lesson 05 insisted on storing IDs. The
dropdown text is ambiguous, but the submitted `value` isn't.

## Activity

1. Change `get_customers()` to show only customers from one state
   (`{"state_code": "TX"}`). Reload the page. Nothing in the HTML changed.
2. Make the duplicate names distinguishable: change `customer_out` to return
   `"Dennis Allen (#90)"` as the name.
3. Change `/api/examples/monthly-sales` to return only `"Books"` rows, sorted
   by revenue, highest first.

## Checkpoint

**Why should switching from a Python list to MongoDB not require changing the
dropdown?** What exactly do the two sides of `fetch('/api/customers')` have to
agree on?
