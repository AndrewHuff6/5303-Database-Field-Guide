-- Q06 — A customer's purchase streaks
--
-- What it answers: "What were this customer's longest runs of buying something on consecutive days?"
-- Route:           GET /customers/streaks   (params: customer_id; every route also takes db=)
-- Pattern:         gaps_and_islands
-- Engine:          SQLite
--
-- Why it behaves this way:
-- Consecutive dates minus their row number give the same value, so each streak
-- becomes one group. All of the expensive work is in the first step, which
-- finds this customer's rows. In idx_* that step is a SEARCH through an index;
-- in noidx_* it is a full SCAN. Read your plan to see *which* index SQLite
-- picked, because it may not be the one you would guess. Everything after that
-- step works on one customer's handful of dates, so it is cheap either way.

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
