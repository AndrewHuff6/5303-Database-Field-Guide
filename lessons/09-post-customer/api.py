# Lesson 09: the first POST route. Register a customer, with validation.
#
# Run:   python api.py
# Open:  http://127.0.0.1:8000

import os
from pathlib import Path
from typing import Literal

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field
from pymongo import MongoClient, ReturnDocument

HERE = Path(__file__).parent

client = MongoClient(os.getenv("MONGO_URL", "mongodb://localhost:27017"))
db = client[os.getenv("MONGO_DB", "noidx_10k")]

app = FastAPI()


# ---- Integer ids from the counters collection ----

def ensure_counter(name, current_max):
    """Create a counter starting at current_max, unless it already exists."""
    db.counters.update_one({"_id": name}, {"$setOnInsert": {"seq": current_max}}, upsert=True)


def next_id(name, count=1):
    """Reserve `count` ids in one step and return the first of them."""
    counter = db.counters.find_one_and_update(
        {"_id": name}, {"$inc": {"seq": count}}, return_document=ReturnDocument.AFTER
    )
    return counter["seq"] - count + 1


# noidx_10k only has a purchase_id counter, so start the other two after the existing ids.
last_customer = db.customers.find_one({}, {"_id": 1}, sort=[("_id", -1)])
ensure_counter("customer_id", last_customer["_id"] if last_customer else 0)

top_card = next(db.customers.aggregate([
    {"$unwind": "$cards"},
    {"$group": {"_id": None, "max": {"$max": "$cards.card_id"}}},
]), None)
ensure_counter("card_id", top_card["max"] if top_card else 0)


# ---- Request model: what a POST /api/customers body must look like ----

class NewCustomer(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)  # trim spaces from every string

    first_name: str = Field(min_length=1, max_length=40)
    last_name: str = Field(min_length=1, max_length=40)
    email: str = Field(max_length=100, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    address: str = Field(min_length=1, max_length=100)
    zipcode: str = Field(pattern=r"^\d{5}$")
    state_code: str = Field(pattern=r"^[A-Z]{2}$")
    card_type: Literal["americanexpress", "discover", "mastercard", "visa"]
    card_number: str = Field(pattern=r"^\d{16}$")


def customer_out(doc):
    return {"id": doc["_id"], "name": f"{doc['first_name']} {doc['last_name']}"}


def product_out(doc):
    return {"id": doc["_id"], "name": doc["product_name"], "price": str(doc["unit_price"])}


def purchase_out(doc):
    return {
        "id": doc["_id"],
        "product_name": doc["product_name"],
        "amount": str(doc["amount"]),
        "department": doc["department"],
        "purchase_date": doc["purchase_date"].date().isoformat(),  # "2026-04-30"
    }


@app.get("/")
def page():
    return FileResponse(HERE / "index.html")


@app.get("/api/customers")
def get_customers():
    docs = db.customers.find({}, {"first_name": 1, "last_name": 1}).sort([("last_name", 1), ("first_name", 1)])
    return [customer_out(doc) for doc in docs]


@app.get("/api/products")
def get_products():
    docs = db.products.find({}, {"product_name": 1, "unit_price": 1}).sort("product_name", 1)
    return [product_out(doc) for doc in docs]


# {product_id} in the path becomes the function's product_id argument.
# ": int" makes FastAPI convert it, and reject /api/products/abc with a 422 error.
@app.get("/api/products/{product_id}")
def get_product(product_id: int):
    doc = db.products.find_one({"_id": product_id})
    if doc is None:
        raise HTTPException(status_code=404, detail=f"Product {product_id} not found")

    product = product_out(doc)
    product["times_purchased"] = db.purchases.count_documents({"product_id": product_id})
    return product


# A customer's most recent purchases.
@app.get("/api/customers/{customer_id}/purchases")
def get_customer_purchases(customer_id: int):
    # "No such customer" (404) is a different answer from "a customer with no purchases" ([]).
    if db.customers.find_one({"_id": customer_id}, {"_id": 1}) is None:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")

    docs = db.purchases.find({"customer_id": customer_id}).sort([("purchase_date", -1), ("_id", -1)]).limit(10)
    return [purchase_out(doc) for doc in docs]


# NEW: create a customer. FastAPI reads the JSON body into a NewCustomer and validates it.
# If validation fails, FastAPI answers 422 itself and this function never runs.
@app.post("/api/customers", status_code=201)
def create_customer(new: NewCustomer):
    email = new.email.lower()
    if db.customers.find_one({"email": email}, {"_id": 1}):
        raise HTTPException(status_code=409, detail=f"A customer with email {email} already exists")

    doc = {
        "_id": next_id("customer_id"),
        "first_name": new.first_name,
        "last_name": new.last_name,
        "email": email,
        "address": new.address,
        "zipcode": new.zipcode,
        "state_code": new.state_code,
        "cards": [
            {"card_id": next_id("card_id"), "card_type": new.card_type, "card_number": new.card_number},
        ],
    }
    db.customers.insert_one(doc)
    return customer_out(doc)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
