# 11 – Search using keywords

Searching comes in two steps, the same way the dropdowns did:

| File                     | Where the search happens                                 |
| ------------------------ | -------------------------------------------------------- |
| `11a-local-search.html`  | **In the browser**, over a hard-coded array of 24 products. Open it directly, no server needed |
| `index.html` (11b)       | **On the server**: `GET /api/products?q=lamp` searches the 5,000 products in the `store` database, with photos |

## Run it

```bash
cd lessons/11-keyword-search_Img
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
        query = {"name": {"$regex": re.escape(term), "$options": "i"}}
    docs = list(db.products.find(query, {...}).sort("name", 1).limit(limit))
    images = main_images([doc["product_id"] for doc in docs])
```

| Code                               | Meaning                                                         |
| ---------------------------------- | --------------------------------------------------------------- |
| `q: str = ""`                      | A function argument that **isn't** in the path is a query parameter. The default makes it optional. |
| `Query(default=100, ge=1, le=100)` | Like `Field` in a model: limits for a query parameter. `limit=0` or `limit=5000` → 422. |
| `{"$regex": …, "$options": "i"}`   | MongoDB's "contains this pattern" match. `i` = ignore case.     |
| `re.escape(term)`                  | **Treat the user's text literally.** Without it, a search for `.*` would be a pattern that matches everything. Try `/api/products?q=.*` (it returns `[]`). |
| `.limit(limit)`                    | Never return more than asked. `light` matches over 200 of the 5,000 products; a search route needs a ceiling. |

This server search uses the **contains** definition. A whole-word match would
be the pattern `rf"\b{re.escape(term)}\b"`, where `\b` means *word boundary*.

> **No index.** This regex reads every product name. With 5,000 products
> that's instant; with 10 million it isn't. MongoDB's **text index**
> (`db.products.createIndex({ name: "text" })` and
> `{"$text": {"$search": term}}`) matches whole words using an index, and
> matches `keyboards` for `keyboard`, but can't do partial matches like
> `key`. That trade-off is what the "define matches first" step is about.

### Images: files on disk, paths in the database

The photos are **not** in MongoDB. They're ordinary JPG files in `images/`,
and the `product_images` collection stores where each one is:

```json
{ "product_id": 1, "sort_order": 0, "path": "images/a9/a96e15d9.jpg", "is_main": "t" }
```

One line in `api.py` makes FastAPI serve that folder as-is:

```python
app.mount("/images", StaticFiles(directory=HERE / "images"), name="images")
```

so `images/a9/a96e15d9.jpg` on disk is `http://127.0.0.1:8000/images/a9/a96e15d9.jpg`
in the browser, and the page just uses `<img :src="product.image">`.

| Code / idea                            | Meaning                                                   |
| -------------------------------------- | --------------------------------------------------------- |
| `main_images(product_ids)`             | **One** extra query for all the results' main photos (`$in`), not one query per product. |
| `"is_main": "t"`                       | The data came from a CSV, so the flag is the text `"t"`, not `true`. Check imported types before you query them. |
| `images/a9/…`                          | Files are spread over 256 subfolders by the first two hex digits of the name, so no folder holds 18,000 files. |
| Why not store the bytes in MongoDB?    | Large binary values bloat the database and its backups, and browsers can't cache them as easily. Files go in file storage; the database keeps the path. In production that folder becomes object storage or a CDN (S3, R2…), and only the path prefix changes. |

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
2. Select a result and check that the details panel shows its photo and how many times it was ordered.
3. Add a "Whole word" checkbox to 11b that sends `&whole=true`, and handle it
   on the server with the `\b` pattern.

## Checkpoint

**Should searching for `key` match `keyboard`? Should `lamp 1` match
`Premium Lamp 10`?** Decide first, then say which mode (and which MongoDB
query) gives your answer. What would a customer typing into a shop's search
box expect?
