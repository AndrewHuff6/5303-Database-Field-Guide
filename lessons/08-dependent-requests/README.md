# 08 – Dependent requests and form updates

Until now the page made its requests once, on load. Now **choosing something
triggers a request**, and the answer depends on what was chosen:

| Route                                        | Trigger                  | Result on the page                |
| -------------------------------------------- | ------------------------ | --------------------------------- |
| `GET /api/products/{product_id}`             | Product dropdown changes | Price and how often it's been bought |
| `GET /api/customers/{customer_id}/purchases` | Customer dropdown changes | Their 10 most recent purchases   |

## Run it

```bash
cd lessons/08-dependent-requests
python api.py
```

Then try these directly in the browser:

- http://127.0.0.1:8000/api/products/1 (a real product)
- http://127.0.0.1:8000/api/products/999 (404: no such product)
- http://127.0.0.1:8000/api/products/abc (422: not an integer)
- http://127.0.0.1:8000/api/customers/1/purchases

## Server: path parameters

```python
@app.get("/api/products/{product_id}")
def get_product(product_id: int):
    doc = db.products.find_one({"_id": product_id})
    if doc is None:
        raise HTTPException(status_code=404, detail=f"Product {product_id} not found")
    ...
```

| Code                          | Meaning                                                              |
| ----------------------------- | -------------------------------------------------------------------- |
| `{product_id}` in the path    | A placeholder. `/api/products/7` calls the function with `product_id=7`. |
| `product_id: int`             | FastAPI converts `"7"` to `7`. If it can't (`abc`), it answers **422** without running your function. The conversion also matters for Mongo: `_id` is stored as the number `7`, and `{"_id": "7"}` would match nothing. |
| `find_one(filter)`            | The first matching document, or `None`.                              |
| `raise HTTPException(404, …)` | Stop and send an error status with a message: `{"detail": "Product 999 not found"}`. |
| `count_documents(filter)`     | How many documents match.                                            |

The history route sorts by `[("purchase_date", -1), ("_id", -1)]`: newest
first, and the `_id` breaks ties between purchases on the same day so the order
is stable.

### Empty is not the same as missing

```python
if db.customers.find_one({"_id": customer_id}, {"_id": 1}) is None:
    raise HTTPException(status_code=404, ...)
docs = db.purchases.find({"customer_id": customer_id})...
```

| Situation                        | Answer           | Page shows                  |
| -------------------------------- | ---------------- | --------------------------- |
| Customer exists, has purchases   | `200` + `[…]`    | The table                   |
| Customer exists, no purchases    | `200` + `[]`     | "No purchases yet."         |
| No such customer                 | `404`            | An error message            |
| Server down / Mongo down         | network error / `500` | An error message       |

Without the existence check, a typo'd ID would quietly look like a customer
with no purchases.

`purchase_out` converts `purchase_date` (a Python `datetime`) to just the date
with `.date().isoformat()`, giving `"2026-04-30"`.

## Page: reacting to a selection

```html
<select x-model.number="productId" @change="loadProduct()" :disabled="loading || productLoading">
```

`x-model` updates `productId` first, then `@change` calls `loadProduct()`,
which reads the new `this.productId`.

Every dependent loader follows the same four steps:

```js
async loadProduct() {
    this.product = null;          // 1. clear stale data immediately
    this.productError = '';
    if (!this.productId) return;  // 2. "Choose a product" → stop here

    this.productLoading = true;   // 3. show "Loading…", disable the dropdown
    try {
        this.product = await getJSON(`/api/products/${this.productId}`);
    } catch (err) {
        this.productError = `Could not load product: ${err.message}`;
    } finally {
        this.productLoading = false;  // 4. always re-enable
    }
}
```

**Why clear first?** If the user switches from the keyboard to the blender and
the request is slow, the page would otherwise show the blender selected next to
the keyboard's price.

### New directive: `x-if`

```html
<template x-if="product">
    <div> … <span x-text="product.name"></span> … </div>
</template>
```

| Directive | When false…                              | Use it when                                    |
| --------- | ---------------------------------------- | ---------------------------------------------- |
| `x-show`  | The element stays in the page, hidden    | Toggling something often; nothing inside can fail |
| `x-if`    | The element is **removed** entirely      | The inside reads properties of something that may be `null` |

With `x-show`, Alpine would still evaluate `product.name` while `product` is
`null` and log errors. Like `x-for`, `x-if` must be on a `<template>` with one
child.

### `null` vs `[]` on the page

`history` starts as `null` ("not loaded"), not `[]` ("loaded, none"), so the
page can tell the two apart:

```html
<p x-show="history !== null && history.length === 0">No purchases yet.</p>
<template x-for="purchase in history ?? []" …>
```

`history ?? []` means "use `history`, or an empty array if it's `null`".

### Better error messages

`getJSON` now reads the body even on failure and uses FastAPI's `detail` text
when it's a string, so the page says "Product 999 not found" instead of
"answered 404".

### What changed in `product`

In lessons 05–07, `product` was a getter that looked up the selected item in
the `products` array. Now `product` is **state**, filled by `loadProduct()`.
The total uses the price from that request, which is the freshest price the
server has given.

## Activity

Selecting a product should update its price and purchase count, and the
estimated total should follow the quantity. Then extend it:

1. Add the customer's email and state to the history section. You'll need a
   new route, `GET /api/customers/{customer_id}`, returning those fields.
2. Show the total amount of the listed purchases under the table (a getter
   that adds `toCents(p.amount)` for each).

## Checkpoint

**What should the page display if the user goes back to "Choose a product"?**
Find the line in `loadProduct()` that handles it. What would go wrong
without step 1 (clearing first)?
