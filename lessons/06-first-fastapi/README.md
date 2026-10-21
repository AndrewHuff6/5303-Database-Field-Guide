# 06 – Connect the page to FastAPI

The page from lesson 05 had its customers and products typed into JavaScript.
Now those same lists move to a **Python server**, and the browser asks for them.

```text
Button click → fetch('/api/customers') → FastAPI route → JSON → Alpine state → dropdown
```

There's still no database. The server returns hard-coded Python lists, so the
only new idea is the request itself.

| File                         | What it is                                                |
| ---------------------------- | --------------------------------------------------------- |
| `api.py`                     | The server: two pages and three JSON routes               |
| `06a-load-with-button.html`  | Load countries, then customers, by clicking buttons       |
| `06b-load-with-x-init.html`  | The lesson 05 purchase form, filled automatically on page load |
| `06c-cors-experiment.html`   | Optional: a test page for the CORS exercise at the end    |
| `countries.json`             | The data for `/api/countries`                             |

## Run it

```bash
cd lessons/06-first-fastapi
python api.py
```

Open http://127.0.0.1:8000 for 06a and http://127.0.0.1:8000/auto for 06b.

> **Don't double-click the HTML files in this lesson.** Opened from disk, the
> page loads but every request fails, even while `api.py` is running. Open the
> pages through the server's address instead. [Why opening the file directly
> doesn't work](#why-opening-the-file-directly-doesnt-work) near the end
> explains why.

## The server: `api.py`

```python
HERE = Path(__file__).parent

@app.get("/")
def page_with_button():
    return FileResponse(HERE / "06a-load-with-button.html")

@app.get("/api/customers")
def get_customers():
    return CUSTOMERS
```

| Code                        | Meaning                                                          |
| --------------------------- | ---------------------------------------------------------------- |
| `Path(__file__).parent`     | The folder `api.py` lives in, so file paths work no matter where you run it from. |
| `FileResponse(path)`        | Send a file as-is, here an HTML page.                            |
| `return CUSTOMERS`          | A list of dicts becomes a JSON array of objects.                 |
| `print(...)`                | Prints in the **terminal running the server**, not in the browser. |

Two kinds of routes now live in one app:

| Route              | Returns | Who uses it                               |
| ------------------ | ------- | ----------------------------------------- |
| `/`, `/auto`       | HTML    | You, typing the address into the browser  |
| `/api/...`         | JSON    | The page's JavaScript, via `fetch()`      |

Prefixing data routes with `/api/` keeps the two kinds easy to tell apart.

Open http://127.0.0.1:8000/api/customers directly in the browser. That raw JSON
is exactly what `fetch()` receives.

## 06a – `fetch()` step by step

### The one-liner (countries)

```html
<button @click="fetch('/api/countries').then(r => r.json()).then(data => countries = data)">
```

1. `fetch('/api/countries')` sends a GET request and immediately returns a
   **Promise**: a placeholder for a response that hasn't arrived yet.
2. `.then(r => r.json())`: when the response arrives, read its body as JSON
   (another Promise).
3. `.then(data => countries = data)`: when that's ready, store it. `x-for`
   redraws the options.

Countries are plain strings, so `:key="country"` and `:value="country"` use the
string itself.

### The real pattern (customers)

