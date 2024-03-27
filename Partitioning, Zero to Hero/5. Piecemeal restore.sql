USE [Partitioning Zero to Hero];


SELECT [name], is_default, is_read_only
FROM sys.filegroups
ORDER BY data_space_id;



-------------------------------------------------
--- Create backups of our filegroups:
-------------------------------------------------




--- Set the old filegroups to READ_ONLY:
ALTER DATABASE CURRENT MODIFY FILEGROUP [Filegroup_START] READ_ONLY WITH NO_WAIT;
ALTER DATABASE CURRENT MODIFY FILEGROUP [Filegroup_2019] READ_ONLY WITH NO_WAIT;
ALTER DATABASE CURRENT MODIFY FILEGROUP [Filegroup_2020] READ_ONLY WITH NO_WAIT;



--- Inspect our handiwork:
EXECUTE dbo.sp_show_partitions
    @partition_scheme_name='Annual',
    @table='dbo.AccountTransactions';



--- Take a full backup of the read-only filegroups:
--- 0:14
BACKUP DATABASE [Partitioning Zero to Hero]
    FILEGROUP='Filegroup_START',
    FILEGROUP='Filegroup_2019',
    FILEGROUP='Filegroup_2020'
    TO DISK='H:\Backup\Readonly_filegroups.bak'
    WITH COMPRESSION, FORMAT;




--- Make some changes in the "current" filegroup:
UPDATE TOP (1000) dbo.AccountTransactions
SET Filler=0x0999
WHERE TransactionDate BETWEEN '2021-02-01' AND '2021-02-28';




--- Take a full backup of the remaining (read-write) filegroups:
--- 0:14
BACKUP DATABASE [Partitioning Zero to Hero]
    FILEGROUP='PRIMARY',
    FILEGROUP='Some_filegroup',
--  FILEGROUP='Filegroup_START',
--  FILEGROUP='Filegroup_2019',
--  FILEGROUP='Filegroup_2020',
    FILEGROUP='Filegroup_2021',
    FILEGROUP='Filegroup_2022',
    FILEGROUP='Filegroup_2023',
    FILEGROUP='Filegroup_2024'
    TO DISK='H:\Backup\Full_filegroups.bak'
    WITH COMPRESSION, FORMAT;





-------------------------------------------------
--- Restore filegroups (piecemeal):
-------------------------------------------------






DROP DATABASE IF EXISTS [Partitioning Zero to Hero_restored];

--- Restore the PRIMARY filegroup to a new database:
--- 0:20
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='PRIMARY'
    FROM DISK = N'H:\Backup\Full_filegroups.bak'
    WITH PARTIAL,
         RECOVERY,
         FILE = 1,
         MOVE N'Partitioning Zero to Hero' TO N'G:\Data\Restored_PRIMARY.mdf',
         MOVE N'Partitioning Zero to Hero_log' TO N'H:\Log\Restored_log.ldf',
         NOUNLOAD;



--- View the state of the files:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];



--- Bring 2021 and 2022 online
--- 0:04
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='Filegroup_2021',
    FILEGROUP='Filegroup_2022'
    FROM DISK = N'H:\Backup\Full_filegroups.bak'
    WITH RECOVERY,
         FILE = 1,
         MOVE N'File_2021.ndf' TO N'G:\Data\Restored_2021.ndf',
         MOVE N'File_2022.ndf' TO N'G:\Data\Restored_2022.ndf',
         NOUNLOAD;



--- View the state of the files:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];




--- Try reading something from 2019 (which is not yet restored)
SELECT TOP (1000) *
FROM [Partitioning Zero to Hero_restored].dbo.AccountTransactions
WHERE TransactionDate BETWEEN '2019-01-01' AND '2019-01-31';



--- Try reading from 2021 (which we've just restored)
--- Note the "Actual partition count: 1" which means we're doing partition isolation
SELECT *
FROM [Partitioning Zero to Hero_restored].dbo.AccountTransactions
WHERE TransactionDate BETWEEN '2021-02-01' AND '2021-02-28'
  AND Filler=0x999;










--- Bring the rest of the read-write files online
--- 
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='Filegroup_2023',
    FILEGROUP='Filegroup_2024',
    FILEGROUP='Some_filegroup'
    FROM DISK = N'H:\Backup\Full_filegroups.bak'
    WITH RECOVERY,
         FILE = 1,
         MOVE N'File_2023.ndf' TO N'G:\Data\Restored_2023.ndf',
         MOVE N'File_2024.ndf' TO N'G:\Data\Restored_2024.ndf',
         MOVE N'Some_file.ndf' TO N'G:\Data\Restored_something.ndf',
         NOUNLOAD;


--- View the state of the files:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];



--- ... and the read-only files from the old backup:
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='Filegroup_START',
    FILEGROUP='Filegroup_2019',
    FILEGROUP='Filegroup_2020'
    FROM DISK = N'H:\Backup\Readonly_filegroups.bak'
    WITH RECOVERY,
         FILE = 1,
         MOVE N'File_START.ndf' TO N'G:\Data\Restored_START.ndf',
         MOVE N'File_2019.ndf'  TO N'G:\Data\Restored_2019.ndf',
         MOVE N'File_2020.ndf'  TO N'G:\Data\Restored_2020.ndf',
         NOUNLOAD;



--- Verify that we have everything:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];




-------------------------------------------------
--- Switch to another database, so we don't break
--- the upcoming RESTORE demo.

USE tempdb;
