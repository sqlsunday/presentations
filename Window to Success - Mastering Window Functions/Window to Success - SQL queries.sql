
/*

    Presentation:       https://github.com/sqlsunday/presentations
    Weather database:   https://sqlsunday.com/download

*/




--------------------------------------------------------------------------------
---
--- FUNDAMENTALS
---
--------------------------------------------------------------------------------



--- How we used to do ROW_NUMBER() before window functions:

SELECT *, (SELECT COUNT(*)+1
           FROM DW.Locations
           WHERE Location_Name<loc.Location_Name
              OR Location_Name=loc.Location_Name AND Location_ID<loc.Location_ID)
FROM DW.Locations AS loc;



--- Simple ROW_NUMBER() example:

SELECT *, ROW_NUMBER() OVER (ORDER BY Location_Name)
FROM DW.Locations;



--- ROW_NUMBER() using the (SELECT NULL) trick to avoid sorting:

SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM DW.Locations;



--- LEAD() and LAG() examples:

SELECT *, LEAD(Location_Name, 1) OVER (ORDER BY Location_Name)
FROM DW.Locations;

SELECT *, LAG(Location_Name, 1) OVER (ORDER BY Location_Name)
FROM DW.Locations;



--- Introducing partitions:

SELECT *, ROW_NUMBER() OVER (
	PARTITION BY Metric_ID
	ORDER BY [Timestamp])
FROM DW.Measurements
WHERE Location_ID=97400
  AND [Timestamp]>='2025-01-01'
  AND [Timestamp]< '2025-01-02';
--ORDER BY Metric_ID, [Timestamp]





--------------------------------------------------------------------------------
---
--- AGGREGATES
---
--------------------------------------------------------------------------------



SELECT *,
       COUNT(*) OVER () AS _count,
       MIN([Value]) OVER () AS _min,
       MAX([Value]) OVER () AS _max,
       SUM([Value]) OVER () AS _sum
FROM DW.Measurements
WHERE Location_ID=97400
  AND [Timestamp]>='2025-01-01'
  AND [Timestamp]< '2025-01-02';
--ORDER BY Metric_ID, [Timestamp]




SELECT *,
       COUNT(*) OVER (PARTITION BY Metric_ID) AS _count,
       MIN([Value]) OVER (PARTITION BY Metric_ID) AS _min,
       MAX([Value]) OVER (PARTITION BY Metric_ID) AS _max,
       SUM([Value]) OVER (PARTITION BY Metric_ID) AS _sum
FROM DW.Measurements
WHERE Location_ID=97400
  AND [Timestamp]>='2025-01-01'
  AND [Timestamp]< '2025-01-02';
--ORDER BY Metric_ID, [Timestamp]




--------------------------------------------------------------------------------
---
--- WINDOW FRAMES
---
--------------------------------------------------------------------------------



--- Window frame (unbounded preceding)

