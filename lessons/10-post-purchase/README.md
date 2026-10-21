# 10 – Record a purchase

```text
POST /api/purchases   {"customer_id": 1, "card_id": 1, "product_id": 1, "quantity": 3}
```

The browser sends **only the user's choices**. It doesn't send a price, a total
or any names: the server looks those up itself. The total on the page is a
**preview**; the total in the database is the one the server calculates.

> This lesson **writes to the database**. Consider running it against a copy
> (see the top-level README).

## Run it

```bash
cd lessons/10-post-purchase
python api.py
```

Pick a customer, a card, a product and a quantity, then **Place purchase**.
The green receipt comes from the server's answer, and the history table
refreshes with the new rows at the top.

## What's new in `api.py`

| Route                              | Purpose                                                       |
| ---------------------------------- | ------------------------------------------------------------- |
| `GET /api/customers/{customer_id}` | Name, email, state and **cards** (last four digits only), for the card dropdown |
| `POST /api/purchases`              | Record the purchase                                           |

### The request model

```python
class NewPurchase(BaseModel):
    customer_id: int
    card_id: int
    product_id: int
    quantity: int = Field(ge=1, le=10)
```

`ge`/`le` mean *greater-or-equal* and *less-or-equal*. Notice what's missing:
no `amount`, `total`, `product_name` or `state_code`. If the model doesn't
declare a field, FastAPI ignores it, so a client that sends
`"amount": "0.01"` changes nothing.

### The route, step by step

| Step | Code                                              | Why                                                  |
| ---- | ------------------------------------------------- | ---------------------------------------------------- |
| 1    | `NewPurchase` validation                          | Integer IDs, quantity 1–10. Otherwise 422.           |
| 2    | `find_one` customer and product; check the card is in `customer["cards"]` | IDs that are valid integers may still not exist (404), and a real card may belong to someone else (400). |
| 3    | `unit_price = product["unit_price"].to_decimal()` | **The authoritative price.** `.to_decimal()` turns `Decimal128` into Python's `Decimal` so `unit_price * quantity` is exact. |
| 4    | `next_id("purchase_id", new.quantity)` then `insert_many(docs)` | In `noidx_10k`, one purchase document is one unit (lesson 01). Quantity 3 → three documents, so three IDs are reserved in one atomic step. |
| 5    | `return {...}`                                    | A confirmation built from what was actually stored.  |

Each document copies `product_name`, `state_code` and `card_type`, and
stores `amount` as **the price at purchase time**. If the product's price changes
tomorrow, today's purchases keep today's price.

`department`: the existing data records a department on each purchase, not on
products. The route reuses the department this product was last sold under.
This is a modelling quirk of the dataset, worth discussing.

`next((c for c in customer["cards"] if ...), None)`: the first card that
matches, or `None`.

## What's new on the page

| Change                          | Detail                                                         |
| ------------------------------- | -------------------------------------------------------------- |
| Card dropdown                   | Built from `customer.cards`, disabled until a customer is loaded |
| `loadCustomer()`                | Replaces `loadHistory()`: loads the customer **and** their history, and clears `cardId` so the previous customer's card can't stay selected |
| `placePurchase()`               | `postJSON('/api/purchases', {customer_id, card_id, product_id, quantity})` |
| `receipt`                       | The server's answer. The confirmation shows *its* total, not the preview |
| Refresh after success           | Reloads history and the product (its purchase count went up)  |
| `:disabled="!canSubmit \|\| submitting"` | Prevents double-submitting while the request is in flight |

## Two things the server can't do yet

### Stock (optional extension)

`noidx_10k` products have no stock level. To add one:

```js
// mongosh, on your copy of the database
db.products.updateMany({}, { $set: { stock: 20 } })
```

Then, in `create_purchase`, **before** inserting:

```python
result = db.products.update_one(
    {"_id": new.product_id, "stock": {"$gte": new.quantity}},  # only if enough is left…
    {"$inc": {"stock": -new.quantity}},                         # …take them
)
if result.modified_count == 0:
    raise HTTPException(status_code=409, detail="Not enough stock")
```

The check and the decrement happen in **one** operation. A "read stock, then
decide, then write" version would let two buyers both see `stock: 1` and
both succeed.

### Keeping several documents consistent

Even with the conditional update, the stock decrement and the `insert_many`
are two separate writes. If the server crashes between them, stock is gone
but no purchase was recorded. The same applies to `monthly_sales`, which this
route doesn't update at all.

MongoDB **transactions** make several writes succeed or fail together, but
need a replica set rather than a single local server. Other designs include
recording the purchase first with `status: "pending"` and fixing up
afterwards. For this course, knowing *where* the gap is matters more than
closing it.

## Activity

1. Place a purchase of 3 and find the three new documents in `mongosh`:
   `db.purchases.find().sort({ _id: -1 }).limit(3)`.
2. Open `/docs` and send a purchase with `"amount": "0.01"` added. Check what
   was stored.
3. Challenge: also update `monthly_sales` (`$inc` `num_purchases` and `revenue`
   for this month, state and department, with `upsert=True`).

## Checkpoint

**What happens if two customers try to buy the last available item at the
same moment?** Answer it twice: for the code as written (no stock), and with
the stock extension using the conditional `update_one`.
