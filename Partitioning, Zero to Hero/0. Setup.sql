/*











    BEFORE YOU PROCEED: Make sure the database directories exist on the target server.


    TODO: Using SIMPLE recovery model could break demo #5?







*/





USE master;
GO

-------------------------------------------------------------------------------
--- Create a source database
-------------------------------------------------------------------------------

IF (DB_ID('Partitioning Zero to Hero_source') IS NOT NULL)
    DROP DATABASE [Partitioning Zero to Hero_source];
GO
CREATE DATABASE [Partitioning Zero to Hero_source]
    ON (
        NAME = N'Partitioning Zero to Hero_source',
        FILENAME = N'G:\Data\Partitioning Zero to Hero_source.mdf',
        SIZE=256MB, FILEGROWTH=256MB)
    LOG ON (
        NAME = N'Partitioning Zero to Hero_source_log',
        FILENAME = N'H:\Log\Partitioning Zero to Hero_source_log.ldf',
        SIZE=256MB, FILEGROWTH=256MB)
;
GO
USE [Partitioning Zero to Hero_source];
GO
ALTER DATABASE [Partitioning Zero to Hero_source] SET RECOVERY SIMPLE WITH NO_WAIT
GO



-------------------------------------------------------------------------------
--- Create a partition function and schema

CREATE PARTITION FUNCTION [AnnualFunction](date)
AS RANGE RIGHT
FOR VALUES ('2018-01-01', '2019-01-01', '2020-01-01', '2021-01-01', '2022-01-01', '2023-01-01');

CREATE PARTITION SCHEME [Annual]
AS PARTITION [AnnualFunction]
ALL TO ([PRIMARY]);



-------------------------------------------------------------------------------
--- Create a demo table with some data:

CREATE TABLE dbo.AccountTransactions (
    TransactionDate         date NOT NULL,
    AccountID               bigint NOT NULL,
    TransactionID           bigint NOT NULL,
    Amount                  numeric(18, 2) NOT NULL
);

CREATE UNIQUE CLUSTERED INDEX PK_AccountTransactions
    ON dbo.AccountTransactions (AccountID, TransactionDate, TransactionID)
    WITH (DATA_COMPRESSION=PAGE) ON Annual(TransactionDate);

INSERT INTO dbo.AccountTransactions WITH (TABLOCKX, HOLDLOCK) (TransactionDate, AccountID, TransactionID, Amount)
SELECT TransactionDate,
       AccountID, 
       1000000+ROW_NUMBER() OVER (ORDER BY AccountID, TransactionDate) AS TransactionID,
       Amount
FROM (
    SELECT DATEADD(day, b.column_id*b.system_type_id, '2017-12-01') AS TransactionDate,
           2200000000+CAST(CHECKSUM(a.[object_id], a.[name], a.column_id) AS bigint) AS AccountID,
           ROUND(10000.*RAND(CHECKSUM(NEWID())), 2)-5000 AS Amount
    FROM sys.columns AS a
    CROSS JOIN sys.columns AS b
    INNER JOIN sys.columns AS c ON c.[object_id]=5
    ) AS x
WHERE TransactionDate BETWEEN '2018-01-01' AND SYSDATETIME();

GO


-------------------------------------------------------------------------------
--- Create the demo database
-------------------------------------------------------------------------------



IF (DB_ID('Partitioning Zero to Hero') IS NOT NULL)
    DROP DATABASE [Partitioning Zero to Hero];
GO
CREATE DATABASE [Partitioning Zero to Hero]
    ON (
        NAME = N'Partitioning Zero to Hero',
        FILENAME = N'G:\Data\Partitioning Zero to Hero.mdf',
        SIZE=256MB, FILEGROWTH=256MB)
    LOG ON (
        NAME = N'Partitioning Zero to Hero_log',
        FILENAME = N'H:\Log\Partitioning Zero to Hero_log.ldf',
        SIZE=256MB, FILEGROWTH=256MB)
