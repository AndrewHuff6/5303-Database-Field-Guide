# 01 – The application and its data

Before writing any code, get to know the data the finished app will use and the
page you're building toward.

## The goal

One page where a user can:

1. Choose a customer from a dropdown.
2. Search for a product (later: as you type, with filters).
3. Pick the customer's card and a quantity.
4. Submit a purchase and see a confirmation.
5. See that customer's purchase history update.

Lessons 02–05 build this page with **no server at all**, using lists typed
directly into the HTML and JavaScript. Then the lists move to FastAPI (lesson
06) and finally into MongoDB (lesson 07 onward). The page barely changes along
the way.

## The `noidx_10k` database

The name means "no indexes, 10 thousand purchases". Apart from the automatic
`_id` index (and a unique index on `products.product_name`), nothing is indexed.
That's deliberate: a later course topic is measuring what indexes do.

| Collection      | Documents | Used in this course                         |
| --------------- | --------- | ------------------------------------------- |
| `customers`     | 500       | Customer dropdown, cards, registration      |
| `products`      | 100       | Product dropdown, details, search           |
| `purchases`     | 10,000    | Purchase history, recording purchases       |
| `counters`      | 1         | Handing out the next integer `_id`          |
| `monthly_sales` | ~8,000    | Pre-computed totals (lesson 07 example)     |

### `customers`

```js
{
  _id: 1,
  first_name: 'Margaret',
  last_name: 'Stroustrup',
  email: 'margaret.stroustrup.1@example.com',
  address: '8242 Main St',
  zipcode: '58331',
  state_code: 'MD',
  cards: [
    { card_id: 1, card_type: 'americanexpress', card_number: '4000000000000001' }
  ]
}
```

- `_id` is a plain **integer**, not a MongoDB `ObjectId`.
- `cards` is an **array of embedded documents**. Every customer has one or two.
  `card_id` is unique across all customers, not just within one customer.
- There is no single `name` field. The API will join `first_name` and `last_name`.

### `products`

```js
{ _id: 1, product_name: 'Wireless Keyboard 0', unit_price: Decimal128('202.11') }
```

- `unit_price` is a **`Decimal128`**, an exact decimal number. This matters for
  money: in JavaScript and Python, `0.1 + 0.2` gives `0.30000000000000004`.
- Products have no category or stock field. Lesson 13 filters by price instead,
  and lesson 10 explains how you'd add stock.

### `purchases`

```js
{
  _id: 1,
  customer_id: 290,
  card_id: 422,
  product_id: 66,
  product_name: 'Smart Speaker 65',
  amount: Decimal128('356.92'),
  department: 'Beauty',
  state_code: 'NH',
  card_type: 'mastercard',
  purchase_date: ISODate('2026-04-30T00:00:00.000Z')
}
```

- **One purchase document = one unit of one product.** `amount` always equals
  the product's `unit_price`. Buying a quantity of 3 means inserting 3 documents.
- `product_name`, `state_code` and `card_type` are **copied** in from the other
  collections when the purchase is made. That's called *denormalizing*: the
  purchase keeps a record of what was true at purchase time, even if the
  product is renamed or the customer moves later.
- `department` belongs to the purchase, not the product. The same product shows
  up under several departments.

### `counters`

```js
{ _id: 'purchase_id', seq: 10000 }
```

MongoDB doesn't hand out integer IDs automatically. To make a new purchase, the
server adds 1 to `seq` and uses the result as the new `_id`. Lesson 09 adds
counters for customer and card IDs the same way.

## How money is handled in these lessons

| Where         | Representation          | Why                                               |
| ------------- | ----------------------- | ------------------------------------------------- |
| MongoDB       | `Decimal128('202.11')`  | Exact; that's how the data was loaded            |
| Python        | `decimal.Decimal`       | Exact arithmetic for totals                      |
| JSON          | the string `"202.11"`   | JSON has no decimal type, and a string can't be rounded by accident |
| Browser       | integer cents: `20211`  | Integer arithmetic is exact in JavaScript        |

The browser converts with `Math.round(Number(price) * 100)` and only displays
dollars: `(cents / 100).toFixed(2)`.

## Explore it yourself

Open `mongosh` and run these one at a time:

```js
use noidx_10k
show collections

db.customers.findOne()
db.products.find().limit(5)
db.purchases.find({ customer_id: 1 }).sort({ purchase_date: -1 }).limit(3)

// Only some fields: 1 = include. _id comes back unless you say _id: 0.
db.customers.find({}, { first_name: 1, last_name: 1 }).limit(5)

// Products whose name contains "lamp", any capitalization
db.products.find({ product_name: /lamp/i })

db.counters.find()
```

**Activity:** Find customer 1's cards, the five most expensive products, and
how many purchases customer 1 has made (`countDocuments`).

**Checkpoint:** A purchase stores `product_name` even though `product_id`
would let you look it up. What problem does that copy solve, and what new
problem does it create?
