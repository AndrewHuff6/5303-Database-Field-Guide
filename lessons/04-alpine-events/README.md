# 04 – Alpine events

So far the page reacts to state changes. Now the user's actions run code.
All data is still local; there's no server yet.

| File                          | New idea                                           |
| ----------------------------- | -------------------------------------------------- |
| `04a-click.html`              | `@click` running a statement                       |
| `04b-input-and-change.html`   | `@input` vs `@change`, and `$event`                |
| `04c-submit-and-methods.html` | `@submit.prevent`, methods, state in a `<script>` function |

## The `@` syntax

`@click="…"` is short for `x-on:click="…"`. The part after `@` is the name of
any browser event; the value is JavaScript to run when it happens.

| Event            | Fires when…                                                        |
| ---------------- | ------------------------------------------------------------------ |
| `@click`         | the element is clicked (or Enter/Space is pressed on a button)     |
| `@input`         | an input's value changes, on **every keystroke**                   |
| `@change`        | a select picks a new option, a checkbox toggles, or a text input loses focus after being edited |
| `@submit`        | a form is submitted (submit button or Enter in a field)            |

## 04a – `@click`

```html
<button type="button" @click="quantity++">+</button>
```

- The expression can **change** state (`quantity++`, `quantity = 1`), which
  `x-text` can't.
- Always give buttons a `type`. A `<button>` inside a `<form>` defaults to
  `type="submit"`, which is a common surprise.
- New Tailwind classes: `flex items-center gap-2` lays children out in a row;
  `ml-4` adds left margin; `hover:underline` underlines on hover.

## 04b – `@input`, `@change`, and `$event`

```html
<input @input="typed = $event.target.value">
<select @change="log.unshift('change: customer ' + $event.target.value)">
```

| Name                  | Meaning                                                    |
| --------------------- | ---------------------------------------------------------- |
| `$event`              | Alpine's name for the browser's event object               |
| `$event.target`       | The element the event happened on                          |
| `$event.target.value` | That element's current value (always a string)             |
| `log.unshift(x)`      | Add `x` to the **front** of the array (`push` adds to the end) |

Type in each field and watch the log. `@input` produces one entry per key, and
the note's `@change` only fires when you click away. That difference will
matter in lesson 12, where you'll search as the user types.

In practice you'll mostly use `x-model` to read values and reserve
`$event` for when you need something `x-model` doesn't give you.

## 04c – `@submit.prevent` and methods

```html
<form x-data="purchaseForm()" @submit.prevent="preview()">
```

**`.prevent`** calls the browser's `event.preventDefault()`. Without it, the
browser submits the form the 02a way: it navigates to a new URL and the page
reloads, wiping all Alpine state. With it, the page stays put and your method
runs instead. Every form from here on uses `@submit.prevent`.

The `required` and `min`/`max` attributes still work: the browser checks them
first, and `@submit` only fires if they pass.

### State in a `<script>` function

```html
<script>
    function purchaseForm() {
        return {
            customerId: '',
            quantity: 1,
            preview() { this.message = `…`; },
            reset()   { this.customerId = ''; this.quantity = 1; this.message = ''; },
        };
    }
</script>
```

- `x-data="purchaseForm()"` calls the function and uses the returned object as
  the component's state, exactly like the inline `{ … }` in lesson 03.
- **Methods** are functions inside that object. The page calls them by name:
  `preview()`, `reset()`. Inside a method, `this` is the component, so you
  write `this.quantity`. In the HTML attributes you write just `quantity`.
- The `<script>` is at the bottom of `<body>`, so it runs before Alpine (which
  is `defer`red) looks for `purchaseForm`.
- `$${total}`: the first `$` is a literal dollar sign and `${total}` is the
  template hole.

## Activity

In 04c, add a **Confirm** button that's only visible after a preview
(`x-show="message"`) and that replaces the message with
"Purchase confirmed (not really saved anywhere yet)". Then make Reset clear it.

## Checkpoint

Remove `.prevent` from 04c and submit. **What does `.prevent` prevent, and why
would losing it break an Alpine page?**
