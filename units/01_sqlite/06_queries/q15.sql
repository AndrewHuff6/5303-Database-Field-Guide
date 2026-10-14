-- Q15 — Insert a purchase
--
-- What it answers: Inserts one purchase inside a transaction and returns the new row with status 201. If the database stays locked longer than the busy timeout, it returns 503.
-- Route:           POST /purchases   (params: JSON body; every route also takes db=)
-- Pattern:         — (see 08_concurrency/)
-- Engine:          SQLite
--
-- Why it behaves this way:
-- SQLite allows one writer at a time for the whole file. When a second writer
-- arrives, it waits up to busy_timeout milliseconds for the lock. If the lock
-- is still held after that, it fails with database is locked. WAL mode lets
-- readers continue while someone writes, but it never allows two writers at
-- once. 08_concurrency/ explains how to measure this.
--
-- Run inside a transaction (`with db:` in Python). A locked database
-- after busy_timeout returns HTTP 503 "database is locked".

INSERT INTO purchases
    (customer_id, card_id, product_id, department, amount, purchase_date)
VALUES (:customer_id, :card_id, :product_id, :department, :amount, :purchase_date)
RETURNING purchase_id, customer_id, product_id, department, amount, purchase_date;
