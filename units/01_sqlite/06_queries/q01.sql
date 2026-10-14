-- Q01 — One customer by id
--
-- What it answers: "Show me customer 42."
-- Route:           GET /customers   (params: customer_id; every route also takes db=)
-- Pattern:         plan basics (see 07_explain/)
-- Engine:          SQLite
--
-- Why it behaves this way:
-- customer_id is the INTEGER PRIMARY KEY, so SQLite jumps straight to the row.
-- Then it uses the primary key on zipcodes to fetch the state. Primary keys
-- are always indexed, so this query is instant in both databases at every
-- size.

SELECT c.customer_id, c.first_name, c.last_name, c.email, c.zipcode, z.state_code
FROM customers c
JOIN zipcodes z ON z.zipcode = c.zipcode
WHERE c.customer_id = :customer_id;
