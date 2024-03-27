ALTER DATABASE [Partitioning Zero to Hero] SET RECOVERY FULL;
GO
USE [Partitioning Zero to Hero];
GO




--- Make some changes in the "current" filegroup:
UPDATE TOP (1000) dbo.AccountTransactions
SET Filler=0x0123
WHERE TransactionDate BETWEEN '2022-02-01' AND '2022-02-28';




--- Make a log backup of these changes:
BACKUP LOG [Partitioning Zero to Hero]
    TO DISK='H:\Backup\Log_backup.trn'
    WITH COMPRESSION, FORMAT;




-------------------------------------------------
--- Create backups of our filegroups:
-------------------------------------------------






DROP DATABASE IF EXISTS [Partitioning Zero to Hero_restored];

--- Restore the PRIMARY filegroup to a new database with NORECOVERY, so we can add logs:
--- 0:20
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='PRIMARY'
    FROM DISK = N'H:\Backup\Full_filegroups.bak'
    WITH PARTIAL,		-- because we're doing piecemeal restore
         NORECOVERY,	-- allow for additional log restores
         FILE = 1,
         MOVE N'Partitioning Zero to Hero' TO N'G:\Data\Restored_PRIMARY.mdf',
         MOVE N'Partitioning Zero to Hero_log' TO N'H:\Log\Restored_log.ldf',
         NOUNLOAD;



--- View the state of the files:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];



--- Restore 2021 and 2022 WITH NORECOVERY
--- 0:20
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='Filegroup_2021',
    FILEGROUP='Filegroup_2022'
    FROM DISK = N'H:\Backup\Full_filegroups.bak'
    WITH NORECOVERY,
         FILE = 1,
         MOVE N'File_2021.ndf' TO N'G:\Data\Restored_2021.ndf',
         MOVE N'File_2022.ndf' TO N'G:\Data\Restored_2022.ndf',
         NOUNLOAD;



--- View the state of the files:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];




--- Restore the log for filegroups PRIMARY, 2021 and 2022 WITH RECOVERY:
--- 0:00
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FROM DISK = N'H:\Backup\Log_backup.trn'
    WITH RECOVERY,
         FILE = 1;








--- View the state of the files:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];







--- Try reading from 2022 (which we've just restored)
--- We can see the Filler=0x123 rows that we created after the full backup.
SELECT *
FROM [Partitioning Zero to Hero_restored].dbo.AccountTransactions
WHERE TransactionDate BETWEEN '2022-02-01' AND '2022-02-28'
  AND Filler=0x123;









--- Bring the rest of the read-write files online
--- 
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FILEGROUP='Filegroup_2023',
    FILEGROUP='Filegroup_2024',
    FILEGROUP='Some_filegroup'
    FROM DISK = N'H:\Backup\Full_filegroups.bak'
    WITH NORECOVERY,
         FILE = 1,
         MOVE N'File_2023.ndf' TO N'G:\Data\Restored_2023.ndf',
         MOVE N'File_2024.ndf' TO N'G:\Data\Restored_2024.ndf',
         MOVE N'Some_file.ndf' TO N'G:\Data\Restored_something.ndf',
         NOUNLOAD;


--- Verify that we have everything:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];



--- Catch up with the log on the read-write files:
RESTORE DATABASE [Partitioning Zero to Hero_restored]
    FROM DISK = N'H:\Backup\Log_backup.trn'
    WITH RECOVERY,
         FILE = 1;


--- Inspect the results:
SELECT [name], [type_desc], [state_desc]
FROM sys.master_files
WHERE [database_id]=DB_ID('Partitioning Zero to Hero_restored')
ORDER BY [name];





--- ... and the read-only files from the old backup
--- WITH RECOVERY because they're read-only and have not changed:
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

USE tempdb;
