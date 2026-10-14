-- Q15 — Insert a purchase
--
-- What it answers: Inserts one purchase inside a transaction and returns the new row with status 201. If the database stays locked longer than the busy timeout, it returns 503.
-- Route:           POST /purchases   (params: JSON body; every route also takes db=)
-- Pattern:         — (see 08_concurrency/)
-- Engine:          SQLite
--
-- Think about it:
-- SQLite allows one writer at a time for the whole file. What happens to a
-- second writer that arrives while the first is busy? Section 8 is where you
-- find out.
--
-- The route runs this with run_write(), inside a transaction.

INSERT INTO purchases
    (customer_id, card_id, product_id, department, amount, purchase_date)
VALUES (:customer_id, :card_id, :product_id, :department, :amount, :purchase_date)
RETURNING purchase_id, customer_id, product_id, department, amount, purchase_date;
