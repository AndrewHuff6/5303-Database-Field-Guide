-- Q14 (fast) — State × department × month report (multi-CTE)
--
-- What it answers: "For 2025, which (state, department, month) combinations had at least 10 purchases, and which brought in the most revenue?"
-- Route:           GET /reports/cube/fast   (params: start, end, min_purchases; every route also takes db=)
-- Pattern:         multi_cte_reports
-- Engine:          SQLite
--
-- Why it behaves this way:
-- This is the trap from Q09 again. In idx_* the planner walks the zipcodes →
-- customers → purchases indexes, but department is not in any covering index.
-- So it jumps back to the table once per purchase, and the query ends up
-- slower than in noidx_*. Compare your two columns. The summary table already
-- holds exactly this (state, department, month) grain, so the rewrite is a
-- filter over a small table.

SELECT state_code, department, month, num_purchases, ROUND(revenue, 2) AS revenue
FROM monthly_sales
WHERE month >= substr(:start, 1, 7) AND month < substr(:end, 1, 7)
  AND num_purchases >= :min_purchases
ORDER BY revenue DESC, state_code, department, month  -- tiebreakers: same rows every time
LIMIT 50;