```js
async loadCustomers(url) {
    this.loading = true;
    this.error = '';
    try {
        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Server answered ${response.status} ${response.statusText}`);
        }
        this.customers = await response.json();
    } catch (err) {
        this.customers = [];
        this.error = `Could not load customers: ${err.message}`;
    } finally {
        this.loading = false;
    }
}
```

| Piece                 | Why it's there                                                     |
| --------------------- | ------------------------------------------------------------------ |
| `async` / `await`     | Same as `.then()`, but it reads top to bottom. `await` pauses *this function* until the Promise is ready; the page stays responsive. |
| `response.ok`         | `true` for status 200–299. **`fetch()` does not throw on 404 or 500**, so you must check. |
| `response.status`     | The HTTP status code: 200 OK, 404 Not Found, 422 invalid input, 500 server error. |
| `response.json()`     | Read the body and parse it. It's also async, so it needs `await`. |
| `loading`             | Drives "Loading…" and `:disabled`, so the user can't double-click. |
| `error`               | Shown with `x-show="error"`. An empty string counts as false, so it's hidden. |
| `try / catch / finally` | `catch` handles any failure; `finally` always switches loading off. |

Click **Load from a wrong URL** to watch the error path, and keep the
browser's **Network** tab (F12 → Network) open while you click. Every request,
its status and its response are listed there. It's the most useful debugging
tool in this course.

## 06b – `x-init`: load on page open

```html
<form x-data="purchaseForm()" x-init="loadOptions()">
```

`x-init` runs once when the component starts. The arrays begin empty
(`customers: []`) and fill in a moment later. Compare the `<script>` with
lesson 05c: **only `loadOptions()` and the empty arrays are new.** Every
getter and method is unchanged, because the data has the same shape.

`getJSON(url)` wraps the fetch-check-parse steps so each request is one line.

> Alpine also calls a method named `init()` automatically if your `x-data`
> object has one, so `x-init` isn't the only way. It's used here because it's
> visible in the HTML.

## Why opening the file directly doesn't work

Double-click `06a-load-with-button.html` while `api.py` is running and click
**Load customers**. It fails. There are two separate reasons, and fixing the
first one reveals the second.

### Problem 1: the relative URL points at your disk, not the server

The page calls `fetch('/api/customers')`. A URL starting with `/` is resolved
against the address of the page that makes the request:

| Page opened as                                         | `/api/customers` becomes              |
| ------------------------------------------------------ | ------------------------------------- |
| `http://127.0.0.1:8000/`                               | `http://127.0.0.1:8000/api/customers` |
| `file:///Users/you/.../06a-load-with-button.html`      | `file:///api/customers`               |

The second is a path at the root of your hard drive. It doesn't exist, and
browsers won't `fetch()` `file://` URLs anyway. Chrome's console says
`URL scheme "file" is not supported`. Your server never sees the request.

### Problem 2: with the full address, the browser blocks the answer (CORS)

Change the call to `fetch('http://127.0.0.1:8000/api/customers')` and reload
the file. Now something confusing happens:

- The terminal running `api.py` logs `GET /api/customers 200 OK`. **The server
  answered.**
- The page still shows an error, and the console says:

  ```text
  Access to fetch at 'http://127.0.0.1:8000/api/customers' from origin 'null'
  has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present…
  ```

This is the browser's **same-origin policy**. An *origin* is the scheme, host
and port of a page: `http://127.0.0.1:8000` is one origin, and
`http://127.0.0.1:5173` is another. JavaScript may read responses only from
its own page's origin, unless the other server explicitly allows it with an
`Access-Control-Allow-Origin` header. That permission system is **CORS**
(Cross-Origin Resource Sharing).

A page opened from disk has the origin `null`, so *every* server is foreign to
it, and FastAPI sends no CORS header unless you configure one. The request
went out and the response came back, but the browser won't hand it to your
JavaScript.

The rule protects users: without it, any web page you visit could use your
logged-in browser to read your email or bank account from another site.

### Fix 1: serve the page from the same app (what this lesson does)

```python
@app.get("/")
def page_with_button():
    return FileResponse(HERE / "06a-load-with-button.html")
```

The page and the API now share one origin (`http://127.0.0.1:8000`), so
relative URLs like `/api/customers` work and CORS never comes into play. Every
lesson from here on works this way.

### Fix 2: allow a specific other origin

Real projects often run the frontend on its own server, such as a Vite dev
server on port 5173, with the API on port 8000. Two ports are two origins, so
the API has to allow the frontend explicitly:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],  # exactly the frontend's origin
    allow_methods=["*"],
    allow_headers=["*"],
)
```

FastAPI then adds `Access-Control-Allow-Origin: http://localhost:5173` to its
responses, and the browser lets that page read them. The page must use the
full URL (`http://127.0.0.1:8000/api/customers`), because a relative URL would
point at the frontend's own server.

