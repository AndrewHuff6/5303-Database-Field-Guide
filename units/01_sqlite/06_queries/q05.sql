-- Q05 — Count purchases in one department
--
-- What it answers: "How many purchases were in the Games department?"
-- Route:           GET /stats/department_count   (params: department; every route also takes db=)
-- Pattern:         counting_and_summaries
-- Engine:          SQLite
--
-- Why it behaves this way:
-- In idx_* the plan is SEARCH purchases USING COVERING INDEX
-- idx_purchases_department. A covering index contains every column the query
-- needs, so SQLite counts index entries and never touches the table. In
-- noidx_* it reads every row. Note that the index still has to count every
-- Games entry. It reads fewer, smaller entries, but the answer is not free.

SELECT COUNT(*) AS num_purchases
FROM purchases
WHERE department = :department;
