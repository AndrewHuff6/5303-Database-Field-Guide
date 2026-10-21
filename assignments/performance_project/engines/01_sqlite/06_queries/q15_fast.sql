-- Q15 /fast — Insert many purchases in one transaction
--
-- What it answers: Inserts every purchase in the request body, then commits once. Returns the new rows with status 201, or 503 if the database stays locked longer than the busy timeout.
-- Route:           POST /purchases/fast   (params: JSON array body; every route also takes db=)
-- Pattern:         — (see 08_concurrency/)
-- Engine:          SQLite
--
-- Think about it:
-- This is the same INSERT as Q15. The route runs it once per purchase, but
-- inside one transaction with one commit. Compare purchases per second with
-- Q15 under the same load. What does a commit cost that a single INSERT
-- doesn't?
--
-- The route runs this with run_write_many(), inside one transaction.

INSERT INTO purchases
    (customer_id, card_id, product_id, department, amount, purchase_date)
VALUES (:customer_id, :card_id, :product_id, :department, :amount, :purchase_date)
RETURNING purchase_id, customer_id, product_id, department, amount, purchase_date;
