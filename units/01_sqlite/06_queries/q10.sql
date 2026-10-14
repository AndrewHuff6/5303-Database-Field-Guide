-- Q10 — Top 10 products by revenue
--
-- What it answers: "Which 10 products brought in the most money?"
-- Route:           GET /products/top   (params: —; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Why it behaves this way:
-- Q10 works the same way as Q09. The covering index idx_purchases_prod_amount
-- (product_id, amount) already holds purchases grouped by product, so SQLite
-- skips building a temporary B-tree for the GROUP BY. LIMIT 10 doesn't save
-- any work, because the database has to total every product before it can tell
-- which 10 are on top.

SELECT pr.product_id, pr.product_name,
       COUNT(*) AS num_purchases, ROUND(SUM(pu.amount), 2) AS revenue
FROM purchases pu
JOIN products pr ON pr.product_id = pu.product_id
GROUP BY pr.product_id
ORDER BY revenue DESC
LIMIT 10;
