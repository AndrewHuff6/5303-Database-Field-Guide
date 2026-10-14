-- Q07 — 90-day spending leaderboard
--
-- What it answers: "Who were the top 20 spenders in the last 90 days, and what rank is each?"
-- Route:           GET /stats/leaderboard   (params: start, end; every route also takes db=)
-- Pattern:         window_ranking
-- Engine:          SQLite
--
-- Think about it:
-- The index helps here, but far less than it helps Q03 or Q04. What work must
-- every version of this query do, index or not?
-- Hint: what has to happen before anyone can be given a rank?

WITH spend AS (
    SELECT customer_id, SUM(amount) AS total
    FROM purchases
    WHERE purchase_date >= :start AND purchase_date < :end
    GROUP BY customer_id
)
SELECT customer_id, ROUND(total, 2) AS total,
       RANK() OVER (ORDER BY total DESC) AS rank
FROM spend
ORDER BY total DESC, customer_id
LIMIT 20;
