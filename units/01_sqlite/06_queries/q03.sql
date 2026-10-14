-- Q03 — Purchases in a date range
--
-- What it answers: "Show me the first 100 purchases from the first week of March 2025."
-- Route:           GET /purchases   (params: start, end; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Why it behaves this way:
-- In idx_* the plan is SEARCH purchases USING INDEX idx_purchases_date. SQLite
-- jumps to March 1st, reads 100 rows in date order, and stops. In noidx_* the
-- plan is SCAN purchases plus USE TEMP B-TREE FOR ORDER BY. It reads every
-- purchase, keeps the ones in range, sorts them, and then returns 100. This is
-- the first query where the two databases diverge, and the gap grows with
-- table size.

SELECT purchase_id, customer_id, product_id, department, amount, purchase_date
FROM purchases
WHERE purchase_date >= :start AND purchase_date < :end
ORDER BY purchase_date
LIMIT 100;
