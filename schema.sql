CREATE SCHEMA IF NOT EXISTS debezium.cdc
WITH (
    location = 's3://trino-etl/topics'
);

CREATE SCHEMA IF NOT EXISTS debezium.views
WITH (
    location = 's3://trino-etl/views'
);

CREATE SCHEMA IF NOT EXISTS latest.inventory
WITH (
    location = 's3://trino-etl/latest'
);

-- addresses
CREATE TABLE IF NOT EXISTS debezium.cdc.addresses (
  before ROW(
    id BIGINT,
    customer_id BIGINT,
    street VARCHAR,
    city VARCHAR,
    state VARCHAR,
    zip VARCHAR,
    type VARCHAR -- 'one of: SHIPPING,BILLING,LIVING'
  ),
  after ROW(
    id BIGINT,
    customer_id BIGINT,
    street VARCHAR,
    city VARCHAR,
    state VARCHAR,
    zip VARCHAR,
    type VARCHAR -- 'one of: SHIPPING,BILLING,LIVING'
  ),
  source ROW(
    version VARCHAR,
    connector VARCHAR,
    name VARCHAR,
    ts_ms BIGINT, -- 'timestamp in milliseconds'
    snapshot VARCHAR, -- 'one of: true,last,false,incremental'
    db VARCHAR,
    sequence VARCHAR,
    "table" VARCHAR,
    server_id BIGINT,
    gtid VARCHAR,
    file VARCHAR,
    pos BIGINT,
    "row" INT,
    thread BIGINT,
    query VARCHAR
  ),
  op VARCHAR,
  ts_ms BIGINT COMMENT 'timestamp in milliseconds',
  transaction ROW(
    id VARCHAR,
    total_order BIGINT,
    data_collection_order BIGINT
  ),
  partition INT
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['partition'],
    external_location = 's3://trino-etl/topics/dbserver1.inventory.addresses/'
);
CALL debezium.system.sync_partition_metadata('cdc', 'addresses', 'FULL');

CREATE OR REPLACE VIEW debezium.views.addresses AS
WITH ordered AS (
    SELECT
        COALESCE(after, before) AS record
      , op
      , ts_ms
      , ROW_NUMBER() OVER (PARTITION BY after.id ORDER BY ts_ms DESC) AS row_num
    FROM debezium.cdc.addresses
)
SELECT record, op, cast(from_unixtime_nanos(ts_ms * 1000) AS timestamp(6)) AS ts
FROM ordered
WHERE row_num = 1;

-- To keep this table up to date, run queries from delta.sql on a periodic basic
CREATE TABLE IF NOT EXISTS latest.inventory.addresses AS
SELECT
    a.record.*
  , a.ts
FROM debezium.views.addresses a
WHERE op != 'd';

-- products
CREATE TABLE IF NOT EXISTS debezium.cdc.products (
  before ROW(
    id BIGINT,
    name VARCHAR,
    description VARCHAR,
    weight DOUBLE
  ),
  after ROW(
    id BIGINT,
    name VARCHAR,
    description VARCHAR,
    weight DOUBLE
  ),
  source ROW(
    version VARCHAR,
    connector VARCHAR,
    name VARCHAR,
    ts_ms BIGINT, -- 'timestamp in milliseconds'
    snapshot VARCHAR, -- 'one of: true,last,false,incremental'
    db VARCHAR,
    sequence VARCHAR,
    "table" VARCHAR,
    server_id BIGINT,
    gtid VARCHAR,
    file VARCHAR,
    pos BIGINT,
    "row" INT,
    thread BIGINT,
    query VARCHAR
  ),
  op VARCHAR,
  ts_ms BIGINT COMMENT 'timestamp in milliseconds',
  transaction ROW(
    id VARCHAR,
    total_order BIGINT,
    data_collection_order BIGINT
  ),
  partition INT
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['partition'],
    external_location = 's3://trino-etl/topics/dbserver1.inventory.products/'
);
CALL debezium.system.sync_partition_metadata('cdc', 'products', 'FULL');

CREATE OR REPLACE VIEW debezium.views.products AS
WITH ordered AS (
    SELECT
        COALESCE(after, before) AS record
      , op
      , ts_ms
      , ROW_NUMBER() OVER (PARTITION BY after.id ORDER BY ts_ms DESC) AS row_num
    FROM debezium.cdc.products
)
SELECT record, op, cast(from_unixtime_nanos(ts_ms * 1000) AS timestamp(6)) AS ts
FROM ordered
WHERE row_num = 1;

-- To keep this table up to date, run queries from delta.sql on a periodic basic
CREATE TABLE IF NOT EXISTS latest.inventory.products AS
SELECT
    a.record.*
  , a.ts
FROM debezium.views.products a
WHERE op != 'd';
