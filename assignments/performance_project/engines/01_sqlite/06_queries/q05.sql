-- Q05 — Count purchases in one department
--
-- What it answers: "How many purchases were in the Games department?"
-- Route:           GET /stats/department_count   (params: department; every route also takes db=)
-- Pattern:         counting_and_summaries
-- Engine:          SQLite
--
-- Think about it:
-- Find the word COVERING in the idx_* plan. What does SQLite get to skip
-- because of it? Is the indexed answer free, or does it still grow with the
-- data?

SELECT COUNT(*) AS num_purchases
FROM purchases
WHERE department = :department;
