-- Q09 — Revenue by state
--
-- What it answers: "Total purchases and revenue for each state."
-- Route:           GET /stats/revenue_by_state   (params: —; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Think about it:
-- There's no WHERE, so both databases must read every purchase. Then why is
-- idx_* still faster? One word in its plan explains it.
-- Then try this on a scratch copy of idx_1m.db (never the original): run
-- DROP INDEX idx_purchases_cust_amount; so only the plain index on
-- customer_id is left, and time the query again. Predict first: faster or
-- slower than noidx_1m? Is an index always better than no index? (At 100k the
-- answer looks different. Why might size matter?)

SELECT z.state_code, COUNT(*) AS num_purchases, ROUND(SUM(pu.amount), 2) AS revenue
FROM purchases pu
JOIN customers c ON c.customer_id = pu.customer_id
JOIN zipcodes  z ON z.zipcode     = c.zipcode
GROUP BY z.state_code
ORDER BY revenue DESC, z.state_code;