SELECT *, SUM([Value]) OVER (
            PARTITION BY Metric_ID
            ORDER BY [Timestamp]
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS _running_total
FROM DW.Measurements
WHERE Location_ID=97400
  AND [Timestamp]>='2025-01-01'
  AND [Timestamp]< '2025-01-02';




--- Window frame (3 preceding to current)

SELECT *, SUM([Value]) OVER (
            PARTITION BY Metric_ID
            ORDER BY [Timestamp]
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ) AS _running_total
FROM DW.Measurements
WHERE Location_ID=97400
  AND [Timestamp]>='2025-01-01'
  AND [Timestamp]< '2025-01-02';




--- Window frame (3 preceding to 2 following)

SELECT *, SUM([Value]) OVER (
            PARTITION BY Metric_ID
            ORDER BY [Timestamp]
            ROWS BETWEEN 3 PRECEDING AND 2 FOLLOWING
        ) AS _running_total
FROM DW.Measurements
WHERE Location_ID=97400
  AND [Timestamp]>='2025-01-01'
  AND [Timestamp]< '2025-01-02';





--------------------------------------------------------------------------------
---
--- WINDOW AGGREGATES
---
--------------------------------------------------------------------------------



--- Daily average

SELECT m.Metric_ID,
       dt.[Date],
       AVG(m.[Value]) AS [Daily avg]
FROM DW.Measurements AS m
CROSS APPLY (
    VALUES (DATETRUNC(day, [Timestamp]))
    ) AS dt([Date])
WHERE m.Location_ID=97400
  AND m.[Timestamp]>='2025-01-01'
  AND m.[Timestamp]<'2025-02-01'
GROUP BY m.Metric_ID,
         dt.[Date];


--- 3-day moving average (of daily average)

SELECT m.Metric_ID,
       dt.[Date],

       --- 3-day moving average of the daily average:
       AVG(AVG(m.[Value])) OVER (
            PARTITION BY m.Metric_ID
            ORDER BY dt.[Date]
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS [3 day moving average average],


       --- The 3-day running total...
       SUM(SUM(m.[Value])) OVER (
          PARTITION BY m.Metric_ID
          ORDER BY dt.[Date]
          ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       )
       --- ... divided by...
       /
       --- ... the 3-day running count.
       SUM(COUNT(m.[Value])) OVER (
           PARTITION BY m.Metric_ID
           ORDER BY dt.[Date]
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS [Weighted 3 day moving average]

FROM DW.Measurements AS m
CROSS APPLY (
    VALUES (DATETRUNC(day, m.[Timestamp]))
    ) AS dt([Date])
WHERE m.Metric_ID=1
  AND m.Location_ID=97400
  AND m.[Timestamp]>='2025-01-01'
  AND m.[Timestamp]<'2025-02-01'
GROUP BY m.Metric_ID,
         dt.[Date]
ORDER BY m.Metric_ID, dt.[Date];







--------------------------------------------------------------------------------
---
--- USEFUL PATTERNS
---
--------------------------------------------------------------------------------



--- First/last rows
SELECT *,
       LAG(0, 1, 1) OVER (ORDER BY [Timestamp]) AS _first,
       LEAD(0, 1, 1) OVER (ORDER BY [Timestamp]) AS _last
FROM DW.Measurements
WHERE Location_ID=97200
  AND Metric_ID=1
  AND [Timestamp]>='2025-01-01';





--- Deleting duplicate rows
DELETE x
FROM (
    SELECT *, ROW_NUMBER() OVER (
               PARTITION BY Location_ID, Metric_ID, [Timestamp]
               ORDER BY (SELECT NULL)
            ) AS _duplicate
    FROM DW.Measurements
    WHERE Location_ID=97200
      AND Metric_ID=1
      AND [Timestamp]>='2025-01-01'
    ) AS x
WHERE _duplicate>1;




--- Fixing overlapping ranges:
UPDATE x
    SET x.[From]=x._prev_to
    FROM (
        SELECT *, LAG([To], 1) OVER (
                PARTITION BY Location_ID
                ORDER BY [From]
            ) AS _prev_to
        FROM DW.Location_Timeframes
        ) AS x
    WHERE _prev_to>[From];




--- Finding gaps
SELECT *, (CASE
           WHEN LAG([To], 1) OVER (
               PARTITION BY Location_ID
               ORDER BY [From]
           )<[From] THEN 1 ELSE 0 END) AS _has_gap
FROM DW.Location_Timeframes;





--- Finding islands
SELECT Location_ID, _group_no, MIN([From]), MAX([To])
FROM (
    SELECT *, SUM(_has_gap) OVER (
            PARTITION BY Location_ID
            ORDER BY [From]
            ROWS UNBOUNDED PRECEDING
        ) AS _group_no
    FROM (
        SELECT *, (CASE
            WHEN LAG([To], 1) OVER (
                PARTITION BY Location_ID
                ORDER BY [From]
            )<[From] THEN 1 ELSE 0 END) AS _has_gap
        FROM DW.Location_Timeframes
    ) AS x
) AS y
GROUP BY Location_ID, _group_no;





--- A windowed COUNT DISTINCT
SELECT *,
       --- The highest dense rank is the distinct count.
       MAX(_dense_rank) OVER () AS _distinct_count
FROM (
    SELECT *,
           --- Dense rank: 1, 2, 3, ...
           DENSE_RANK() OVER (ORDER BY Location_ID) AS _dense_rank
    FROM DW.Location_Timeframes
) AS x;





--- Named windows
SELECT *,
       --- Rank: 1, 45, 111, ...
       RANK() OVER by_location AS _rank,

       --- Dense rank: 1, 2, 3, ...
       DENSE_RANK() OVER by_location AS _dense_rank

FROM DW.Location_Timeframes
WINDOW by_location AS (ORDER BY Location_ID)




