-- Q12 — Random sample: `ORDER BY random()` vs. random ids
--
-- What it answers: "Give me 10 random purchases."
-- Route:           GET /purchases/sample   (params: —; every route also takes db=)
-- Pattern:         random_sampling
-- Engine:          SQLite
--
-- Think about it:
-- How many rows does ORDER BY random() touch to return 10? The fast version
-- picks ids in Python first. What has to be true about purchase_id for that
-- to be a fair sample, and what could break it?

SELECT purchase_id, customer_id, product_id, amount, purchase_date
FROM purchases
ORDER BY random()
LIMIT 10;
