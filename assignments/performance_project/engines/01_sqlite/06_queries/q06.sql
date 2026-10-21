-- Q06 — A customer's purchase streaks
--
-- What it answers: "What were this customer's longest runs of buying something on consecutive days?"
-- Route:           GET /customers/streaks   (params: customer_id; every route also takes db=)
-- Pattern:         gaps_and_islands
-- Engine:          SQLite
--
-- Think about it:
-- Work out by hand why consecutive dates minus their row numbers land in the
-- same group. Which step of this query is the expensive one, and which index
-- did SQLite pick for it? It may not be the one you'd guess.

WITH days AS (
    SELECT DISTINCT purchase_date AS day
    FROM purchases
    WHERE customer_id = :customer_id
),
islands AS (
    SELECT day,
           julianday(day) - ROW_NUMBER() OVER (ORDER BY day) AS grp
    FROM days
)
SELECT MIN(day) AS streak_start, MAX(day) AS streak_end, COUNT(*) AS days
FROM islands
GROUP BY grp
HAVING COUNT(*) >= 2
ORDER BY days DESC, streak_start
LIMIT 10;
