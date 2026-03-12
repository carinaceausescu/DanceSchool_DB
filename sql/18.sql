--18

READ UNCOMMITTED – Dirty Read 
--Doar teoretic, nu va rula
--T1 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
UPDATE ABONAMENT 
SET nr_sedinte = nr_sedinte - 1 
WHERE abonament_id = 1; 

--T2 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
SELECT nr_sedinte 
FROM ABONAMENT 
WHERE abonament_id = 1; 
COMMIT; 

--T1  - continuare 
ROLLBACK; 

READ COMMITTED – Non-repeatable Read 
--T1
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT nr_sedinte
FROM ABONAMENT
WHERE abonament_id = 1;

--T2 - rulez un alt tab fara sa dau commit la T1
UPDATE ABONAMENT;
SET nr_sedinte = nr_sedinte - 1;
WHERE abonament_id = 1;
COMMIT;

--T1
SELECT nr_sedinte
FROM ABONAMENT
WHERE abonament_id = 1;
COMMIT;

REPEATABLE READ 
-- T1
--Citesc elevii cu o sedinta ramasa
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--repeatable read nu exista in Oracle, dar poate fi simulat cu seriazable
SELECT elev_id
FROM ABONAMENT
WHERE nr_sedinte = 1;

--T2 - in paralel
UPDATE ABONAMENT
SET nr_sedinte = nr_sedinte - 1
WHERE abonament_id = 6; --id-ul abonamentului elevului 2
COMMIT;

-- T1
--dupa T2 mai rulez o data aceeasi comanda
SELECT elev_id
FROM ABONAMENT
WHERE nr_sedinte = 1;
COMMIT;

SERIALIZABLE 
-- T1
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM ABONAMENT WHERE elev_id = 5 AND activ = 'DA';
COMMIT;

--T2
INSERT INTO ABONAMENT (elev_id, nr_sedinte, pret, perioada_start, perioada_end, activ)
VALUES ( 5, 10, 200, SYSDATE, SYSDATE + 30, 'DA');
COMMIT;

--T1
COMMIT;