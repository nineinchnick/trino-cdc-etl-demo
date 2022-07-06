INSERT INTO mysql.inventory.addresses (id, customer_id, street, city, state, zip, type)
VALUES
(1000, 1004, 'Prosta 70', 'Warsaw', 'Mazovian', '05-200', 'BILLING'),
(1001, 1004, 'Prosta 70', 'Warsaw', 'Mazovian', '05-200', 'LIVING'),
(1002, 1004, 'Prosta 70', 'Warsaw', 'Mazovian', '05-200', 'SHIPPING');

DELETE FROM mysql.inventory.addresses WHERE id = 1001;

UPDATE mysql.inventory.addresses SET type = 'SHIPPING' WHERE id = 1002;
