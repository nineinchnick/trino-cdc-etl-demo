WITH
src AS (
  SELECT 'addresses' AS name, count(*) AS num FROM mysql.inventory.addresses
  UNION ALL
  SELECT 'products' AS name, count(*) AS num FROM mysql.inventory.products
)
, dst AS (
  SELECT 'addresses' AS name, count(*) AS num FROM latest.inventory.addresses
  UNION ALL
  SELECT 'products' AS name, count(*) AS num FROM latest.inventory.products
)
SELECT src.num = dst.num AS matches, src.name, src.num AS src_num, dst.num AS dst_num
FROM src
JOIN dst ON src.name = dst.name;
