# 03 – Alpine state and display

Alpine.js lets you add behavior to HTML by writing attributes. There's no build
step and no separate JavaScript file: one `<script>` tag in `<head>` loads it.

```html
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.1/dist/cdn.min.js"></script>
```

`defer` means "download now, but run after the whole page has been read", so
Alpine can find every `x-` attribute below it.

| File                       | New idea                                           |
| -------------------------- | -------------------------------------------------- |
| `03a-x-data-x-text.html`   | `x-data` (state) and `x-text` (display a value)    |
| `03b-x-model.html`         | `x-model` (inputs ↔ state) and `.number`           |
| `03c-x-show.html`          | `x-show` (show/hide), checkboxes                   |
| `03d-purchase-preview.html`| All of the above plus a getter: a live price preview |

## 03a – `x-data` and `x-text`

```html
<article x-data="{ productName: 'Wireless Keyboard 0', priceCents: 20211, quantity: 2 }">
    <strong x-text="productName"></strong>
    $<span x-text="(priceCents / 100).toFixed(2)"></span>
</article>
```

| Directive | Value                      | What happens                                                      |
| --------- | -------------------------- | ----------------------------------------------------------------- |
| `x-data`  | A JavaScript object        | This element and everything inside it become one *component*. The object's properties are its **state**. |
| `x-text`  | Any JavaScript expression  | The element's text becomes the expression's result, and is re-calculated whenever the state it uses changes. |

Points to notice:

- State is **scoped**: the second `<article>` has its own `x-data` and can't
  see the first one's variables.
- `x-text` takes an *expression*, not just a variable name:
  `(priceCents / 100).toFixed(2)` turns `20211` into `"202.11"`.
- The price is stored as **integer cents** (`20211`). See lesson 01 for why.
- `` `${quantity} × ${productName}` `` is a JavaScript *template string*:
  backticks, with `${…}` holes filled from the state.

## 03b – `x-model`

```html
<input type="number" min="1" x-model.number="quantity">
```

`x-model` is a **two-way binding**: typing updates `quantity`, and if code
changes `quantity`, the box updates. Every `x-text` that uses `quantity`
re-renders automatically.

| Modifier         | Effect                                                         |
| ---------------- | -------------------------------------------------------------- |
| `x-model.number` | Convert the input's text to a number. **Use it for every numeric field.** |
| `x-model.trim`   | Remove spaces from both ends (useful for names and emails).    |
| `x-model.lazy`   | Update only when the input loses focus instead of on every key. |

The bottom half of 03b shows the bug `.number` prevents: an input's value is
always a **string**, so `"3" + 1` is `"31"`.

The `<label class="block"><span>…</span><input></label>` pattern wraps the input
inside its label (no `for`/`id` needed). The `<span class="block">` just puts
the label text on its own line.

## 03c – `x-show`

```html
<p x-show="quantity > 5">⚠️ Large order</p>
<input type="checkbox" x-model="showDetails">
<section x-show="showDetails">…</section>
```

| Directive | What happens                                                                    |
| --------- | ------------------------------------------------------------------------------- |
| `x-show`  | When the expression is false, Alpine adds `display: none`. The element still exists in the page; it's just hidden. |

A checkbox bound with `x-model` holds `true` or `false`, which makes it a
natural switch for `x-show`. `!showDetails` means "not showDetails".

## 03d – Purchase preview

```js
{
    customerId: '',
    quantity: 1,
    priceCents: 20211,
    get totalCents() {
        return this.quantity * this.priceCents;
    }
}
```

- The `x-data` object can span many lines. It's still one JavaScript object
  inside the attribute's quotes, so use single quotes for strings inside it.
- `get totalCents()` is a **getter**. You read it like a variable
  (`totalCents`, no parentheses), but it's recalculated every time, so it can
  never be out of date. Inside it, `this` means the component's state.
- `customerId` starts as `''`, which matches the empty "Choose a customer"
  option, so the preview stays hidden until someone is chosen.
- `customerId` is a **string** here (`"2"`), because `<option value="2">` always
  produces text. Lesson 05 uses `x-model.number` on selects too.

## Activity

Starting from 03d, add a second product price and a pair of radio buttons
(`<input type="radio" x-model="priceCents" value="…">`) that switch between
them. Hint: radio values are strings too, so you'll need `.number`.

## Checkpoint

Change the quantity in 03d to 7. **Did anything change in the database?**
Where does this total exist, and what happens to it when you reload the page?
