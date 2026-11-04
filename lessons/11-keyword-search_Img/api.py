# Lesson 11: keyword search with a query parameter: GET /api/products?q=lamp
#
# Run:   python api.py
# Open:  http://127.0.0.1:8000

import os
import re
from datetime import datetime, timezone
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field
from pymongo import MongoClient, ReturnDocument

BASE_IMG = ""
HERE = Path(__file__).parent

client = MongoClient(os.getenv("MONGO_URL", "mongodb://localhost:27017"))
db = client[os.getenv("MONGO_DB", "store")]

app = FastAPI()

# NEW: every file under ./images is served as-is: images/a9/a96e15d9.jpg -> /images/a9/a96e15d9.jpg
app.mount("/images", StaticFiles(directory=HERE / "images"), name="images")


# ---- Integer ids from the counters collection ----


def ensure_counter(name, current_max):
    """Create a counter starting at current_max, unless it already exists."""
    db.counters.update_one(
        {"_id": name}, {"$setOnInsert": {"seq": current_max}}, upsert=True
    )


def next_id(name, count=1):
    """Reserve `count` ids in one step and return the first of them."""
    counter = db.counters.find_one_and_update(
        {"_id": name}, {"$inc": {"seq": count}}, return_document=ReturnDocument.AFTER
    )
    return counter["seq"] - count + 1


# The store CSVs were imported with mongoimport, so _id is an ObjectId and the integer id is
# its own field (customer_id, order_id, product_id). Start each counter after the largest one.
last_customer = db.customers.find_one(
    {}, {"customer_id": 1}, sort=[("customer_id", -1)]
)
ensure_counter("customer_id", last_customer["customer_id"] if last_customer else 0)

last_order = db.orders.find_one({}, {"order_id": 1}, sort=[("order_id", -1)])
ensure_counter("order_id", last_order["order_id"] if last_order else 0)


# ---- Request model: what a POST /api/customers body must look like ----


