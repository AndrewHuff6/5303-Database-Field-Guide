-- Q01 — One customer by id
--
-- What it answers: "Show me customer 42."
-- Route:           GET /customers   (params: customer_id; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Think about it:
-- This is instant in both idx_* and noidx_*, at every size. What does noidx_*
-- still have that makes that possible?

SELECT c.customer_id, c.first_name, c.last_name, c.email, c.zipcode, z.state_code
FROM customers c
JOIN zipcodes z ON z.zipcode = c.zipcode
WHERE c.customer_id = :customer_id;
