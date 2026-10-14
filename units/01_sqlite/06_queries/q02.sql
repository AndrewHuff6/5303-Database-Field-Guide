-- Q02 — One page of products
--
-- What it answers: "Show me the first page of the product catalog."
-- Route:           GET /products   (params: limit, offset; every route also takes db=)
-- Pattern:         keyset_pagination
-- Engine:          SQLite
--
-- Why it behaves this way:
-- The plan says SCAN products, but SQLite walks the table in primary-key order
-- and stops after 50 rows. A "scan" that stops early is cheap. Q11 shows what
-- happens when the offset is large.

SELECT product_id, product_name, unit_price
FROM products
ORDER BY product_id
LIMIT :limit OFFSET :offset;
