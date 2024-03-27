USE [Partitioning Zero to Hero];
GO



-------------------------------------------------
--- Add a file and split a partition
-------------------------------------------------





--- Inspect the partitions:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';



--- Let's add another filegroup:
ALTER DATABASE CURRENT ADD FILEGROUP [Filegroup_2024];



--- ... and a new data file to attach to it:
ALTER DATABASE CURRENT ADD FILE (
        NAME='File_2024.ndf',
        SIZE=256MB, FILEGROWTH=256MB,
        FILENAME='G:\Data\File_2024.ndf'
    ) TO FILEGROUP [Filegroup_2024];



--- Tell the partition scheme where to grow:
ALTER PARTITION SCHEME [Annual] NEXT USED [Filegroup_2024];




--- Inspect the partitions:
--- We want to split the last partition by inserting a new boundary.
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';



--- ... at 2024-01-01:
ALTER PARTITION FUNCTION AnnualFunction() SPLIT RANGE ('2024-01-01');




--- Inspect the partitions:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';




-------------------------------------------------
--- Merge the first partition and delete the file
-------------------------------------------------







--- I'll delete anything before 2019-01-01:
TRUNCATE TABLE dbo.AccountTransactions WITH (PARTITIONS (1 TO 2));



--- Inspect the partitions:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';



--- Merge the first two partitions by removing the boundary at 2018-01-01:
ALTER PARTITION FUNCTION AnnualFunction() MERGE RANGE ('2018-01-01');



--- We're not using this file or filegroup anymore, so we can clean that up, too:
ALTER DATABASE CURRENT REMOVE FILE [File_2018.ndf];
ALTER DATABASE CURRENT REMOVE FILEGROUP [Filegroup_2018];



--- Inspect the partitions:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';






-------------------------------------------------
--- Switch to another database, so we don't break
--- the upcoming RESTORE demo.

USE tempdb;
