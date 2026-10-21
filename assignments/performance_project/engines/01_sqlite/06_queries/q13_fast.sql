-- Q13 (fast) — Revenue by month: scan vs. summary table
--
-- What it answers: "Total purchases and revenue for every month."
-- Route:           GET /stats/revenue_by_month/fast   (params: —; every route also takes db=)
-- Pattern:         counting_and_summaries
-- Engine:          SQLite
--
-- Think about it:
-- No WHERE, all of history: can any index let the slow version avoid reading
-- every purchase? The fast version reads monthly_sales instead. What does it
-- give up? (Section 8 shows you.)

SELECT month, SUM(num_purchases) AS num_purchases, ROUND(SUM(revenue), 2) AS revenue
FROM monthly_sales
GROUP BY month
ORDER BY month;