GO
USE [Partitioning Zero to Hero];
GO

ALTER DATABASE [Partitioning Zero to Hero] ADD FILEGROUP [Some_filegroup];

ALTER DATABASE [Partitioning Zero to Hero] ADD FILE (
        NAME='Some_file.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\Some_file.ndf'
    ) TO FILEGROUP [Some_filegroup];


-------------------------------------------------------------------------------
--- Create a demo table with some data:


CREATE TABLE dbo.AccountTransactions_unpartitioned (
    TransactionDateYear AS YEAR(TransactionDate) PERSISTED NOT NULL,
    TransactionDate         date NOT NULL,
    AccountID               bigint NOT NULL,
    TransactionID           bigint NOT NULL,
    Amount                  numeric(18, 2) NOT NULL,
    Filler                  binary(250) NOT NULL DEFAULT (0x00),
    CONSTRAINT PK_AccountTransactions_unpartitioned PRIMARY KEY CLUSTERED (TransactionDateYear, AccountID, TransactionDate, TransactionID)
) ON Some_Filegroup;

INSERT INTO dbo.AccountTransactions_unpartitioned (TransactionDate, AccountID, TransactionID, Amount)
SELECT TransactionDate, AccountID, TransactionID, Amount
FROM [Partitioning Zero to Hero_source].dbo.AccountTransactions;


-------------------------------------------------------------------------------
--- Same table and data, but unpartitioned:


CREATE TABLE dbo.AccountTransactions_plain (
    TransactionDate         date NOT NULL,
    AccountID               bigint NOT NULL,
    TransactionID           bigint NOT NULL,
    Amount                  numeric(18, 2) NOT NULL,
    Filler                  binary(250) NOT NULL DEFAULT (0x00),
    CONSTRAINT PK_AccountTransactions_plain PRIMARY KEY CLUSTERED (AccountID, TransactionDate, TransactionID)
) ON Some_Filegroup;

INSERT INTO dbo.AccountTransactions_plain (TransactionDate, AccountID, TransactionID, Amount)
SELECT TransactionDate, AccountID, TransactionID, Amount
FROM [Partitioning Zero to Hero_source].dbo.AccountTransactions;




GO


-------------------------------------------------------------------------------
--- sp_show_partitions utility function:
-------------------------------------------------------------------------------



CREATE OR ALTER PROCEDURE dbo.sp_show_partitions
    @partition_scheme_name  sysname,
    @table sysname
AS

    --- Collect partition function and the partition function's
    --- range boundary values
    WITH fn AS (
        SELECT ps.data_space_id,
               pf.function_id, pf.boundary_value_on_right,
               prv.boundary_id, prv.[value]
        FROM sys.partition_functions AS pf
        INNER JOIN sys.partition_range_values AS prv ON pf.function_id=prv.function_id
        INNER JOIN sys.partition_schemes AS ps ON ps.function_id=pf.function_id
        WHERE ps.[name]=@partition_scheme_name
        ),

    --- Compute the ranges
    ranges AS (
        SELECT data_space_id,
               boundary_id as partition_number,
               NULL AS lower_boundary,
               boundary_value_on_right,
               [value] AS upper_boundary
        FROM fn
        WHERE boundary_id=1
 
        UNION ALL
 
        SELECT data_space_id,
               boundary_id+1 as partition_number,
               [value] AS lower_boundary,
               boundary_value_on_right,
               LEAD([value], 1) OVER (ORDER BY boundary_id) AS upper_boundary
        FROM fn)

    --- Return the range that applies for @partition_number
    SELECT ISNULL(i.[type_desc], 'HEAP') AS [Type],
           i.[name] AS [Index name],
           ranges.partition_number AS [Partition],
           ranges.lower_boundary AS [Lower boundary],
           CAST((CASE WHEN ranges.lower_boundary IS NULL THEN '   '
                      WHEN ranges.boundary_value_on_right=0 THEN '<'
                      ELSE '<=' END) AS varchar(2))+'   '+c.[name]+N'   '+
           CAST((CASE WHEN ranges.upper_boundary IS NULL THEN ' '
                      WHEN ranges.boundary_value_on_right=1 THEN '<'
                      ELSE '<=' END) AS varchar(2)) AS [Range],
           ranges.upper_boundary AS [Upper boundary],
           fg.[name] AS [Filegroup],
           p.[rows] AS [Row count],
           p.data_compression_desc AS [Compression],
           (CASE WHEN fg.is_read_only=1 THEN 'READ_ONLY' ELSE '' END) AS [Read-only]
    FROM ranges
    LEFT JOIN sys.destination_data_spaces AS dds ON dds.partition_scheme_id=ranges.data_space_id AND dds.destination_id=ranges.partition_number
    LEFT JOIN sys.filegroups AS fg ON dds.data_space_id=fg.data_space_id
    LEFT JOIN sys.partitions AS p ON p.[object_id]=OBJECT_ID(@table) AND p.index_id IN (0, 1) AND p.partition_number=ranges.partition_number
    LEFT JOIN sys.indexes AS i ON p.[object_id]=i.[object_id] AND p.index_id=i.index_id
    LEFT JOIN sys.index_columns AS ic ON p.[object_id]=ic.[object_id] AND p.index_id=ic.index_id AND ic.partition_ordinal=1
    LEFT JOIN sys.columns AS c ON ic.[object_id]=c.[object_id] AND c.column_id=ic.column_id
    ORDER BY ranges.partition_number;

