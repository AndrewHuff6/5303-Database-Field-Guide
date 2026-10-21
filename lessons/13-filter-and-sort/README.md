# 13 – Filtering and sorting

The search route grows from one parameter to several:

```text
GET /api/products?q=lamp&min_price=50&max_price=200&sort=price_asc&limit=10
```

> **Why price instead of category?** `noidx_10k` products have no category
> field. `department` is recorded per purchase, and one product appears under
> many departments (lesson 01), so a price range is the filter this data
> actually supports.

## Run it

```bash
cd lessons/13-filter-and-sort
python api.py
```

The page loads the first 10 products by name on open (`x-init`). Every control
re-runs the search, and the exact URL requested is shown under the controls.

## Server

### Each parameter is optional and validated

```python
def get_products(
    q: str = "",
    min_price: Decimal | None = Query(default=None, ge=0),
    max_price: Decimal | None = Query(default=None, ge=0),
    sort: Literal["name", "price_asc", "price_desc"] = "name",
    limit: int = Query(default=100, ge=1, le=100),
):
```

| Parameter    | Type                    | Rejected with 422                       |
| ------------ | ----------------------- | --------------------------------------- |
| `q`          | text                    | (never)                                 |
| `min_price`  | `Decimal` or missing    | `abc`, `-1`                             |
| `max_price`  | `Decimal` or missing    | `abc`, `-1`                             |
| `sort`       | one of three words      | anything else, e.g. `unit_price`        |
| `limit`      | 1–100                   | `0`, `500`                              |

`Decimal | None = …default=None` means "a decimal number, or not given at
all". `Decimal` rather than `float` keeps `10.50` exact.

### Combining filters

```python
query = {}
if term:
    query["product_name"] = {"$regex": re.escape(term), "$options": "i"}

price = {}
if min_price is not None:
    price["$gte"] = Decimal128(min_price)
if max_price is not None:
    price["$lte"] = Decimal128(max_price)
if price:
    query["unit_price"] = price
```

The filter dict is built **one condition at a time**, and only the conditions
the user asked for are added. Every key in one MongoDB filter must match, so
the conditions are combined with AND. For `?q=lamp&max_price=200` the result is:

```python
{"product_name": {"$regex": "lamp", "$options": "i"},
 "unit_price": {"$lte": Decimal128("200")}}
```

`$gte` = greater than or equal, `$lte` = less than or equal. Both can sit in
one dict for a range. The prices are wrapped in `Decimal128` to match how
`unit_price` is stored.

### Mapping sort choices

```python
SORTS = {
    "name":       [("product_name", 1)],
    "price_asc":  [("unit_price", 1),  ("product_name", 1)],
    "price_desc": [("unit_price", -1), ("product_name", 1)],
}
...
.sort(SORTS[sort])
```

The browser picks a **name** for a sort order; the server translates it into
the actual database instruction. The second key breaks ties, so products with
equal prices always come back in the same order.

## Page

### Building parameters from state

```js
buildParams() {
    const params = new URLSearchParams({ sort: this.sort, limit: this.limit });
    if (term.length >= MIN_LENGTH) params.set('q', term);
    if (this.minPrice !== '') params.set('min_price', this.minPrice);
    if (this.maxPrice !== '') params.set('max_price', this.maxPrice);
    return params;
}
```

Empty filters are **left out** rather than sent as `min_price=`, which the
server would reject as "not a valid decimal". This is the browser-side mirror
of the server building its query one condition at a time.

The price inputs use `x-model` **without** `.number` on purpose: an empty box
stays `''`, which is easy to test for, and the server parses the text as a
`Decimal` anyway.

### Which events trigger a search

| Control                  | Event                         | Why                                     |
| ------------------------ | ----------------------------- | --------------------------------------- |
| Name search, price boxes | `@input.debounce.400ms`       | Typing produces many events             |
| Sort, limit              | `@change`                     | One choice = one event; no need to wait |
| Reset filters            | `@click`                      | Resets state, then searches             |
| Page open                | `x-init="searchProducts()"`   | Show something before the user acts     |

It reuses lesson 12's request counter, since several controls can now fire
overlapping searches.

### Responsive layout

`grid grid-cols-1 sm:grid-cols-3`: one column on a phone, three columns on
screens at least Tailwind's `sm` width (640px). A prefix like `sm:` means
"from this screen size up".

## Activity

1. Add an **Under $100** quick-filter button that sets `maxPrice` to `100`
   and searches.
2. Add a fourth sort option, `name_desc` (Z–A). You'll need to change the
   `Literal`, `SORTS` **and** the `<select>`.
3. Show "No products between $X and $Y" when `minPrice` is greater than
   `maxPrice`, without sending the request.

## Checkpoint

**Why should the server validate sort options instead of accepting arbitrary
database field names?** Suppose the route did `.sort(sort_field_from_user, 1)`.
What could a user learn or break by sending `sort=cards.card_number` against
the customers collection, or a field with no index on a 10-million-document
collection?
