USE [Partitioning Zero to Hero];
SET STATISTICS TIME, IO ON;
GO





-------------------------------------------------
--- Plain delete from unpartioned table
-------------------------------------------------

--- 0:09
DELETE FROM dbo.AccountTransactions_unpartitioned
WHERE TransactionDate>='2020-01-01' AND TransactionDate<'2021-01-01';
--WHERE YEAR(TransactionDate)=2020;







-------------------------------------------------
--- Truncating the equivalent partition in the
--- partitioned table
-------------------------------------------------

--- Look at the partitioned table:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';



BEGIN TRANSACTION;

    --- Truncate the 2020 partition:
    TRUNCATE TABLE dbo.AccountTransactions WITH (PARTITIONS (4));

ROLLBACK TRANSACTION;






-------------------------------------------------
--- Switch to another database, so we don't break
--- the upcoming RESTORE demo.

USE tempdb;
