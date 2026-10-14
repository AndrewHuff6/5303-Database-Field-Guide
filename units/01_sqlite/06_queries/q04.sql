-- Q04 — One customer's purchase history
--
-- What it answers: "Show me this customer's 100 most recent purchases, with product names."
-- Route:           GET /customers/purchases   (params: customer_id; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Why it behaves this way:
-- purchases.customer_id is a foreign key, and SQLite does not index foreign
-- keys automatically. In noidx_* the plan is SCAN pu, which reads the whole
-- table to find one customer's rows. In idx_* it is SEARCH pu USING INDEX
-- idx_purchases_customer (customer_id=?). The driver passes the customer with
-- the *most* purchases (the "whale" that --skew creates), so this is a worst
-- case.

SELECT pu.purchase_id, pu.purchase_date, pr.product_name, pu.department, pu.amount
FROM purchases pu
JOIN products pr ON pr.product_id = pu.product_id
WHERE pu.customer_id = :customer_id
ORDER BY pu.purchase_date DESC
LIMIT 100;
