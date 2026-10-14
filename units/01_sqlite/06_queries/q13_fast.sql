-- Q13 (fast) — Revenue by month: scan vs. summary table
--
-- What it answers: "Total purchases and revenue for every month."
-- Route:           GET /stats/revenue_by_month/fast   (params: —; every route also takes db=)
-- Pattern:         counting_and_summaries
-- Engine:          SQLite
--
-- Why it behaves this way:
-- The question covers *all* of history, so every purchase must be added up. No
-- index can avoid that. The fix is to do the adding once, ahead of time, into
-- a small table (about 36,000 rows at 1M purchases instead of 1,000,000). The
-- cost is staleness: purchases inserted after the summary was built are
-- missing until you rebuild it. Phase 4 shows this.

SELECT month, SUM(num_purchases) AS num_purchases, ROUND(SUM(revenue), 2) AS revenue
FROM monthly_sales
GROUP BY month
ORDER BY month;
