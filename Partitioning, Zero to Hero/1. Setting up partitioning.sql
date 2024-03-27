USE [Partitioning Zero to Hero];
GO



-------------------------------------------------
--- Create the filegroups:
-------------------------------------------------

ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_START];
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2018];
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2019];
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2020];
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2021];
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2022];
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2023];







-------------------------------------------------
--- Add files to the filegroups:
-------------------------------------------------

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_START.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_START.ndf'
    ) TO FILEGROUP [Filegroup_START];

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2018.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2018.ndf'
    ) TO FILEGROUP [Filegroup_2018];

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2019.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2019.ndf'
    ) TO FILEGROUP [Filegroup_2019];

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2020.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2020.ndf'
    ) TO FILEGROUP [Filegroup_2020];

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2021.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2021.ndf'
    ) TO FILEGROUP [Filegroup_2021];

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2022.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2022.ndf'
    ) TO FILEGROUP [Filegroup_2022];

ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2023.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2023.ndf'
    ) TO FILEGROUP [Filegroup_2023];





-------------------------------------------------
--- Create the partition function:
-------------------------------------------------




CREATE PARTITION FUNCTION [AnnualFunction](date)
AS RANGE RIGHT
FOR VALUES ('2018-01-01', '2019-01-01', '2020-01-01', '2021-01-01', '2022-01-01', '2023-01-01');



-------------------------------------------------
--- Create the partition scheme:
-------------------------------------------------



CREATE PARTITION SCHEME [Annual]
AS PARTITION [AnnualFunction]
TO ([Filegroup_START], [Filegroup_2018], [Filegroup_2019], [Filegroup_2020], [Filegroup_2021], [Filegroup_2022], [Filegroup_2023]);






-------------------------------------------------
--- Create the table:
-------------------------------------------------



CREATE TABLE dbo.AccountTransactions (
    TransactionDate         date NOT NULL,
    AccountID               bigint NOT NULL,
    TransactionID           bigint NOT NULL,
    Amount                  numeric(18, 2) NOT NULL,
    Filler                  binary(250) NOT NULL DEFAULT (0x00),
    CONSTRAINT PK_AccountTransactions
		PRIMARY KEY CLUSTERED (AccountID, TransactionDate, TransactionID)
		ON Annual(TransactionDate)
);




-------------------------------------------------
--- And load some data:
-------------------------------------------------


--- 0:35
INSERT INTO dbo.AccountTransactions (TransactionDate, AccountID, TransactionID, Amount)
SELECT TransactionDate, AccountID, TransactionID, Amount
FROM [Partitioning Zero to Hero_source].dbo.AccountTransactions;


--- Look at the results:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';








-------------------------------------------------
--- Switch to another database, so we don't break
--- the upcoming RESTORE demo.

USE tempdb;