class NewCustomer(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True
    )  # trim spaces from every string

    first_name: str = Field(min_length=1, max_length=40)
    last_name: str = Field(min_length=1, max_length=40)
    email: str = Field(max_length=100, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    city: str = Field(min_length=1, max_length=60)
    state: str = Field(pattern=r"^[A-Z]{2}$")


# Only the choices the user made. No price, no total, no names.
class NewOrder(BaseModel):
    customer_id: int
    product_id: int
    quantity: int = Field(
        ge=1, le=10
    )  # ge = greater than or equal, le = less than or equal


def dollars(cents):
    """1699 -> "16.99". Prices are stored as whole cents, so the math stays exact."""
    return f"{cents // 100}.{cents % 100:02d}"


def now_text():
    """The current UTC time in the same text format the CSVs use: "2025-04-30T14:05:09Z"."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main_images(product_ids):
    """{product_id: "/images/a9/a96e15d9.jpg"} for each product's main photo, in one query."""
    # is_main came from a CSV, so it's the text "t" or "f", not a boolean.
    docs = db.product_images.find(
        {"product_id": {"$in": product_ids}, "is_main": "t"},
        {"product_id": 1, "path": 1},
    )
    return {doc["product_id"]: "/" + doc["path"] for doc in docs}


def customer_out(doc):
    return {"id": doc["customer_id"], "name": f"{doc['first_name']} {doc['last_name']}"}


def customer_detail_out(doc):
    return {
        **customer_out(doc),
        "email": doc["email"],
        "city": doc["city"],
        "state": doc["state"],
    }


def product_out(doc, image=None):
    return {
        "id": doc["product_id"],
        "name": doc["name"],
        "price": dollars(doc["price_cents"]),
        "image": image,
    }


def order_out(order, items):
    return {
        "id": order["order_id"],
        "status": order["status"],
        "total": dollars(order["total_cents"]),
        "created_at": order["created_at"][:10],  # "2025-04-30T..." -> "2025-04-30"
        "items": [
            {
                "product_name": i["product_name"],
                "quantity": i["quantity"],
                "unit_price": dollars(i["unit_price_cents"]),
            }
            for i in items
        ],
    }


@app.get("/")
def page():
    return FileResponse(HERE / "index.html")


@app.get("/local")
def local_search_page():
    return FileResponse(HERE / "11a-local-search.html")


@app.get("/api/customers")
def get_customers():
    docs = db.customers.find(
        {}, {"customer_id": 1, "first_name": 1, "last_name": 1}
    ).sort([("last_name", 1), ("first_name", 1)])
    return [customer_out(doc) for doc in docs]


# CHANGED: optional query parameters. /api/products still returns every product (up to limit),
# and /api/products?q=lamp&limit=5 returns at most 5 products with "lamp" in the name.
@app.get("/api/products")
def get_products(q: str = "", limit: int = Query(default=100, ge=1, le=100)):
    term = q.strip()
    query = {}
    if term:
        # Partial, case-insensitive match anywhere in the name ("key" finds "Keyboard").
        # re.escape makes characters like "." or "(" in the user's text match literally.
        query = {"name": {"$regex": re.escape(term), "$options": "i"}}

    docs = list(
        db.products.find(query, {"product_id": 1, "name": 1, "price_cents": 1})
        .sort("name", 1)
        .limit(limit)
    )
    # NEW: a second query fetches the main photo for just these products.
    images = main_images([doc["product_id"] for doc in docs])
    return [product_out(doc, images.get(doc["product_id"])) for doc in docs]


# {product_id} in the path becomes the function's product_id argument.
# ": int" makes FastAPI convert it, and reject /api/products/abc with a 422 error.
@app.get("/api/products/{product_id}")
def get_product(product_id: str):
    doc = db.products.find_one({"item_id": product_id})
    if doc is None:
        raise HTTPException(status_code=404, detail=f"Product {product_id} not found")

    img = db.product_images.find_one({"product_id": product_id})
    if img is None:
        raise HTTPException(status_code=404, detail=f"Image {product_id} not found")

    print(img)

    product = product_out(doc, main_images([product_id]).get(product_id))
    product["brand"] = doc["brand"]
    product["times_ordered"] = db.order_items.count_documents(
        {"product_id": product_id}
    )
    return product


# One customer.
@app.get("/api/customers/{customer_id}")
def get_customer(customer_id: int):
    doc = db.customers.find_one({"customer_id": customer_id})
    if doc is None:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")
    return customer_detail_out(doc)


# A customer's most recent orders, each with its items.
@app.get("/api/customers/{customer_id}/orders")
def get_customer_orders(customer_id: int):
    # "No such customer" (404) is a different answer from "a customer with no orders" ([]).
    if db.customers.find_one({"customer_id": customer_id}, {"_id": 1}) is None:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")

    orders = list(
        db.orders.find({"customer_id": customer_id})
        .sort([("created_at", -1), ("order_id", -1)])
        .limit(10)
    )
    items = list(
        db.order_items.find({"order_id": {"$in": [o["order_id"] for o in orders]}})
    )

    # order_items only has product_id, so look the names up in one query (a manual join).
    names = {
        p["product_id"]: p["name"]
        for p in db.products.find(
            {"product_id": {"$in": [i["product_id"] for i in items]}},
            {"product_id": 1, "name": 1},
        )
    }
    for i in items:
        i["product_name"] = names.get(i["product_id"], "(deleted product)")

    return [
        order_out(o, [i for i in items if i["order_id"] == o["order_id"]])
        for o in orders
    ]


# Create a customer. FastAPI reads the JSON body into a NewCustomer and validates it.
# If validation fails, FastAPI answers 422 itself and this function never runs.
@app.post("/api/customers", status_code=201)
def create_customer(new: NewCustomer):
    email = new.email.lower()
    if db.customers.find_one({"email": email}, {"_id": 1}):
        raise HTTPException(
            status_code=409, detail=f"A customer with email {email} already exists"
        )

    doc = {
        "customer_id": next_id("customer_id"),
        "first_name": new.first_name,
        "last_name": new.last_name,
        "email": email,
        "city": new.city,
        "state": new.state,
        "created_at": now_text(),
    }
    db.customers.insert_one(doc)
    return customer_out(doc)


# Place an order for one product: one orders document plus one order_items document.
@app.post("/api/orders", status_code=201)
def create_order(new: NewOrder):
    # 1. The IDs are valid integers and 1 <= quantity <= 10 (Pydantic checked that already).

    # 2. Confirm the customer and the product exist.
    customer = db.customers.find_one({"customer_id": new.customer_id})
    if customer is None:
        raise HTTPException(
            status_code=404, detail=f"Customer {new.customer_id} not found"
        )

    product = db.products.find_one({"product_id": new.product_id})
    if product is None:
        raise HTTPException(
            status_code=404, detail=f"Product {new.product_id} not found"
        )

    # 3. The authoritative price comes from the database, never from the request.
    unit_price_cents = product["price_cents"]
    total_cents = unit_price_cents * new.quantity

    # 4. The order and its item. The item keeps the price AT ORDER TIME, so a later price
    #    change doesn't rewrite history. total_cents must equal the sum of its items.
    order = {
        "order_id": next_id("order_id"),
        "customer_id": customer["customer_id"],
        "status": "pending",
        "total_cents": total_cents,
        "created_at": now_text(),
    }
    item = {
        "order_id": order["order_id"],
        "product_id": product["product_id"],
        "quantity": new.quantity,
        "unit_price_cents": unit_price_cents,
    }
    db.orders.insert_one(order)
    db.order_items.insert_one(item)

    # 5. Confirm what was recorded.
    return {
        "order_id": order["order_id"],
        "customer_name": f"{customer['first_name']} {customer['last_name']}",
        "product_name": product["name"],
        "quantity": new.quantity,
        "unit_price": dollars(unit_price_cents),
        "total": dollars(total_cents),
        "created_at": order["created_at"],
    }


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8001)