### What about a local static server?

A common next idea is to serve the HTML with a small static file server:

```bash
python -m http.server 5500        # or VS Code's Live Server extension (also port 5500)
```

That gives the page a real origin (`http://localhost:5500`), but it's the
static server's origin, not the API's. Both problems come back in new forms:

| The page calls                                 | What actually happens                                         |
| ---------------------------------------------- | ------------------------------------------------------------- |
| `fetch('/api/customers')`                      | Goes to `http://localhost:5500/api/customers`. The **static server** answers 404, because it only has files. The API terminal logs nothing. |
| `fetch('http://127.0.0.1:8000/api/customers')` | The API logs `200 OK`, and the browser blocks it with the CORS error, because `localhost:5500` and `127.0.0.1:8000` are different origins. |

A different port is enough to make a different origin, and so is writing
`localhost` instead of `127.0.0.1`: they're the same machine but different
origins. A static server is the "frontend on its own server" setup, so it
needs Fix 2.

A static server is perfectly fine for **lessons 02–05 and 11a**, which make no
API calls. Live Server even reloads the page each time you save.

### Fix 3: have FastAPI serve the whole folder (`StaticFiles`)

Instead of one `FileResponse` route per page, FastAPI can serve a whole
directory:

```python
from fastapi.staticfiles import StaticFiles

# AFTER all the @app.get routes:
app.mount("/", StaticFiles(directory=HERE, html=True), name="pages")
```

| Piece                 | Meaning                                                       |
| --------------------- | ------------------------------------------------------------- |
| `app.mount("/", …)`   | Hand every URL that no route matched to this sub-application. |
| `StaticFiles(directory=HERE)` | Answer a URL by sending the file at that path inside `HERE`. |
| `html=True`           | A folder URL such as `/` sends that folder's `index.html`, and a missing file sends `404.html` if you've made one. |

Now every page in the folder works from the API's own origin
(`http://127.0.0.1:8000/06c-cors-experiment.html`, …) with relative URLs and
no CORS. That's also how a real FastAPI app usually serves its frontend's
built files. It's simple to write, but there's a lot going on underneath:

1. **Order matters.** A mount at `/` matches everything. Routes defined before
   it still win, but a route added *after* the mount line is unreachable,
   because the mount grabs its URL first.
2. **It serves *everything* in the directory.** The code above publishes
   `api.py` and `README.md` too. Try it: http://127.0.0.1:8000/api.py
   shows your server's source code to anyone who asks. With a real app, that
   could be a `.env` file holding database passwords. **Never point
   `StaticFiles` at a folder containing code or secrets.** Put the pages in
   their own folder and mount only that:

   ```python
   app.mount("/static", StaticFiles(directory=HERE / "static"), name="static")
   ```

3. **Files and routes share one set of URLs.** A file at `api/customers` in the
   folder would never be served, because the `/api/customers` route matches
   first, and nothing warns you. A mount at `/static` (or `/pages`) keeps
   files and routes apart.
4. **One page set per API.** Every lesson has its own `api.py` with different
   routes. Serving lesson 10's page from lesson 06's API loads fine, then fails
   on the first request to a route lesson 06 doesn't have. That's why each
   lesson folder has its own `api.py`, serving its own pages with explicit
   `FileResponse` routes, which show exactly which files are public.

### Advice

- **Use Fix 1 while learning.** One app and one origin means one less thing to
  go wrong.
- **List exact origins in `allow_origins`.** `allow_origins=["*"]` makes the
  error go away, including for `file://` pages, but it lets *any* website's
  JavaScript read your API. Use it only for a quick experiment, and never on
  an API that handles logins or private data.
- **When you see a CORS error, check the server's terminal first.** If it
  logged the request, the network and your route are fine, and the problem is
  the missing header. If it logged nothing, the URL is wrong (Problem 1).
