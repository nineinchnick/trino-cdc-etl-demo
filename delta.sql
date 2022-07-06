CALL debezium.system.sync_partition_metadata('cdc', 'addresses', 'FULL');

-- get latest ts across all records and only process changes since then

-- delete dropped but also updated records to insert them back in in the next query
DELETE FROM latest.inventory.addresses
WHERE id IN (
    SELECT b.record.id
    FROM debezium.views.addresses b
    WHERE b.ts > (SELECT coalesce(max(a.ts), timestamp '0000-01-01') FROM latest.inventory.addresses a)
);

-- insert missing records (new and updated)
INSERT INTO latest.inventory.addresses
SELECT b.record.*, b.ts
FROM debezium.views.addresses b
WHERE b.op != 'd' AND b.ts > (SELECT coalesce(max(a.ts), timestamp '0000-01-01') FROM latest.inventory.addresses a);


CALL debezium.system.sync_partition_metadata('cdc', 'products', 'FULL');

-- get latest ts across all records and only process changes since then

-- delete dropped but also updated records to insert them back in in the next query
DELETE FROM latest.inventory.products
WHERE id IN (
    SELECT b.record.id
    FROM debezium.views.products b
    WHERE b.ts > (SELECT coalesce(max(a.ts), timestamp '0000-01-01') FROM latest.inventory.products a)
);

-- insert missing records (new and updated)
INSERT INTO latest.inventory.products
SELECT b.record.*, b.ts
FROM debezium.views.products b
WHERE b.op != 'd' AND b.ts > (SELECT coalesce(max(a.ts), timestamp '0000-01-01') FROM latest.inventory.products a);
