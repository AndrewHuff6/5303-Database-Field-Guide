-- Q10 — Top 10 products by revenue
--
-- What it answers: "Which 10 products brought in the most money?"
-- Route:           GET /products/top   (params: —; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Think about it:
-- LIMIT 10 asks for only ten rows. Why doesn't that make the query cheap?
-- Compare its plan with Q09's.

SELECT pr.product_id, pr.product_name,
       COUNT(*) AS num_purchases, ROUND(SUM(pu.amount), 2) AS revenue
FROM purchases pu
JOIN products pr ON pr.product_id = pu.product_id
GROUP BY pr.product_id
ORDER BY revenue DESC, pr.product_id
LIMIT 10;
