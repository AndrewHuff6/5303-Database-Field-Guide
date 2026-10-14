-- Q09 — Revenue by state
--
-- What it answers: "Total purchases and revenue for each state."
-- Route:           GET /stats/revenue_by_state   (params: —; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Why it behaves this way:
-- This query has no WHERE, so every purchase must be read whichever database
-- you use. What the index changes is how each purchase is read. With
-- idx_purchases_cust_amount (customer_id, amount) the purchase side is a
-- COVERING INDEX, a compact copy of just the two needed columns. Without the
-- index, SQLite reads full rows.
--
-- Note: Why the index has to be covering: If you remove the covering index and
-- keep only the plain idx_purchases_customer, this query gets slower than
-- having no index at all. SQLite follows the index and then jumps back to the
-- table for amount once per row, which is a million random reads instead of
-- one sequential scan. An index can make a query worse.

SELECT z.state_code, COUNT(*) AS num_purchases, ROUND(SUM(pu.amount), 2) AS revenue
FROM purchases pu
JOIN customers c ON c.customer_id = pu.customer_id
JOIN zipcodes  z ON z.zipcode     = c.zipcode
GROUP BY z.state_code
ORDER BY revenue DESC;
