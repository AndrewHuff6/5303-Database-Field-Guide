# Lesson 08: routes with path parameters, called when a dropdown changes.
#
# Run:   python api.py
# Open:  http://127.0.0.1:8000

import os
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pymongo import MongoClient

HERE = Path(__file__).parent

client = MongoClient(os.getenv("MONGO_URL", "mongodb://localhost:27017"))
db = client[os.getenv("MONGO_DB", "noidx_10k")]

app = FastAPI()


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


# NEW: {product_id} in the path becomes the function's product_id argument.
# ": int" makes FastAPI convert it, and reject /api/products/abc with a 422 error.
@app.get("/api/products/{product_id}")
def get_product(product_id: int):
    doc = db.products.find_one({"_id": product_id})
    if doc is None:
        raise HTTPException(status_code=404, detail=f"Product {product_id} not found")

    product = product_out(doc)
    product["times_purchased"] = db.purchases.count_documents({"product_id": product_id})
    return product


# NEW: a customer's most recent purchases.
@app.get("/api/customers/{customer_id}/purchases")
def get_customer_purchases(customer_id: int):
    # "No such customer" (404) is a different answer from "a customer with no purchases" ([]).
    if db.customers.find_one({"_id": customer_id}, {"_id": 1}) is None:
        raise HTTPException(status_code=404, detail=f"Customer {customer_id} not found")

    docs = db.purchases.find({"customer_id": customer_id}).sort([("purchase_date", -1), ("_id", -1)]).limit(10)
    return [purchase_out(doc) for doc in docs]


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
