# 12 – Search as you type

Lesson 11's search worked when you pressed a button. Now results update **as
you type**, which raises problems a button never had: too many requests,
searches for one letter, and old answers arriving after new ones.

The server route is unchanged except for one development switch, `slow=1`.

## Run it

```bash
cd lessons/12-search-as-you-type
python api.py
```

Type `lamp` slowly, then quickly, and watch the **Request log**.

## Debouncing

```html
<input type="search" x-model="query" @input.debounce.400ms="searchProducts()">
```

Without `.debounce`, typing `kettle` sends six requests: `k`, `ke`, `ket`, …
With `.debounce.400ms`, Alpine waits until **400 ms have passed with no
typing** and then calls `searchProducts()` once. A fast typist sends one
request; a slow one sends a few.

| Modifier          | Behavior                                                    |
| ----------------- | ----------------------------------------------------------- |
| `.debounce`       | Wait 250 ms after the last event (the default)              |
| `.debounce.400ms` | Wait 400 ms                                                  |
| `.throttle.400ms` | Run at most once every 400 ms, even while typing continues  |

`@keydown.escape="clearSearch()"` is another modifier: only run on the Esc key.

## Minimum length, loading, clearing

```js
if (term.length < MIN_LENGTH) {
    this.cancelPending();
    return;
}
```

- A one-letter search matches nearly everything and helps no one. Below 2
  characters, the page clears instead of searching, and `tooShort` shows a hint.
- "Searching…" is pinned inside the input with `relative` (on the wrapper) and
  `absolute right-3 top-2.5` (on the label): Tailwind's positioning classes.
- Clearing the box (or pressing Esc) empties the results. It also
  **cancels anything still in flight** (see below), or a late answer could
  repopulate a box the user just emptied.

## Out-of-order responses

Tick **Simulate a slow, unpredictable network**. Every request now takes a
random 0.1–2 s on the server:

```python
if slow:
    time.sleep(random.uniform(0.1, 2.0))
```

With protection set to **None**, type `lamp`, pause, then change it to `kettle`.
Sometimes the log reads:

```text
#1 sent      "lamp"
#2 sent      "kettle"
#2 displayed "kettle"
#1 displayed "lamp"      ← arrived last, so it replaced the newer results
```

The box says `kettle` and the list shows lamps. The page marks this in red.
Requests don't promise to finish in the order they started.

### Fix 1: a request counter

```js
const myNumber = ++this.requestCount;
// … await the response …
if (myNumber !== this.requestCount) {
    return;  // a newer request was sent after this one: ignore this answer
}
```

Each search takes a ticket number. When an answer arrives, it's displayed only
if no newer ticket has been issued. Old requests still complete on the server,
and the page throws their answers away.

### Fix 2: `AbortController`

```js
this.controller?.abort();                 // cancel the previous request
this.controller = new AbortController();
const response = await fetch(url, { signal: this.controller.signal });
```

Starting a new search **cancels** the previous one. The cancelled `fetch`
throws an error named `AbortError`, which the `catch` recognizes and ignores.
The browser stops waiting, though the server may still finish the work.
In the Network tab, aborted requests show as *(canceled)*.

| Strategy        | Old response…                        | Good for                                  |
| --------------- | ------------------------------------ | ----------------------------------------- |
| None            | can overwrite new results            | Nothing. This is the bug.                 |
| Request counter | arrives, is ignored                  | Simple, works with any async code         |
| AbortController | is cancelled before it arrives       | Also frees the connection; good for slow or large responses |

The `finally` block only switches `loading` off for the newest request, so
"Searching…" doesn't disappear while the newest search is still running.

## New Alpine and JS bits

| Code                                 | Meaning                                                   |
| ------------------------------------ | --------------------------------------------------------- |
| `x-for="(entry, i) in log" :key="i"` | The second name is the index. Using it as the key is fine here, because log entries are only appended, never reordered |
| `params.set('slow', '1')`            | Add a parameter to an existing `URLSearchParams`          |
| `fetch(url, { signal })`             | When `signal` is `undefined`, it's simply ignored         |
| `err.name === 'AbortError'`          | How a cancelled `fetch` reports itself                    |

## Activity

1. Convert lesson 11's Search button into this search-as-you-type interface,
   with debounce and a 2-character minimum.
2. Reproduce the out-of-order bug with protection **None**, then fix it with
   **Request counter**, then **AbortController**, and compare the logs.
3. Change the debounce to `50ms` and to `1500ms`. Which feels better, and
   how many requests does each send for `kettle`?

## Checkpoint

**If a slow response for an old search arrives last, how could it replace
newer results?** Explain in terms of what `await` does, and why
`this.results = data` runs in whatever order the answers arrive.
