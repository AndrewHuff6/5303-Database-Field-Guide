# 00 – The minimal FastAPI app

This folder is a preview of where the course is going: one small Python file that
answers three kinds of requests. You don't need to understand every line yet;
lessons 06–10 rebuild these routes slowly. Run it now to check that your
Python, FastAPI and MongoDB setup works.

## Run it

```bash
cd lessons/00-minimal-api
python api.py
```

You should see `Uvicorn running on http://127.0.0.1:8000`. Leave it running and
open these in your browser:

| URL                                 | What you get                                        |
| ----------------------------------- | --------------------------------------------------- |
| http://127.0.0.1:8000/api/countries | A JSON array of country names from `countries.json` |
| http://127.0.0.1:8000/api/users     | Ten customers read from MongoDB                     |
| http://127.0.0.1:8000/docs          | FastAPI's built-in test page for every route        |

A browser address bar can only send GET requests. To try the POST route, open
`/docs`, expand **POST /api/purchases**, click **Try it out**, and send:

```json
{
  "customer_id": 1,
  "card_id": 1,
  "product_id": 1,
  "amount": "202.11"
}
```

Then check it in `mongosh`:

```js
use noidx_10k
db.purchases.find().sort({ _id: -1 }).limit(1)
```

Stop the server with **Ctrl+C**.

## Read the code top to bottom

| Code                                       | What it does                                                                        |
| ------------------------------------------ | ----------------------------------------------------------------------------------- |
| `app = FastAPI()`                          | Creates the web application. Routes get attached to `app`.                          |
| `MongoClient("mongodb://localhost:27017")` | Opens a connection to the MongoDB server on your machine.                           |
| `db = client["noidx_10k"]`                 | Picks the database. `db.customers`, `db.purchases`, … are its collections.          |
| `@app.get("/api/countries")`               | A *decorator*: "when a GET request arrives for this path, call the function below." |
| `return json.load(f)`                      | Whatever a route returns (list, dict, number, string) is sent back as JSON.         |
| `.find({}, {...}).limit(10)`               | `{}` matches every document; the second dict picks which fields come back.          |
| `@app.post(...)` + `purchase: dict`        | A POST route. FastAPI parses the JSON body into a Python `dict` for you.            |
| `find_one_and_update(... "$inc" ...)`      | Adds 1 to the purchase counter and returns the new value, in one step.              |
| `if __name__ == "__main__":`               | True only when you run `python api.py` directly, not when another file imports it.  |
| `uvicorn.run(app, ...)`                    | Uvicorn is the web server; it listens on port 8000 and hands requests to `app`.     |

## What this version leaves out (on purpose)

- **Validation.** The POST route stores whatever JSON it receives, including
  missing or wrong fields. Lesson 09 adds a Pydantic model for this.
- **Price lookup.** The client sends `amount`, so it could send any price.
  In lesson 10 the server looks up the real price itself.
- **A web page.** There's no HTML yet. Lesson 06 has FastAPI serve the page
  and the data from the same app.

## Notes

- `open("countries.json")` is relative to the folder you run the command from,
  so `cd` into this folder first. Later lessons build the path from the location
  of `api.py` so it works from anywhere.
- `_id` values in `noidx_10k` are plain integers, so documents convert to JSON
  without trouble. Lesson 07 shows what to do with `ObjectId` and `Decimal128`
  values, which don't convert on their own.
