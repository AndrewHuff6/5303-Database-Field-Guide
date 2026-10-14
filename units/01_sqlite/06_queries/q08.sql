-- Q08 — Products never bought in a state (anti-join)
--
-- What it answers: "Which products has nobody in Texas ever bought?"
-- Route:           GET /products/dead   (params: state; every route also takes db=)
-- Pattern:         anti_joins
-- Engine:          SQLite
--
-- Why it behaves this way:
-- For each product, the inner query asks "is there at least one Texas purchase
-- of this product?" In idx_*, idx_purchases_product lets SQLite jump to that
-- product's purchases and stop at the first Texas buyer. In noidx_* it has to
-- search the big table again for every product. Expect the biggest index win
-- in the assignment.

SELECT pr.product_id, pr.product_name
FROM products pr
WHERE NOT EXISTS (
    SELECT 1
    FROM purchases pu
    JOIN customers c ON c.customer_id = pu.customer_id
    JOIN zipcodes  z ON z.zipcode     = c.zipcode
    WHERE pu.product_id = pr.product_id
      AND z.state_code  = :state
)
ORDER BY pr.product_id
LIMIT 100;
