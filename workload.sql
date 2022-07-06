DELETE FROM addresses WHERE customer_id = 1004 AND street = 'Prosta 70';

INSERT INTO addresses (customer_id, street, city, state, zip, type)
VALUES
(1004, 'Prosta 70', 'Warsaw', 'Mazovian', '05-200', 'BILLING'),
(1004, 'Prosta 70', 'Warsaw', 'Mazovian', '05-200', 'LIVING'),
(1004, 'Prosta 70', 'Warsaw', 'Mazovian', '05-200', 'SHIPPING');

DELETE FROM addresses WHERE customer_id = 1004 AND street = 'Prosta 70' AND type = 'SHIPPING';

UPDATE addresses SET type = 'SHIPPING' WHERE customer_id = 1004 AND street = 'Prosta 70' AND type = 'LIVING';
