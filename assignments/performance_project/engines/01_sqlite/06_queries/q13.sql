-- Q13 — Revenue by month: scan vs. summary table
--
-- What it answers: "Total purchases and revenue for every month."
-- Route:           GET /stats/revenue_by_month   (params: —; every route also takes db=)
-- Pattern:         counting_and_summaries
-- Engine:          SQLite
--
-- Think about it:
-- No WHERE, all of history: can any index let the slow version avoid reading
-- every purchase? The fast version reads monthly_sales instead. What does it
-- give up? (Section 8 shows you.)

SELECT substr(purchase_date, 1, 7) AS month,
       COUNT(*) AS num_purchases, ROUND(SUM(amount), 2) AS revenue
FROM purchases
GROUP BY month
ORDER BY month;