GO


-------------------------------------------------------------------------------
--- sp_truncate_partitions utility function:
-------------------------------------------------------------------------------



CREATE OR ALTER PROCEDURE dbo.sp_truncate_partitions
    @data_space_id              int,
    @first_boundary             sql_variant,
    @last_boundary              sql_variant,
    @truncate_before_first_boundary bit=0,
    @truncate_after_last_boundary bit=0
AS

SET NOCOUNT ON;

DECLARE @sql nvarchar(max)=NULL;

--- Any partitions that we can truncate right away?
SELECT @sql=ISNULL(@sql+N'
', N'')+N'TRUNCATE TABLE '+QUOTENAME(s.[name])+N'.'+QUOTENAME(t.[name])+N' WITH (PARTITIONS ('+STRING_AGG(CAST(x.partition_number AS nvarchar(10)), N', ') WITHIN GROUP (ORDER BY x.partition_number)+N'));'
FROM sys.partition_functions AS pf
INNER JOIN sys.partition_range_values AS prv ON pf.function_id=prv.function_id
INNER JOIN sys.partition_schemes AS ps ON ps.function_id=pf.function_id
INNER JOIN sys.indexes AS i ON i.data_space_id=@data_space_id AND i.index_id IN (0, 1)
INNER JOIN sys.tables AS t ON i.[object_id]=t.[object_id]
INNER JOIN sys.schemas AS s ON t.[schema_id]=s.[schema_id]
INNER JOIN sys.partitions AS p ON p.[object_id]=t.[object_id] AND p.index_id=i.index_id AND p.partition_number=prv.boundary_id AND p.[rows]>0
CROSS APPLY (
    SELECT prv.boundary_id+1 AS partition_number
    WHERE @truncate_after_last_boundary=1 AND (
          pf.boundary_value_on_right=1 AND prv.[value]>@last_boundary
       OR pf.boundary_value_on_right=0 AND prv.[value]>=@last_boundary)

    UNION ALL

    SELECT prv.boundary_id AS partition_number
    WHERE @truncate_before_first_boundary=1 AND (
          pf.boundary_value_on_right=1 AND prv.[value]<=@first_boundary
       OR pf.boundary_value_on_right=0 AND prv.[value]<@first_boundary)
    ) AS x
WHERE ps.data_space_id=@data_space_id
GROUP BY s.[name], t.[name];

PRINT @sql;

IF (@sql IS NOT NULL)
    EXECUTE sys.sp_executesql @sql;

GO
