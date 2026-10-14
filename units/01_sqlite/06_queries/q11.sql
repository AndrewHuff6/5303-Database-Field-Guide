-- Q11 — Deep pagination: `OFFSET` vs. keyset
--
-- What it answers: "Show me page 18,001 of all purchases (50 per page)."
-- Route:           GET /purchases/page   (params: offset; every route also takes db=)
-- Pattern:         keyset_pagination
-- Engine:          SQLite
--
-- Why it behaves this way:
-- OFFSET 900000 doesn't skip rows. SQLite reads 900,000 rows and throws them
-- away. The keyset version remembers the last id the client saw and uses the
-- primary key to jump straight past it (SEARCH ... (rowid>?)). The cost of
-- OFFSET grows with page depth. The cost of keyset stays the same on every
-- page. The client has to send back the last purchase_id it received instead
-- of a page number.

SELECT purchase_id, customer_id, product_id, amount, purchase_date
FROM purchases
ORDER BY purchase_id
LIMIT 50 OFFSET :offset;
