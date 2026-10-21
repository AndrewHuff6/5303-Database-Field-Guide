# Lesson 07: same routes as lesson 06, but the data now comes from MongoDB.
#
# Run:   python api.py
# Open:  http://127.0.0.1:8000

import os
from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.responses import FileResponse
from pymongo import MongoClient

HERE = Path(__file__).parent

# Connect once, when the server starts. Every request reuses this connection.
client = MongoClient(os.getenv("MONGO_URL", "mongodb://localhost:27017"))
db = client[os.getenv("MONGO_DB", "noidx_10k")]

app = FastAPI()


# ---- Converters: MongoDB document → the JSON shape the page expects ----

def customer_out(doc):
    return {"id": doc["_id"], "name": f"{doc['first_name']} {doc['last_name']}"}


def product_out(doc):
    # unit_price is a Decimal128. str() gives "202.11", the same shape lesson 06 sent.
    return {"id": doc["_id"], "name": doc["product_name"], "price": str(doc["unit_price"])}


# ---- Page ----

@app.get("/")
def page():
    return FileResponse(HERE / "index.html")


# ---- API routes ----

@app.get("/api/customers")
def get_customers():
    # find(filter, projection): {} = every customer; the projection keeps only the name fields.
    docs = db.customers.find({}, {"first_name": 1, "last_name": 1}).sort([("last_name", 1), ("first_name", 1)])
    return [customer_out(doc) for doc in docs]


@app.get("/api/products")
def get_products():
    docs = db.products.find({}, {"product_name": 1, "unit_price": 1}).sort("product_name", 1)
    return [product_out(doc) for doc in docs]


# ---- Examples for the README: why the converters exist ----

@app.get("/api/examples/raw-products")
def raw_products():
    # Returns MongoDB documents untouched. Decimal128 isn't JSON, so this route FAILS with a 500.
    return list(db.products.find().limit(3))


@app.get("/api/examples/monthly-sales")
def monthly_sales():
    # monthly_sales uses ObjectId _ids and Decimal128 revenue. Both must become strings.
    docs = db.monthly_sales.find().sort("month", -1).limit(5)
    return [
        {
            "id": str(doc["_id"]),
            "month": doc["month"],
            "state_code": doc["state_code"],
            "department": doc["department"],
            "num_purchases": doc["num_purchases"],
            "revenue": str(doc["revenue"]),
        }
        for doc in docs
    ]


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
