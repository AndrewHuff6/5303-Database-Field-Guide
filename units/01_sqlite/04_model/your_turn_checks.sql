-- =============================================================================
-- your_turn_checks.sql  --  Checks for the people_products + orders data (Part B)
-- =============================================================================
-- The queries are given. For each one: write your prediction BEFORE running it,
-- then record what it returned and what that means for your design.
--
-- Run from units/01_sqlite/04_model/ so the relative paths resolve:
--
--     cd units/01_sqlite/04_model
--     sqlite3 your_turn.db
--     sqlite> .read your_turn_checks.sql
--
-- A check that finds no counterexamples prints nothing at all. Silence is a
-- result.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Staging: every column TEXT, no constraints, same as the walkthrough.
-- Declaring the tables yourself matters: if you let .import create them, it
-- guesses types, and a zip like 01114 comes back as 1114.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS raw_people;
DROP TABLE IF EXISTS raw_products;
DROP TABLE IF EXISTS raw_zips;
DROP TABLE IF EXISTS raw_orders;
DROP TABLE IF EXISTS raw_order_items;

CREATE TABLE raw_people (
    id TEXT, fname TEXT, lname TEXT, credit_card TEXT, expiration_date TEXT,
    cvv TEXT, email TEXT, gender TEXT, password TEXT, address TEXT,
    state TEXT, zip TEXT
);
CREATE TABLE raw_products (
    id TEXT, name TEXT, category TEXT, sub_category TEXT, description TEXT,
    price TEXT, inventory TEXT
);
CREATE TABLE raw_zips (
    zip TEXT, city TEXT, state TEXT, state_abbr TEXT, county TEXT,
    count_code TEXT, latitude TEXT, longitude TEXT
);
CREATE TABLE raw_orders (
    order_id TEXT, person_id TEXT, order_date TEXT, card_last4 TEXT
);
CREATE TABLE raw_order_items (
    order_id TEXT, line_no TEXT, product_id TEXT, quantity TEXT, unit_price TEXT
);

.mode csv
.import --skip 1 ../../../datasets/people_products/people.csv            raw_people
.import --skip 1 ../../../datasets/people_products/products.csv          raw_products
.import --skip 1 ../../../datasets/people_products/us_zips.csv           raw_zips
.import --skip 1 ../../../datasets/people_products/generated/classroom/orders.csv      raw_orders
.import --skip 1 ../../../datasets/people_products/generated/classroom/order_items.csv raw_order_items

.mode box
.headers on

SELECT (SELECT count(*) FROM raw_people)      AS people,
       (SELECT count(*) FROM raw_products)    AS products,
       (SELECT count(*) FROM raw_zips)        AS zips,
       (SELECT count(*) FROM raw_orders)      AS orders,
       (SELECT count(*) FROM raw_order_items) AS order_items;

-- =============================================================================
-- People
-- =============================================================================

-- P1. Is every person id unique?
SELECT count(*) AS rows, count(DISTINCT id) AS distinct_ids FROM raw_people;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P2. Is every email unique?
SELECT email, count(*) AS rows
FROM raw_people
GROUP BY email
HAVING rows > 1;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P3. Is a card number ever shared by two people?
SELECT credit_card, count(DISTINCT id) AS people
FROM raw_people
GROUP BY credit_card
HAVING people > 1;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P4. Does every person's zip exist in the lookup, in the same state?
SELECT p.id, p.zip, p.state, z.state_abbr AS lookup_state
FROM raw_people p
LEFT JOIN raw_zips z ON z.zip = p.zip
WHERE z.state_abbr IS NOT p.state;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P5. Once you have the lookup, which person columns can you derive instead of
--     store? (city isn't in people.csv at all.)
SELECT p.zip, p.state, z.city, z.county, z.latitude, z.longitude
FROM raw_people p
JOIN raw_zips z ON z.zip = p.zip
LIMIT 5;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P6. How many zips start with 0? (Did they survive loading?)
SELECT count(*) AS people_with_leading_zero_zip FROM raw_people WHERE zip GLOB '0*';
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P7. How many cards had expired by 2026-08-31, the last day of order history?
SELECT count(*) AS expired_cards FROM raw_people WHERE expiration_date < '2026-08-31';
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- P8. Which columns would you refuse to store as-is?
SELECT id, credit_card, cvv, password FROM raw_people LIMIT 3;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- =============================================================================
-- Products
-- =============================================================================

-- R1. Is every product name unique?
SELECT count(*) AS rows, count(DISTINCT name) AS distinct_names FROM raw_products;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- R2. Do rows with the same name ever have different prices?
SELECT name, count(DISTINCT price) AS prices
FROM raw_products
GROUP BY name
HAVING prices > 1;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- R3. Do rows with the same name ever have different categories?
SELECT name, count(DISTINCT category || '|' || sub_category) AS categories
FROM raw_products
GROUP BY name
HAVING categories > 1;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- R4. Do rows with the same name ever have different inventory?
SELECT count(*) AS names_with_different_inventory FROM (
    SELECT name
    FROM raw_products
    GROUP BY name
    HAVING count(DISTINCT inventory) > 1
);
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- R5. Does each sub_category belong to exactly one category?
SELECT sub_category, count(DISTINCT category) AS parents,
       group_concat(DISTINCT category) AS which
FROM raw_products
GROUP BY sub_category
HAVING parents > 1
ORDER BY parents DESC
LIMIT 10;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- R6. What do the category strings look like?
SELECT category, count(*) AS products
FROM raw_products
GROUP BY category
ORDER BY category
LIMIT 25;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- =============================================================================
-- Orders
-- =============================================================================

-- O1. Does every order point at a real person?
SELECT o.order_id, o.person_id
FROM raw_orders o
LEFT JOIN raw_people p ON p.id = o.person_id
WHERE p.id IS NULL;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- O2. Does card_last4 always match the person's card?
SELECT o.order_id, o.card_last4, substr(p.credit_card, -4) AS card_on_file
FROM raw_orders o
JOIN raw_people p ON p.id = o.person_id
WHERE o.card_last4 <> substr(p.credit_card, -4);
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- O3. Was any order placed after the customer's card expired?
SELECT o.order_id, o.order_date, p.expiration_date
FROM raw_orders o
JOIN raw_people p ON p.id = o.person_id
WHERE o.order_date >= p.expiration_date;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- O4. Does every line item point at a real product?
SELECT i.order_id, i.product_id
FROM raw_order_items i
LEFT JOIN raw_products r ON r.id = i.product_id
WHERE r.id IS NULL;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- O5. Does a line's unit_price always equal the product's current price?
SELECT count(*) AS lines,
       sum(CAST(i.unit_price AS REAL) <> CAST(r.price AS REAL)) AS lines_at_a_different_price
FROM raw_order_items i
JOIN raw_products r ON r.id = i.product_id;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- O6. What identifies a line item? Is (order_id, line_no) unique?
--     Is (order_id, product_id)?
SELECT count(*) AS lines,
       count(DISTINCT order_id || '|' || line_no)    AS distinct_order_line,
       count(DISTINCT order_id || '|' || product_id) AS distinct_order_product
FROM raw_order_items;
-- Your prediction:
-- What it returned:
-- What it means for the design:

-- O7. Which "duplicate" products actually get sold under different ids?
SELECT r.name, count(DISTINCT r.id) AS ids_sold, count(*) AS lines
FROM raw_order_items i
JOIN raw_products r ON r.id = i.product_id
GROUP BY r.name
HAVING ids_sold > 1
ORDER BY ids_sold DESC, lines DESC
LIMIT 10;
-- Your prediction:
-- What it returned:
-- What it means for the design:
