# 02 – HTML forms before Alpine

There's no JavaScript in this lesson. Everything here is plain HTML the browser
already understands. Open each file by double-clicking it.

| File                             | New ideas                                              |
| -------------------------------- | ------------------------------------------------------ |
| `02a-basic-form.html`            | `<form>`, `<label>`, `<input>`, `<button>`, `name`     |
| `02b-select-and-validation.html` | `<select>`, `<option>`, `value`, validation attributes |
| `02c-styled-with-tailwind.html`  | The same form, styled with Tailwind CSS classes        |

## The skeleton every page uses

```html
<!DOCTYPE html>                <!-- "This is modern HTML." Always the first line. -->
<html lang="en">               <!-- The whole page. lang helps screen readers. -->
<head>                         <!-- Information ABOUT the page; not displayed. -->
    <meta charset="utf-8">     <!-- Text encoding, so é and – display correctly. -->
    <meta name="viewport" content="width=device-width, initial-scale=1">  <!-- Phones: don't zoom out. -->
    <title>…</title>           <!-- Text on the browser tab. -->
</head>
<body>                         <!-- Everything visible goes in here. -->
    <main>                     <!-- The page's main content. -->
```

## 02a – Form elements

| Element / attribute      | Meaning                                                                                      |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| `<form>`                 | Groups inputs that are submitted together.                                                   |
| `action=""`              | URL to send the data to. Empty means "this same page".                                       |
| `method="get"`           | Send the data in the URL (`?customer_id=1&quantity=2`). Later, `fetch()` uses POST.          |
| `<label>`                | The visible name of an input. Clicking it focuses the input, and screen readers announce it. |
| `<label for="x">`        | Connects to the input with `id="x"`. Alternatively, wrap the input inside the label.         |
| `<input type="number">`  | A text box that only accepts numbers and shows up/down arrows.                               |
| `name="customer_id"`     | **The key the data is sent under.** No `name`, no data sent.                                 |
| `id="product_id"`        | A unique identifier inside the page, used by `for=`, CSS and JavaScript. It is *not* sent.   |
| `value="1"`              | The starting value of the input.                                                             |
| `<button type="submit">` | Submits its form. (`type="button"` would do nothing by itself.)                              |

**Try it:** fill in the form, submit, and read the address bar. You'll see
`?customer_id=…&product_id=…&quantity=…`. Now delete `name="quantity"` and
submit again. Quantity disappears from the URL.

## 02b – Dropdowns and validation

```html
<select id="customer" name="customer_id" required>
    <option value="">Choose a customer</option>
    <option value="1">Margaret Stroustrup</option>
</select>
```

| Element / attribute    | Meaning                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------- |
| `<select>`             | A dropdown. Its `name` is sent with the chosen option's `value`.                    |
| `<option>`             | One choice. **Text between the tags = what the user sees. `value` = what is sent.** |
| `value=""`             | An empty placeholder choice. With `required`, the form won't submit on it.          |
| `required`             | The browser blocks submitting until this field has a value.                         |
| `min` / `max` / `step` | Limits for number inputs. `step="1"` rejects 2.5.                                   |
| `type="email"`         | The browser checks the format and phones show an `@` keyboard.                      |
| `placeholder`          | Faint hint text. It is not a value and is not sent.                                 |

The customers and products here are real rows from `noidx_10k` (customer
`_id` 1–5, product `_id` 1, 2, 3, 5), typed in by hand for now. Typing data
into HTML doesn't scale, which is the problem lessons 05–07 solve.

## 02c – Styling with Tailwind CSS

02a and 02b have no CSS, so you see what HTML alone gives you. 02c is the same
form as 02b with one added line in `<head>`:

```html
<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4.1.11"></script>
```

Tailwind is *utility-first* CSS. Instead of writing a stylesheet, you put
small, single-purpose classes on each element, and Tailwind generates the CSS
for exactly the classes it finds. The class names are short descriptions:

| Class                         | Means                                                           |
| ----------------------------- | --------------------------------------------------------------- |
| `p-6`, `px-3`, `py-2`         | padding: all sides / left+right / top+bottom (1 unit = 0.25rem) |
| `mb-1`, `mb-4`, `mt-4`        | margin-bottom / margin-top                                      |
| `mx-auto`                     | equal left/right margins, which centers a block                 |
| `max-w-xl`                    | maximum width (`sm` < `md` < `lg` < `xl` < `2xl` …)             |
| `w-full`, `w-32`              | width: 100% / fixed 8rem                                        |
| `space-y-4`                   | vertical gap between every child element                        |
| `block`                       | take a whole line (labels are inline by default)                |
| `text-2xl`, `text-sm`         | font size                                                       |
| `font-bold`, `font-medium`    | font weight                                                     |
| `text-gray-900`, `text-white` | text color (`50` is lightest … `950` darkest)                   |
| `bg-white`, `bg-blue-600`     | background color                                                |
| `border`, `border-gray-300`   | 1px border / its color                                          |
| `rounded`, `rounded-lg`       | rounded corners                                                 |
| `shadow-sm`                   | a soft drop shadow                                              |

A prefix applies a class only in some situation:

| Prefix          | Applies when…                                                  |
| --------------- | -------------------------------------------------------------- |
| `hover:`        | the mouse is over the element (`hover:bg-blue-700`)            |
| `disabled:`     | the element is disabled (used from lesson 05 on)               |
| `user-invalid:` | the user has interacted with the field and it fails validation |

Tailwind's base styles remove the browser's default look; for example, inputs
have no border until you add `border`. That's why every input in 02c carries
the same few classes. You'll see this same small set of classes in every lesson
from here on, so you only have to learn it once.

Tailwind is only about appearance. You can ignore every `class="…"` and
the page logic is unchanged. Delete the `<script>` line to prove it.

## Activity

Build your own purchase form with a customer dropdown, a product dropdown, and
a quantity input. Make all three required and keep quantity between 1 and 10.

## Checkpoint

Choose "Tim Ritchie" and submit. The URL says `customer_id=2`, not the name.
**What's the difference between an option's displayed text and its submitted
value, and why does the database want the value?**
