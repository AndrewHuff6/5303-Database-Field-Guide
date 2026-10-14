-- Q12 (fast) — Random sample: `ORDER BY random()` vs. random ids
--
-- What it answers: "Give me 10 random purchases."
-- Route:           GET /purchases/sample/fast   (params: — (10 random ids chosen in Python: id1..id10); every route also takes db=)
-- Pattern:         random_sampling
-- Engine:          SQLite
--
-- Why it behaves this way:
-- ORDER BY random() gives every row a random number and then sorts all of
-- them, a million rows sorted to keep 10. MAX(purchase_id) is a single
-- primary-key lookup, and fetching 10 ids is 10 more. The shortcut assumes ids
-- have no large gaps; heavy deletes would bias the sample (see the pattern write-up).
--
-- The route picks 10 random ids in Python first:
--   max_id = SELECT MAX(purchase_id) FROM purchases
--   ids    = random.sample(range(1, max_id + 1), 10)  -> :id1 .. :id10

SELECT purchase_id, customer_id, product_id, amount, purchase_date
FROM purchases
WHERE purchase_id IN (:id1, :id2, :id3, :id4, :id5, :id6, :id7, :id8, :id9, :id10);
