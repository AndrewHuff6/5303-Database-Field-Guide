-- Q03 — Purchases in a date range
--
-- What it answers: "Show me the first 100 purchases from the first week of March 2025."
-- Route:           GET /purchases   (params: start, end; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Think about it:
-- This is the first query where idx_* and noidx_* diverge. Put the two plans
-- side by side: which line appears in only one of them, and what work does
-- that line stand for?

SELECT purchase_id, customer_id, product_id, department, amount, purchase_date
FROM purchases
WHERE purchase_date >= :start AND purchase_date < :end
ORDER BY purchase_date, purchase_id
LIMIT 100;
