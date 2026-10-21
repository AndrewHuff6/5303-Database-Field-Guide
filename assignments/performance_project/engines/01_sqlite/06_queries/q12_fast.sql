-- Q12 (fast) — Random sample: `ORDER BY random()` vs. random ids
--
-- What it answers: "Give me 10 random purchases."
-- Route:           GET /purchases/sample/fast   (params: — (10 random ids chosen in Python: id1..id10); every route also takes db=)
-- Pattern:         random_sampling
-- Engine:          SQLite
--
-- Think about it:
-- How many rows does ORDER BY random() touch to return 10? The fast version
-- picks ids in Python first. What has to be true about purchase_id for that
-- to be a fair sample, and what could break it?
--
-- The route picks 10 random ids in Python first:
--   max_id = SELECT MAX(purchase_id) FROM purchases
--   ids    = random.sample(range(1, max_id + 1), 10)  -> :id1 .. :id10

SELECT purchase_id, customer_id, product_id, amount, purchase_date
FROM purchases
WHERE purchase_id IN (:id1, :id2, :id3, :id4, :id5, :id6, :id7, :id8, :id9, :id10)
ORDER BY purchase_id;
