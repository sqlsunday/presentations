USE [Partitioning Zero to Hero];
GO



-------------------------------------------------
--- Switching out a partition to a regular table
-------------------------------------------------



--- Create a staging/switching table:
CREATE TABLE dbo.AccountTransactions_2022 (
    TransactionDate         date NOT NULL,
    AccountID               bigint NOT NULL,
    TransactionID           bigint NOT NULL,
    Amount                  numeric(18, 2) NOT NULL,
    Filler                  binary(250) NOT NULL DEFAULT (0x00),
    CONSTRAINT PK_AccountTransactions_2022
		PRIMARY KEY CLUSTERED (AccountID, TransactionDate, TransactionID)
		ON [Filegroup_2022]
);



--- Inspect the partitioned table:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';




--- Switch out the 2022 partition:
ALTER TABLE dbo.AccountTransactions
SWITCH PARTITION 6 TO dbo.AccountTransactions_2022;




--- Inspect the partitioned table:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';



-------------------------------------------------
--- Switch the regular table back into the
--- partition:
-------------------------------------------------




ALTER TABLE dbo.AccountTransactions_2022
SWITCH TO dbo.AccountTransactions PARTITION 6;



--- Add a CHECK constraint to the staging table
ALTER TABLE dbo.AccountTransactions_2022
    ADD CONSTRAINT I_promise_its_2022
        CHECK (TransactionDate>='2022-01-01' AND TransactionDate<'2023-01-01');



--- Try switching again:
ALTER TABLE dbo.AccountTransactions_2022
SWITCH TO dbo.AccountTransactions PARTITION 6;



--- Inspect the partitioned table:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';






-------------------------------------------------
--- Switching a partition from one partitioned
--- table to another partitioned table
---
--- Example: let's say we want to compress an
---          old partition.
-------------------------------------------------





--- Create a staging/switching table, but with partitions:
CREATE TABLE dbo.AccountTransactions_switch_with_partitions (
    TransactionDate         date NOT NULL,
    AccountID               bigint NOT NULL,
    TransactionID           bigint NOT NULL,
    Amount                  numeric(18, 2) NOT NULL,
    Filler                  binary(250) NOT NULL DEFAULT (0x00),
    CONSTRAINT PK_AccountTransactions_part
		PRIMARY KEY CLUSTERED (AccountID, TransactionDate, TransactionID)
		ON Annual(TransactionDate)
);


--- Switch out the 2018 partition:
ALTER TABLE dbo.AccountTransactions
SWITCH PARTITION 2 TO dbo.AccountTransactions_switch_with_partitions PARTITION 2;



--- Inspect the partitioned table:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';

--- Inspect the staging table:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions_switch_with_partitions';



--- Rebuild the 2018 partition of both tables:
ALTER TABLE dbo.AccountTransactions
    REBUILD PARTITION=2 WITH (DATA_COMPRESSION=PAGE);

ALTER TABLE dbo.AccountTransactions_switch_with_partitions
    REBUILD PARTITION=2 WITH (DATA_COMPRESSION=PAGE);




--- Switch back the 2018 partition:
ALTER TABLE dbo.AccountTransactions_switch_with_partitions
SWITCH PARTITION 2 TO dbo.AccountTransactions PARTITION 2;




--- Inspect the results:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';




-------------------------------------------------
--- Switch to another database, so we don't break
--- the upcoming RESTORE demo.

USE tempdb;