- **CORS is enforced by browsers only.** `curl` and Python scripts ignore it,
  and `/docs` works because FastAPI serves it from the API's own origin. That's
  why the same URL can work in one place and fail in another.
  It is not a security layer for your API; anyone can still call it directly.
  Lesson 09 makes the same point about browser form validation.

## Activity

Add a `GET /api/departments` route that returns a list of department names
(`"Books"`, `"Games"`, `"Tools"` …) and a third dropdown on 06b that loads it.

### Optional: the CORS exercise

The goal is to watch each failure happen, then fix it, using
`06c-cors-experiment.html`. That page shows its own origin and has two
buttons: one calls `fetch('/api/customers')` (relative) and one calls the full
API address. Keep three things visible: the page, the browser console (F12),
and the terminal running `api.py`. For each round, write down what each button
shows **and** whether the API terminal logged a request.

**Round 1: open the file from disk.** Start `python api.py`, then double-click
`06c-cors-experiment.html`.

- The origin shows `null`. Both buttons fail with `TypeError: Failed to fetch`.
- The console gives two different reasons: `file:///api/customers` (the
  relative URL pointed at your disk) and `blocked by CORS policy`.
- The API terminal shows **one** `GET /api/customers 200 OK`: the full-address
  request did reach the server.

**Round 2: serve the page with a static server.** Leave `api.py` running and,
in a second terminal:

```bash
cd lessons/06-first-fastapi
python -m http.server 5500
```

Open http://localhost:5500/06c-cors-experiment.html.

- The origin is now `http://localhost:5500`.
- The relative button gets a **404**, and the *static server's* terminal
  logged `GET /api/customers 404`: the request went to the wrong server.
- The full-address button still fails with the CORS error, while the API
  terminal logs `200 OK`.

**Round 3: allow the static server's origin.** Add this to `api.py`, after
`app = FastAPI()`:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5500", "http://127.0.0.1:5500"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Restart `api.py` and reload the page.

- The full-address button now works.
- The relative button still gets a 404 from the static server. CORS has
  nothing to do with *where* a relative URL points.
- In DevTools → Network, click the `customers` request. Its response headers
  include `access-control-allow-origin: http://localhost:5500`. That one
  header is the whole difference between Rounds 2 and 3. (JavaScript can't
  read it; only the browser can.)

Now prove that the server doesn't block anything:

```bash
curl -i -H "Origin: http://evil.example" http://127.0.0.1:8000/api/customers
```

The response is `200 OK` with all the data, just without the
`access-control-allow-origin` header. CORS only tells *browsers* whether a
page may read the answer.

**Round 4: one origin again, with `StaticFiles`.** Remove the CORS middleware,
stop the static server, and add Fix 3's mount at the end of `api.py`, just
above `if __name__ == "__main__":`. Restart and open
http://127.0.0.1:8000/06c-cors-experiment.html.

- Both buttons work: the page and the API share an origin.
- Now open http://127.0.0.1:8000/api.py and http://127.0.0.1:8000/README.md.
  Both are served to anyone who asks.
- Fix that: move the HTML files into a `static/` folder, mount it at
  `/static`, and confirm `/api.py` now gives 404. What other URL changes do
  you need?

Finally, undo your changes to `api.py`. The other lessons assume it's back to
the original.

**Exercise questions**

1. In Round 1, why did only one of the two requests appear in the API's
   terminal?
2. In Round 2, how could you tell from the terminals alone that the relative
   request went to the wrong server?
3. Rounds 3 and 4 both make the full-address button work. Which one also
   fixes the relative button, and why?
4. What would `allow_origins=["*"]` have changed in Round 1 and in Round 3,
   and why is it a bad default?

## Checkpoint

For each piece, say whether it runs **in the browser** or **on the server**:
`x-for`, `get_customers()`, `fetch()`, `CUSTOMERS`, `toCents()`,
`print(...)`, `response.ok`, `FileResponse`.

Then stop the server (Ctrl+C) and reload `/auto`. What happens, and why?
