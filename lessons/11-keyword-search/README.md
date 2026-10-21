# 11 – Search using keywords

Searching comes in two steps, the same way the dropdowns did:

| File                     | Where the search happens                                 |
| ------------------------ | -------------------------------------------------------- |
| `11a-local-search.html`  | **In the browser**, over a hard-coded array of 24 products. Open it directly, no server needed |
| `index.html` (11b)       | **On the server**: `GET /api/products?q=lamp` searches all 100 products in MongoDB |

## Run it

```bash
cd lessons/11-keyword-search
python api.py
```

http://127.0.0.1:8000 is the server search. http://127.0.0.1:8000/local
serves 11a too, if you'd rather not open the file directly.

## First, define "matches"

Before writing any query, decide what a search for `key` should find. 11a
lets you switch between two definitions:

| Mode                | Code                                    | `key` finds `Wireless Keyboard 0`? | `lamp 1` finds `Premium Lamp 10`? |
| ------------------- | --------------------------------------- | ---------------------------------- | --------------------------------- |
| Whole word          | `name.split(' ').includes(term)`        | No                                 | No (`lamp 1` isn't a single word) |
| Contains the text   | `name.includes(term)`                   | Yes                                | Yes                               |

Both start the same way:

```js
const term = this.query.trim().toLowerCase();
```

- `trim()` removes spaces at both ends, so `"  lamp "` → `"lamp"`.
- `toLowerCase()` on **both** the term and the name makes the search
  case-insensitive.
- An empty term is treated as "no search", not "match everything".

`products.filter(p => …)` returns a new array with only the items whose test
returned `true`.

## 11b – Query parameters

```text
GET /api/products?q=lamp&limit=10
                 └───────┬──────┘
                  query parameters
```

Path parameters (lesson 08) identify **which thing**: `/api/products/7`.
Query parameters **adjust** the request: what to search for, how many to
return, later how to sort. They're optional, so `/api/products` with no
parameters still works for the purchase form's dropdown.

### Server

```python
@app.get("/api/products")
def get_products(q: str = "", limit: int = Query(default=100, ge=1, le=100)):
    term = q.strip()
    query = {}
    if term:
        query = {"product_name": {"$regex": re.escape(term), "$options": "i"}}
    docs = db.products.find(query, {...}).sort("product_name", 1).limit(limit)
```

| Code                               | Meaning                                                         |
| ---------------------------------- | --------------------------------------------------------------- |
| `q: str = ""`                      | A function argument that **isn't** in the path is a query parameter. The default makes it optional. |
| `Query(default=100, ge=1, le=100)` | Like `Field` in a model: limits for a query parameter. `limit=0` or `limit=5000` → 422. |
| `{"$regex": …, "$options": "i"}`   | MongoDB's "contains this pattern" match. `i` = ignore case.     |
| `re.escape(term)`                  | **Treat the user's text literally.** Without it, a search for `.*` would be a pattern that matches everything. Try `/api/products?q=.*` (it returns `[]`). |
| `.limit(limit)`                    | Never return more than asked. Even with 100 products, a search route should have a ceiling. |

This server search uses the **contains** definition. A whole-word match would
be the pattern `rf"\b{re.escape(term)}\b"`, where `\b` means *word boundary*.

> **No index.** In `noidx_10k`, this regex reads every product name. With 100
> products that's instant; with 10 million it isn't. MongoDB's **text index**
> (`db.products.createIndex({ product_name: "text" })` and
> `{"$text": {"$search": term}}`) matches whole words using an index, and
> matches `keyboards` for `keyboard`, but can't do partial matches like
> `key`. That trade-off is what the "define matches first" step is about.

### Page

```js
const params = new URLSearchParams({ q: term, limit: this.limit });
this.lastUrl = `/api/products?${params}`;
this.results = await getJSON(this.lastUrl);
```

`URLSearchParams` builds `q=lamp&limit=10` and **encodes** special characters:
a search for `a&b` becomes `q=a%26b` instead of breaking the URL into two
parameters. The page prints the exact URL it requested, so you can watch it change.

New pieces:

| Code                                     | Meaning                                                   |
| ---------------------------------------- | --------------------------------------------------------- |
| `type="search"`                          | A text input with a built-in clear (×) button.            |
| `:class="selected?.id === product.id && '…'"` | Add these classes only when the condition is true. Alpine merges them with the static `class`. |
| `divide-y divide-gray-100`               | Tailwind: a thin line between list items.                 |
| `flex-1`                                 | Tailwind: this element takes the remaining width.         |
| `searched`                               | The term the current results belong to. `null` = no search yet, so "no matches" and "haven't searched" display differently. |

## Activity

1. Search for `lamp`, `LAMP` and ` lamp ` (with spaces). All three should
   give the same results.
2. Select a result and check that the details panel shows its purchase count.
3. Add a "Whole word" checkbox to 11b that sends `&whole=true`, and handle it
   on the server with the `\b` pattern.

## Checkpoint

**Should searching for `key` match `keyboard`? Should `lamp 1` match
`Premium Lamp 10`?** Decide first, then say which mode (and which MongoDB
query) gives your answer. What would a customer typing into a shop's search
box expect?
