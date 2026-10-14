-- Q07 — 90-day spending leaderboard
--
-- What it answers: "Who were the top 20 spenders in the last 90 days, and what rank is each?"
-- Route:           GET /stats/leaderboard   (params: start, end; every route also takes db=)
-- Pattern:         window_ranking
-- Engine:          SQLite
--
-- Why it behaves this way:
-- The covering index idx_purchases_date_cust_amount (purchase_date,
-- customer_id, amount) lets SQLite read only the 90-day slice and only the
-- three columns it needs. Even so, it must still sum *every* purchase in the
-- window and sort every customer's total, because no index stores "rank".
-- Expect roughly 2× faster with the index, not 100×.

WITH spend AS (
    SELECT customer_id, SUM(amount) AS total
    FROM purchases
    WHERE purchase_date >= :start AND purchase_date < :end
    GROUP BY customer_id
)
SELECT customer_id, ROUND(total, 2) AS total,
       RANK() OVER (ORDER BY total DESC) AS rank
FROM spend
ORDER BY total DESC
LIMIT 20;
