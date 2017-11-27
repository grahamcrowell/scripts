USE gcDev
GO

-- CREATE TABLE BST (N int, P int);

-- INSERT INTO BST VALUES('1','2'); 
-- INSERT INTO BST VALUES('3','2'); 
-- INSERT INTO BST VALUES('5','6'); 
-- INSERT INTO BST VALUES('7','6'); 
-- INSERT INTO BST VALUES('2','4'); 
-- INSERT INTO BST VALUES('6','4'); 
-- INSERT INTO BST VALUES('4','15'); 
-- INSERT INTO BST VALUES('8','9'); 
-- INSERT INTO BST VALUES('10','9'); 
-- INSERT INTO BST VALUES('12','13'); 
-- INSERT INTO BST VALUES('14','13'); 
-- INSERT INTO BST VALUES('9','11'); 
-- INSERT INTO BST VALUES('13','11'); 
-- INSERT INTO BST VALUES('11','15'); 
-- INSERT INTO BST VALUES('15',NULL); 


;WITH anchor AS (

    SELECT *
    FROM BST 
    WHERE P IS NULL
), iter AS (
    SELECT BST.N, BST.P
    FROM BST
    JOIN anchor
    ON BST.P = anchor.N
)
SELECT *
FROM iter