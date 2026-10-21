-- Q14 — State × department × month report (multi-CTE)
--
-- What it answers: "For 2025, which (state, department, month) combinations had at least 10 purchases, and which brought in the most revenue?"
-- Route:           GET /reports/cube   (params: start, end, min_purchases; every route also takes db=)
-- Pattern:         multi_cte_reports
-- Engine:          SQLite
--
-- Think about it:
-- Compare the slow version in idx_* and noidx_*. Which one is faster, and is
-- that what you expected?
-- Hint: it's the same trap as the second half of Q09. Which column does this
-- query need that none of the indexes it walks contains?
-- The fast version reads monthly_sales. Check its grain against this query's
-- GROUP BY.

WITH base AS (
    SELECT z.state_code, pu.department,
           substr(pu.purchase_date, 1, 7) AS month, pu.amount
    FROM purchases pu
    JOIN customers c ON c.customer_id = pu.customer_id
    JOIN zipcodes  z ON z.zipcode     = c.zipcode
    WHERE pu.purchase_date >= :start AND pu.purchase_date < :end
),
cube AS (
    SELECT state_code, department, month,
           COUNT(*) AS num_purchases, SUM(amount) AS revenue
    FROM base
    GROUP BY state_code, department, month
)
SELECT state_code, department, month, num_purchases, ROUND(revenue, 2) AS revenue
FROM cube
WHERE num_purchases >= :min_purchases
ORDER BY revenue DESC, state_code, department, month  -- tiebreakers: same rows every time
LIMIT 50;
