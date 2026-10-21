# 09 – Submit information with POST

Every request so far has been a GET: *give me data*. A POST says *here is
data, store it*. This lesson starts with a small write, registering a
customer, before lesson 10 tackles purchases.

```text
Form state → JSON.stringify → POST /api/customers → Pydantic validates → insert_one → 201 + new customer
```

> This lesson **writes to the database**. Consider running it against a copy
> (see the top-level README, `MONGO_DB=noidx_10k_dev`).

## Run it

```bash
cd lessons/09-post-customer
python api.py
```

The page is lesson 08's page with a registration form added at the bottom.
After registering, the new customer appears in the dropdown, already selected.

## Server

### A request model

```python
class NewCustomer(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    first_name: str = Field(min_length=1, max_length=40)
    email: str = Field(max_length=100, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    zipcode: str = Field(pattern=r"^\d{5}$")
    state_code: str = Field(pattern=r"^[A-Z]{2}$")
    card_type: Literal["americanexpress", "discover", "mastercard", "visa"]
    card_number: str = Field(pattern=r"^\d{16}$")
    ...
```

A **Pydantic model** describes what a valid request body looks like.

| Piece                          | Meaning                                                       |
| ------------------------------ | ------------------------------------------------------------- |
| `class NewCustomer(BaseModel)` | A data shape. Each annotated line is a required field.        |
| `str`, `int`                   | The field's type. `"abc"` for an `int` field is rejected.     |
| `Field(min_length=1, …)`       | Extra rules for that field.                                   |
| `pattern=r"^\d{5}$"`           | A regular expression: exactly five digits, nothing else.      |
| `Literal["visa", …]`           | Only one of these exact values.                               |
| `str_strip_whitespace=True`    | `" Ada "` arrives as `"Ada"`.                                 |

Compare lesson 00, where `purchase: dict` accepted any JSON at all.

### The route

```python
@app.post("/api/customers", status_code=201)
def create_customer(new: NewCustomer):
```

Because the parameter's type is a model, FastAPI:

1. reads the request body as JSON,
2. checks it against `NewCustomer`,
3. if anything fails, answers **422** with a list of every problem, **without
   calling your function**,
4. otherwise calls `create_customer` with `new.first_name`, `new.email`, … ready to use.

Inside, the route checks for a duplicate email (**409 Conflict**), builds the
document in the same shape as the existing customers (including the `cards`
array), inserts it, and returns `{id, name}`, the same shape the dropdown
already uses. `status_code=201` means *Created*.

### Where new IDs come from: `counters`

```python
def next_id(name, count=1):
    counter = db.counters.find_one_and_update(
        {"_id": name}, {"$inc": {"seq": count}}, return_document=ReturnDocument.AFTER
    )
    return counter["seq"] - count + 1
```

`find_one_and_update` with `$inc` adds to the counter and returns the new value
**in one atomic step**. Two simultaneous requests can never get the same
number. "Find the highest `_id` and add 1" can't promise that: both requests
could read 500 and both try to insert 501.

`noidx_10k` ships with only a `purchase_id` counter. On startup,
`ensure_counter` creates `customer_id` and `card_id` counters starting from
the current highest IDs. `$setOnInsert` with `upsert=True` means "create it if
it's missing; if it exists, leave it alone".

## Page

### Sending JSON

```js
async function postJSON(url, body) {
    const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    ...
}
```

| Option                              | Why                                                      |
| ----------------------------------- | -------------------------------------------------------- |
| `method: 'POST'`                    | `fetch` sends GET unless told otherwise.                 |
| `'Content-Type': 'application/json'`| Tells FastAPI how to read the body. Leave it out and you get a 422. |
| `JSON.stringify(body)`              | Turns the JavaScript object into JSON text. A request body is text. |

### Collecting the form into one object

All eight fields bind into one object, `newCustomer`:

```html
<input x-model="newCustomer.first_name">
```

so the request body is just a copy of it:

```js
const body = { ...this.newCustomer, state_code: this.newCustomer.state_code.toUpperCase() };
```

`{ ...obj }` copies every property; a property listed after it overrides that one.

### Showing the server's errors

A 422 `detail` is a list:

```json
{"detail": [{"loc": ["body", "zipcode"], "msg": "String should match pattern '^\\d{5}$'"}]}
```

`errorMessages()` turns either shape (a string or that list) into lines such as
`zipcode: String should match pattern…`, and the page lists them.

### After success

```js
this.customers = await getJSON('/api/customers');  // refresh the dropdown
this.customerId = created.id;                       // select the new customer
await this.loadHistory();                           // "No purchases yet."
```

### New HTML and Tailwind

| Code                               | Meaning                                                  |
| ---------------------------------- | -------------------------------------------------------- |
| `pattern="\d{5}"`                  | Browser-side regex check (the same rule as the server's) |
| `inputmode="numeric"`              | Phones show a number keypad, but it's still a text field, so leading zeros survive |
| `maxlength="2"`                    | Can't type more than 2 characters                        |
| `:novalidate="skipBrowserChecks"`  | A bound boolean attribute: when true, the browser skips `required`/`pattern` checks |
| `grid grid-cols-2 gap-4`           | Lay out the fields in two columns                        |
| `col-span-2`                       | This field spans both columns                            |
| `uppercase`                        | *Displays* text in capitals; the value is unchanged, which is why the code still calls `toUpperCase()` |

## Activity

1. Register a customer and buy nothing. The history should say "No purchases yet."
2. Register the same email twice and read the 409 message.
3. Make the error messages friendlier: in `errorMessages`, map field names to
   labels (`zipcode` → "ZIP code") and, for `string_pattern_mismatch`, say
   "has the wrong format" instead of showing the regex.

## Checkpoint

Tick **Skip browser validation**, leave every field empty, and submit.
**Why is browser validation insufficient on its own?** Who else can send a
POST to `/api/customers`? (Try it from `/docs`, or with `curl`.)
