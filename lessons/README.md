# Full-Stack Lessons: HTML → Alpine → FastAPI → MongoDB → Redis

Each lesson builds one purchase page a little further. The page looks the same
throughout; what changes is **where its data comes from**:

```text
hard-coded HTML  →  JavaScript arrays  →  FastAPI (hard-coded Python lists)
                 →  FastAPI + MongoDB  →  FastAPI + MongoDB + Redis cache
```

| Lesson | Folder                     | Focus                                   | Needs a server? |
| ------ | -------------------------- | --------------------------------------- | --------------- |
| 00     | `00-minimal-api`           | Preview: the smallest FastAPI app       | FastAPI + Mongo |
| 01     | `01-the-data`              | The `noidx_10k` database and the goal   | Mongo (mongosh) |
| 02     | `02-html-forms`            | Forms, labels, inputs, selects          | No              |
| 03     | `03-alpine-state`          | `x-data`, `x-text`, `x-model`, `x-show` | No              |
| 04     | `04-alpine-events`         | `@click`, `@input`, `@change`, `@submit.prevent` | No     |
| 05     | `05-local-arrays`          | `x-for`, `:key`, `:value`, `:disabled`  | No              |
| 06     | `06-first-fastapi`         | `fetch()` + GET routes with hard-coded data | FastAPI     |
| 07     | `07-mongo-reads`           | Same page, data now from MongoDB        | FastAPI + Mongo |
| 08     | `08-dependent-requests`    | Path parameters, product details, history | FastAPI + Mongo |
| 09     | `09-post-customer`         | POST, JSON bodies, Pydantic validation  | FastAPI + Mongo |
| 10     | `10-post-purchase`         | Recording a purchase with server-side pricing | FastAPI + Mongo |
| 11     | `11-keyword-search`        | Local search first, then `?q=` on the server | FastAPI + Mongo |
| 12     | `12-search-as-you-type`    | Debounce, minimum length, out-of-order responses | FastAPI + Mongo |
| 13     | `13-filter-and-sort`       | Price filters, validated sort options   | FastAPI + Mongo |
| 14     | `14-redis-cache`           | Cache-aside, expiry, invalidation; the complete app | FastAPI + Mongo + Redis |

Every folder has a `README.md` that explains each new HTML element, Alpine
directive or Python line, followed by an **Activity** and a **Checkpoint**.
Within a lesson, files are numbered (`03a-…`, `03b-…`) and each one adds a
single new idea to the one before it.

## One-time setup

```bash
cd 5303_Full_Stack_Proj
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r lessons/requirements.txt
```

MongoDB must be running locally with the `noidx_10k` database loaded. Redis is
needed only for lesson 14, and that lesson keeps working without it (you just
won't see cache hits).

## Opening the lessons

- **Lessons 02–05** are plain HTML files. Double-click one, or drag it into a
  browser. Nothing to install or run.
- **Lessons 06–14** each have an `api.py`. Start it, then open the address it
  prints:

  ```bash
  cd lessons/07-mongo-reads
  python api.py
  # open http://127.0.0.1:8000
  ```

  Only one lesson server can use port 8000 at a time. Stop the old one with
  **Ctrl+C** before starting the next. If something else already uses 8000
  (`address already in use`), start the lesson on another port instead:

  ```bash
  python -m uvicorn api:app --port 8001
  ```

## Settings

The `api.py` files in lessons 07–14 read two optional environment variables
(lesson 00 hard-codes them to stay short):

| Variable    | Default                     |
| ----------- | --------------------------- |
| `MONGO_URL` | `mongodb://localhost:27017` |
| `MONGO_DB`  | `noidx_10k`                 |

Lessons 09, 10 and 14 **write** to the database, and so does lesson 00's POST route. To keep the original data
untouched, copy it once and point the lessons at the copy:

```bash
mongosh noidx_10k --eval 'db.getCollectionNames().forEach(c => db[c].aggregate([{ $out: { db: "noidx_10k_dev", coll: c } }]))'
export MONGO_DB=noidx_10k_dev
```

## Libraries, and why so few

| Library                  | Used for                                         |
| ------------------------ | ------------------------------------------------ |
| Alpine.js (from a CDN)   | Reactive HTML without a build step               |
| Tailwind CSS (from a CDN) | Styling with utility classes (explained in lesson 02c). Delete its `<script>` and everything still works, just unstyled |
| FastAPI + Uvicorn        | Python web routes and the web server             |
| PyMongo                  | Talking to MongoDB                               |
| redis-py                 | Lesson 14 only                                   |
