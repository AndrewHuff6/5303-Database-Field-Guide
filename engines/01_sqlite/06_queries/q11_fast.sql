-- Q11 (fast) — Deep pagination: `OFFSET` vs. keyset
--
-- What it answers: "Show me page 18,001 of all purchases (50 per page)."
-- Route:           GET /purchases/page/fast   (params: after_id; every route also takes db=)
-- Pattern:         keyset_pagination
-- Engine:          SQLite
--
-- Think about it:
-- Run the slow version at offset 1000 and at offset 900000. What does OFFSET
-- actually do with the rows it "skips"? The fast version needs something from
-- the client that a page number doesn't give it. What, and what does that
-- cost the application?

SELECT purchase_id, customer_id, product_id, amount, purchase_date
FROM purchases
WHERE purchase_id > :after_id
ORDER BY purchase_id
LIMIT 50;
