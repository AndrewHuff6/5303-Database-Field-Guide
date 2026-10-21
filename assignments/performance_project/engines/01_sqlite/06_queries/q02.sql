-- Q02 — One page of products
--
-- What it answers: "Show me the first page of the product catalog."
-- Route:           GET /products   (params: limit, offset; every route also takes db=)
-- Pattern:         keyset_pagination
-- Engine:          SQLite
--
-- Think about it:
-- The plan says SCAN products, yet it doesn't slow down as the table grows.
-- Why not?

SELECT product_id, product_name, unit_price
FROM products
ORDER BY product_id
LIMIT :limit OFFSET :offset;
