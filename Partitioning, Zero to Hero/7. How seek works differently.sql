USE [Partitioning Zero to Hero];
SET STATISTICS TIME, IO ON;





-------------------------------------------------
--- On an unpartitioned table
-------------------------------------------------


SELECT AccountID, SUM(Amount) AS Net_balance_change
FROM dbo.AccountTransactions_plain
WHERE TransactionDate BETWEEN '2021-07-01' AND '2022-06-30'
  AND AccountID BETWEEN 810000000 AND 820000000
GROUP BY AccountID
OPTION (MAXDOP 1);







-------------------------------------------------
--- On the partitioned table
-------------------------------------------------

SELECT AccountID, SUM(Amount) AS Net_balance_change
FROM dbo.AccountTransactions
WHERE TransactionDate BETWEEN '2021-07-01' AND '2022-06-30'
  AND AccountID BETWEEN 810000000 AND 820000000
GROUP BY AccountID
OPTION (MAXDOP 1);



