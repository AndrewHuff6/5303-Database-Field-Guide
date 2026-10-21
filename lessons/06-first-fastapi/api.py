# Lesson 06: the first API. No database yet, just Python lists.
#
# Run:   python api.py
# Open:  http://127.0.0.1:8000        (load with a button)
#        http://127.0.0.1:8000/auto   (load automatically with x-init)
#        http://127.0.0.1:8000/docs   (FastAPI's test page)

import json
from pathlib import Path

import uvicorn
from fastapi import FastAPI
from fastapi.responses import FileResponse

HERE = Path(__file__).parent  # the folder this file is in, wherever you run it from

app = FastAPI()

# The same lists the page used to hold in lesson 05, now living on the server.
CUSTOMERS = [
    {"id": 1, "name": "Margaret Stroustrup"},
    {"id": 2, "name": "Tim Ritchie"},
    {"id": 3, "name": "Frances Berners"},
    {"id": 4, "name": "Anita Perlman"},
    {"id": 5, "name": "Alan Allen"},
    {"id": 6, "name": "Grace Knuth"},
    {"id": 7, "name": "Katherine Johnson"},
    {"id": 8, "name": "Alan Ritchie"},
]

PRODUCTS = [
    {"id": 1, "name": "Wireless Keyboard 0", "price": "202.11"},
    {"id": 2, "name": "Portable Blender 1", "price": "259.06"},
    {"id": 3, "name": "Adjustable Monitor 2", "price": "398.52"},
    {"id": 4, "name": "Adjustable Skillet 3", "price": "322.00"},
    {"id": 5, "name": "Foldable Lamp 4", "price": "254.51"},
    {"id": 6, "name": "Stainless Lamp 5", "price": "264.04"},
    {"id": 7, "name": "Foldable Toolkit 6", "price": "218.36"},
    {"id": 8, "name": "Classic Kettle 7", "price": "256.65"},
]


# ---- Pages: send an HTML file to the browser ----

@app.get("/")
def page_with_button():
    return FileResponse(HERE / "06a-load-with-button.html")


@app.get("/auto")
def page_with_x_init():
    return FileResponse(HERE / "06b-load-with-x-init.html")


# ---- API routes: send JSON data ----

@app.get("/api/countries")
def get_countries():
    with open(HERE / "countries.json") as f:
        return json.load(f)


@app.get("/api/customers")
def get_customers():
    print("GET /api/customers was called")  # appears in the terminal, not the browser
    return CUSTOMERS


@app.get("/api/products")
def get_products():
    return PRODUCTS


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
