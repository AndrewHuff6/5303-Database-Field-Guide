# 05 – Populate form elements from local arrays

In lessons 02–04 every `<option>` was typed into the HTML. Now the options come
from **JavaScript arrays**, and Alpine generates the HTML. That's the step that
makes lesson 06 easy: once the page builds its dropdowns from an array, it
doesn't care whether the array was typed in or arrived from a server.

| File                         | New idea                                              |
| ---------------------------- | ----------------------------------------------------- |
| `05a-x-for-list.html`        | `<template x-for>`, `:key`, arrays changing the page  |
| `05b-customer-dropdown.html` | `<option :value>`, `x-model.number` on a select, looking up by ID |
| `05c-purchase-form.html`     | Two dropdowns, a total, `:disabled`. **This is the page lessons 06–08 keep.** |

## 05a – `x-for`

```html
<template x-for="product in products" :key="product.id">
    <li>
        <span x-text="product.name"></span> – $<span x-text="product.price"></span>
    </li>
</template>
```

| Piece                           | Meaning                                                          |
| ------------------------------- | ---------------------------------------------------------------- |
| `<template>`                    | An HTML element the browser never displays. Alpine uses it as a stamp. |
| `x-for="product in products"`   | Stamp the template's contents once per item; call the current item `product`. |
| `:key="product.id"`             | A unique, stable label for each copy, so Alpine can tell which item is which when the array changes. |
| One child only                  | The `<template>` must contain exactly **one** root element (here `<li>`). |

**Why a stable key?** If you used the position (0, 1, 2…) and removed the
first item, every remaining item would shift position and Alpine would
mismatch them. IDs don't change, so they're the right key.

Click **Add** and **Remove last**. You never touch the `<ul>`: changing the
array is enough.

## 05b – A dropdown from an array

```html
<select x-model.number="selectedCustomerId">
    <option value="">Choose a customer</option>
    <template x-for="customer in customers" :key="customer.id">
        <option :value="customer.id" x-text="customer.name"></option>
    </template>
</select>
```

**The colon.** `:value="customer.id"` (short for `x-bind:value`) means "the
value is the result of this JavaScript expression". Without the colon,
`value="customer.id"` would be the literal text `customer.id`. Any attribute
can be bound: `:value`, `:disabled`, `:class`, `:href`.

**Store the ID, look up the rest.** The state holds just `selectedCustomerId`
(a number). A getter finds the full object when the page needs the name:

```js
get selectedCustomer() {
    return this.customers.find(c => c.id === this.selectedCustomerId);
}
```

`c => c.id === …` is an *arrow function*: "given `c`, is its id the selected
one?". `?.` in `selectedCustomer?.name` means "if `selectedCustomer` is
undefined, give `undefined` instead of crashing".

`.number` matters again: without it, `selectedCustomerId` would be `"2"`, and
`2 === "2"` is **false**, so `.find()` would never match. The page shows
`JSON.stringify(selectedCustomerId)` so you can see the quotes appear if you
remove `.number`.

## 05c – The purchase form

The state now holds two arrays whose objects have **exactly the shape the API
will return in lesson 06**:

```js
customers: [{ id: 1, name: 'Margaret Stroustrup' }, …]
products:  [{ id: 1, name: 'Wireless Keyboard 0', price: '202.11' }, …]
```

New pieces:

| Code                                | Purpose                                                    |
| ----------------------------------- | ---------------------------------------------------------- |
| `toCents(price)`                    | `"202.11"` → `20211`. `Math.round` fixes float noise such as `20210.999…`. |
| `get canSubmit()`                   | True only when a customer, a product and a valid quantity are chosen. |
| `:disabled="!canSubmit"`            | The button is disabled until then.                         |
| `disabled:opacity-50`               | Tailwind: fade the button while it's disabled.             |
| `` x-text="`${product.name} – $${product.price}`" `` | A template string as the option text.     |

## Activity

Add a third dropdown, **Card**, between customer and quantity. Give each
customer a `cards` array (customer 1 has
`[{ card_id: 1, card_type: 'americanexpress' }]`), and build the card options
from `customer.cards`. Make the dropdown `:disabled` until a customer is chosen.
Lesson 10 does this with real data.

## Checkpoint

**Why store a customer ID instead of the customer's name?** Consider two
customers named "Alan Ritchie", and what the `purchases` collection stores.
