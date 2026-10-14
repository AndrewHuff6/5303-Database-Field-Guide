-- Q12 — Random sample: `ORDER BY random()` vs. random ids
--
-- What it answers: "Give me 10 random purchases."
-- Route:           GET /purchases/sample   (params: —; every route also takes db=)
-- Pattern:         random_sampling
-- Engine:          SQLite
--
-- Why it behaves this way:
-- ORDER BY random() gives every row a random number and then sorts all of
-- them, a million rows sorted to keep 10. MAX(purchase_id) is a single
-- primary-key lookup, and fetching 10 ids is 10 more. The shortcut assumes ids
-- have no large gaps; heavy deletes would bias the sample (see the pattern write-up).

SELECT purchase_id, customer_id, product_id, amount, purchase_date
FROM purchases
ORDER BY random()
LIMIT 10;
