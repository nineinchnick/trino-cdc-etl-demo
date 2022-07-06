WITH
latest_addresses AS (
    -- all columns except op and ts
    SELECT id, customer_id, street, city, state, zip, type
    FROM latest.inventory.addresses
)
, latest_products AS (
    -- all columns except op and ts
    SELECT id, name, description, weight
    FROM latest.inventory.products
)
, delta AS (
  SELECT
    'addresses' AS name
    , (SELECT count(*) FROM mysql.inventory.addresses) AS num_total
    , (SELECT count(*) FROM (TABLE mysql.inventory.addresses EXCEPT TABLE latest_addresses)) AS num_missing
    , (SELECT count(*) FROM (TABLE latest_addresses EXCEPT TABLE mysql.inventory.addresses)) AS num_stale
  UNION ALL
  SELECT
    'products' AS name
    , (SELECT count(*) FROM mysql.inventory.products) AS num_total
    , (SELECT count(*) FROM (TABLE mysql.inventory.products EXCEPT TABLE latest_products)) AS num_missing
    , (SELECT count(*) FROM (TABLE latest_products EXCEPT TABLE mysql.inventory.products)) AS num_stale
)
SELECT
    num_missing = 0 AND num_stale = 0 AS result
  , name
  , num_missing
  , num_stale
  , num_total
FROM delta;
