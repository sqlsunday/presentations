--- Not so fast.
THROW
/*

    STOP: THIS SCRIPT WILL NOT WORK IN AZURE SQL DATABASE
          OR AZURE SQL EDGE. The Azure SQL engines come
          with Read Committed Snapshot Isolation turned on
          by default, and to the best of my knowledge, it
          cannot be properly disabled.

          This means that the locking-related demos below
          will not perform as expected.

*/

SET TRANSACTION ISOLATION LEVEL READ COMMITTED; -- SQL Server default






-------------------------------------------------
----
---- Dirty reads
----
-------------------------------------------------

--- Scenario 1:
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--- Scenario 2:
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED;




















--- 1.
SELECT Account, Balance
FROM dbo.DirtyReads
ORDER BY Account;













--- 3. (SELECT)
SELECT Account, Balance
FROM dbo.DirtyReads
ORDER BY Account;


--- 4. (UPDATE)
UPDATE dbo.DirtyReads
SET Balance=Balance-100
WHERE Account='Brent';





























-------------------------------------------------
----
---- Non-repeatable reads
----
-------------------------------------------------

WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;










--- Scenario 1:
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

--- Scenario 2:
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;




--- 1.
BEGIN TRANSACTION;

    SELECT Account, Balance
    FROM dbo.NonRepeatable
    WHERE Account='Brent';





    --- 3.
    SELECT Account, Balance
    FROM dbo.NonRepeatable
    WHERE Account='Brent';

ROLLBACK TRANSACTION;












-------------------------------------------------
----
---- Phantom reads
----
-------------------------------------------------

WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;




--- Scenario 1:
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

--- Scenario 2:
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;







--- 1.
BEGIN TRANSACTION;

    SELECT Account, Balance
    FROM dbo.PhantomReads
    WHERE Account BETWEEN 'B' AND 'D';




    --- 3.
    SELECT Account, Balance
    FROM dbo.PhantomReads
    WHERE Account BETWEEN 'B' AND 'D';

ROLLBACK TRANSACTION;












-------------------------------------------------
----
---- Deadlocks
----
-------------------------------------------------


















WHILE (@@TRANCOUNT>0) ROLLBACK TRANSACTION;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;


--- 0b.
BEGIN TRANSACTION;


    --- 1.
    UPDATE dbo.Deadlocks
    SET Balance=Balance-100
    WHERE Account='Alexander';




    --- 3.
    UPDATE dbo.Deadlocks
    SET Balance=Balance+100
    WHERE Account='Brent';











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
































--- The reconstructed MERGE:

--- 1.2
DECLARE @Account varchar(100)='Brian, too',
        @Balance numeric(12, 2)=0.00;
 
BEGIN TRANSACTION;
 
    IF (EXISTS (SELECT NULL FROM dbo.Deadlocks
                WHERE Account=@Account)) BEGIN;
 

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



















SET TRANSACTION ISOLATION LEVEL SNAPSHOT;



--- 0b.
BEGIN TRANSACTION;






    --- 2.
    SELECT Account, Balance
    FROM dbo.UpdateConflicts
    WHERE Account='Daniel';






    --- 4.
    SELECT Account, Balance
    FROM dbo.UpdateConflicts
    WHERE Account='Daniel';

    --- 5.
    UPDATE dbo.UpdateConflicts
    SET Balance=99999
    WHERE Account='Daniel';


COMMIT TRANSACTION;
