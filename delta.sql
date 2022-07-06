CALL debezium.system.sync_partition_metadata('cdc', 'addresses', 'FULL');

-- delete dropped but also updated records to insert them back in in the next query
DELETE FROM latest.inventory.addresses
WHERE id IN (
    SELECT id
    FROM debezium.views.addresses
    WHERE op = 'd'
    UNION ALL
    SELECT dst.id
    FROM latest.inventory.addresses dst
    JOIN debezium.views.addresses src ON src.op != 'd' AND src.record.id = dst.id AND src.ts > dst.ts
);

-- insert missing records (new and updated)
INSERT INTO latest.inventory.addresses
SELECT record.*, ts
FROM debezium.views.addresses
WHERE op != 'd'
EXCEPT
SELECT * FROM latest.inventory.addresses;
