/*

    STOP: THIS SCRIPT WILL NOT WORK IN AZURE SQL DATABASE
          OR AZURE SQL EDGE. The Azure SQL engines come
          with Read Committed Snapshot Isolation turned on
          by default, and to the best of my knowledge, it
          cannot be properly disabled.

          This means that the locking-related demos below
          will not perform as expected.

*/
SET NOCOUNT ON;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED; -- SQL Server default






-------------------------------------------------
----
---- Dirty reads
----
-------------------------------------------------

WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;

DROP TABLE IF EXISTS dbo.DirtyReads;

CREATE TABLE dbo.DirtyReads (
    Account         varchar(100) NOT NULL,
    Balance         numeric(12, 2) NOT NULL,
    PRIMARY KEY CLUSTERED (Account)
);

INSERT INTO dbo.DirtyReads (Account, Balance)
VALUES ('Alexander', 100.00),
       ('Brent',     100.00),
       ('Cathrine',  100.00),
       ('Daniel',    100.00),
       ('Emelie',    100.00);















--- 2.
BEGIN TRANSACTION;

    UPDATE dbo.DirtyReads
    SET Balance=Balance-100.00
    WHERE Account='Brent';
























--- 4.
    UPDATE dbo.DirtyReads
    SET Balance=Balance+100.00
    WHERE Account='Cathrine';




COMMIT TRANSACTION;
ROLLBACK TRANSACTION;







-------------------------------------------------
----
---- Non-repeatable reads
----
-------------------------------------------------

DROP TABLE IF EXISTS dbo.NonRepeatable;

CREATE TABLE dbo.NonRepeatable (
    Account         varchar(100) NOT NULL,
    Balance         numeric(12, 2) NOT NULL,
    PRIMARY KEY CLUSTERED (Account)
);

INSERT INTO dbo.NonRepeatable (Account, Balance)
VALUES ('Alexander', 100.00),
       ('Brent',     100.00),
       ('Cathrine',  100.00),
       ('Daniel',    100.00),
       ('Emelie',    100.00);












--- 2.
UPDATE dbo.NonRepeatable
SET Balance=0.00
WHERE Account='Brent';



















-------------------------------------------------
----
---- Phantom reads
----
-------------------------------------------------

DROP TABLE IF EXISTS dbo.PhantomReads;

CREATE TABLE dbo.PhantomReads (
    Account         varchar(100) NOT NULL,
    Balance         numeric(12, 2) NOT NULL,
    PRIMARY KEY CLUSTERED (Account)
);

INSERT INTO dbo.PhantomReads (Account, Balance)
VALUES ('Alexander', 100.00),
       ('Brent',     100.00),
       ('Cathrine',  100.00),
       ('Daniel',    100.00),
       ('Emelie',    100.00);






--- 2.
INSERT INTO dbo.PhantomReads
VALUES ('Cl�udio', 1000.00);





















-------------------------------------------------
----
---- Deadlocks
----
-------------------------------------------------

WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;

DROP TABLE IF EXISTS dbo.Deadlocks;

CREATE TABLE dbo.Deadlocks (
    Account         varchar(100) NOT NULL,
    Balance         numeric(12, 2) NOT NULL,
    PRIMARY KEY CLUSTERED (Account)
);

INSERT INTO dbo.Deadlocks (Account, Balance)
VALUES ('Alexander', 100.00),
       ('Brent',     100.00),
       ('Cathrine',  100.00),
       ('Daniel',    100.00),
       ('Emelie',    100.00);



SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


BEGIN TRANSACTION;





    --- 2.
    UPDATE dbo.Deadlocks
    SET Balance=Balance-100
    WHERE Account='Brent';






    --- 4.
    UPDATE dbo.Deadlocks
    SET Balance=Balance+100
    WHERE Account='Alexander';









COMMIT TRANSACTION;
















-------------------------------------------------
----
---- The serializable merge deadlock
----
-------------------------------------------------

WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;

--- Scenario 1:
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

--- Scenario 2:
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;



--- The original MERGE:
MERGE INTO dbo.Deadlocks AS dl
USING (
    SELECT 'Brian' AS Account, 0.00 AS Balance
    ) AS x ON dl.Account=x.Account

WHEN NOT MATCHED BY TARGET THEN
    INSERT (Account, Balance)
    VALUES (x.Account, x.Balance)

WHEN MATCHED THEN
    UPDATE
    SET dl.Balance=x.Balance;





DELETE FROM dbo.Deadlocks WHERE Account LIKE 'Brian%';



--- The reconstructed MERGE:

--- 1.
DECLARE @Account varchar(100)='Brian',
        @Balance numeric(12, 2)=0.00;
 
BEGIN TRANSACTION;
 
    IF (EXISTS (SELECT NULL FROM dbo.Deadlocks WHERE Account=@Account)) BEGIN;
 

        WAITFOR DELAY '00:00:10';

 
        UPDATE dbo.Deadlocks
        SET Balance=@Balance
        WHERE Account=@Account;
 
    END ELSE BEGIN;
 

        WAITFOR DELAY '00:00:10';

 
        INSERT INTO dbo.Deadlocks (Account, Balance)
        VALUES (@Account, @Balance);       
 
    END;
 
COMMIT TRANSACTION;











-------------------------------------------------
----
---- Update conflicts
----
-------------------------------------------------

WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;

DROP TABLE IF EXISTS dbo.UpdateConflicts;

CREATE TABLE dbo.UpdateConflicts (
    Account         varchar(100) NOT NULL,
    Balance         numeric(12, 2) NOT NULL,
    PRIMARY KEY CLUSTERED (Account)
);

INSERT INTO dbo.UpdateConflicts (Account, Balance)
VALUES ('Alexander', 100.00),
       ('Brent',     100.00),
       ('Cathrine',  100.00),
       ('Daniel',    100.00),
       ('Emelie',    100.00);


ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;

SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

BEGIN TRANSACTION;

    --- 1.
    SELECT Account, Balance
    FROM dbo.UpdateConflicts
    WHERE Account='Daniel';

    --- 2.
    UPDATE dbo.UpdateConflicts
    SET Balance=0
    WHERE Account='Daniel';












--- 5.
COMMIT TRANSACTION;
