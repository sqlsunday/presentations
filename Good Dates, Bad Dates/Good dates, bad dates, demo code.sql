-- Don't accidentally run the entire script top-to-bottom.
THROW;



---
--- https://public.sqlsunday.com/Chicago.bak
---
--- 8 GB download, restores to about 25 GB.
--- Requires SQL Server 2019+
---





ALTER DATABASE ChicagoParkingTickets SET COMPATIBILITY_LEVEL=170;

USE ChicagoParkingTickets;





--- Reset the demo database
DROP STATISTICS Tickets.Parking_Violations.Quarter_stats;
ALTER TABLE Tickets.Parking_Violations DROP COLUMN IF EXISTS Issued_quarter;






--- Turn on statistics
SET STATISTICS TIME, IO ON;
















-------------------------------------------------------------------
---
--- .. Some basic date/time functions
---
-------------------------------------------------------------------

SET LANGUAGE us_english;

--- Getting the date part, name of the date part:

DECLARE @now datetimeoffset(7)=SYSDATETIMEOFFSET();

SELECT DATEPART(year,     @now) AS [year],
       DATEPART(quarter,  @now) AS [quarter],
       DATEPART(month,    @now) AS [month],
	   DATEPART(day,      @now) AS [day],
	   DATEPART(weekday,  @now) AS [weekday],

	   DATENAME(month,    @now) AS [name of month],
	   DATENAME(weekday,  @now) AS [name of weekday],

	   DATEPART(hour,     @now) AS [hour],
	   DATEPART(minute,   @now) AS [minute],
	   DATEPART(second,   @now) AS [second],

	   DATEPART(tzoffset, @now) AS [timezone],
	   DATENAME(tzoffset, @now) AS [name of timezone];



--- Adding/subtracting

SELECT DATEADD(month, 1, '2026-09-12')

SELECT DATEADD(day, -30, '2026-09-12')






--- Date difference

SELECT DATEDIFF(day, '2026-09-12', '2026-10-12')

SELECT DATEDIFF(month, '2026-09-12', '2026-10-12')

SELECT DATEDIFF(quarter, '2026-09-12', '2026-10-12')




--- Compute today's UNIX epoch number

SELECT DATEDIFF(second, '1970-01-01', SYSDATETIME())

SELECT DATEDIFF(millisecond, '1970-01-01', SYSDATETIME())

SELECT DATEDIFF_BIG(millisecond, '1970-01-01', SYSDATETIME())






DECLARE @date datetime2(0)=SYSDATETIME();

--- Find the first of each date part using DATETRUNC()

SELECT DATETRUNC(year,         @date) AS [year],
       DATETRUNC(quarter,      @date) AS [quarter],
       DATETRUNC(month,        @date) AS [month],
       DATETRUNC(week,         @date) AS [week],
       DATETRUNC(day,          @date) AS [day],
       DATETRUNC(hour,         @date) AS [hour];

--- Equivalent, using DATE_BUCKET()

SELECT DATE_BUCKET(year,    1, @date) AS [year],
       DATE_BUCKET(quarter, 1, @date) AS [quarter],
       DATE_BUCKET(month,   1, @date) AS [month],
       DATE_BUCKET(week,    1, @date) AS [week],
       DATE_BUCKET(day,     1, @date) AS [day],
       DATE_BUCKET(hour,    1, @date) AS [hour];

--- Larger buckets

SELECT x.[date] AS [Date],
       DATE_BUCKET(day,     1, x.[date]) AS [1 day],
       DATE_BUCKET(day,     2, x.[date]) AS [2 days],
       DATE_BUCKET(day,     3, x.[date]) AS [3 days],
       DATE_BUCKET(day,     7, x.[date]) AS [7 days],
       DATE_BUCKET(day,    30, x.[date]) AS [30 days]
FROM GENERATE_SERIES(-30, 30, 1) AS gs
CROSS APPLY (VALUES (DATEADD(day, gs.[value], CAST('2026-01-01' AS date)))) AS x([date]);

--- ... and manually defining the bucket start date ("origin")

SELECT x.[date] AS [Date],
       DATE_BUCKET(day,     1, x.[date], CAST('2026-01-01' AS date)) AS [1 day],
       DATE_BUCKET(day,     2, x.[date], CAST('2026-01-01' AS date)) AS [2 days],
       DATE_BUCKET(day,     3, x.[date], CAST('2026-01-01' AS date)) AS [3 days],
       DATE_BUCKET(day,     7, x.[date], CAST('2026-01-01' AS date)) AS [7 days],
       DATE_BUCKET(day,    30, x.[date], CAST('2026-01-01' AS date)) AS [30 days]
FROM GENERATE_SERIES(-30, 30, 1) AS gs
CROSS APPLY (VALUES (DATEADD(day, gs.[value], CAST('2026-01-01' AS date)))) AS x([date]);
















-------------------------------------------------------------------
---
--- 2. Conversions
---
-------------------------------------------------------------------

--- CONVERT and CAST do the same thing, but CONVERT allows you to
--- specify formatting style.









--- Implicit conversions from text to date relies on your language
--- settings and a little bit of luck:

SET LANGUAGE Swedish;
SELECT @@LANGUAGE,
       CAST('2010/11/12' AS date),
       CAST('10/11/12' AS date),
       CAST('10/11/2012' AS date);

SET LANGUAGE Norwegian;
SELECT @@LANGUAGE,
       CAST('2010/11/12' AS date),
       CAST('10/11/12' AS date),
       CAST('10/11/2012' AS date);

SET LANGUAGE British;
SELECT @@LANGUAGE,
       CAST('2010/11/12' AS date),
       CAST('10/11/12' AS date),
       CAST('10/11/2012' AS date);

SET LANGUAGE us_english;
SELECT @@LANGUAGE,
       CAST('2010/11/12' AS date),
       CAST('10/11/12' AS date),
       CAST('10/11/2012' AS date);

SET LANGUAGE German;
SELECT @@LANGUAGE,
       CAST('2010/11/12' AS date),
       CAST('10/11/12' AS date),
       CAST('10/11/2012' AS date);

SET LANGUAGE us_english;



--- Using ODBC escape sequences returns a native datetime.
--- This works regardless of language or DATEFORMAT.

SELECT {d '2010-11-12'},
      {ts '2010-11-12 13:14:15'},
      {ts '2010-11-12 13:14:15.678'},
       {t '13:14:15'};


EXECUTE sys.sp_describe_first_result_set N'
	SELECT {d ''2010-11-12''},
	      {ts ''2010-11-12 13:14:15''},
	      {ts ''2010-11-12 13:14:15.678''},
	       {t ''13:14:15''};
';






--- THE SOLUTION: You can get a predictable conversion by using CONVERT() with a style:

SELECT CONVERT(date, '10/11/12'    ) AS [Default conversion],
	   CONVERT(date, '10/11/12',  1) AS [US],
	   CONVERT(date, '10/11/12',  3) AS [British/French],
	   CONVERT(date, '10/11/12', 11) AS [Japan];

--- ... and back:

DECLARE @ts datetime2(3)={ts '2010-11-12 13:14:15.678'};

SELECT CONVERT(varchar(100), @ts     ) AS [Default conversion],
	   CONVERT(varchar(100), @ts,   1) AS [US],
	   CONVERT(varchar(100), @ts,   3) AS [British/French],
	   CONVERT(varchar(100), @ts,  11) AS [Japan],
	   CONVERT(varchar(100), @ts, 112) AS [compact ISO 8601],
	   CONVERT(varchar(100), @ts, 120) AS [ODBC canonical (ISO 8601)],
	   CONVERT(varchar(100), @ts, 121) AS [... with milliseconds],
	   CONVERT(varchar(100), @ts, 126) AS [... with T];


--- Use the length of the varchar/nvarchar to truncate the output as needed:

SELECT CONVERT(varchar(10), @ts, 121) AS [to varchar(10)],
	   CONVERT(varchar(16), @ts, 121) AS [to varchar(16)],
	   CONVERT(varchar(19), @ts, 121) AS [to varchar(19)],
	   CONVERT(varchar(23), @ts, 121) AS [to varchar(23)];




--- All the different conversion styles
SELECT [value] AS [Style without century],
       TRY_CONVERT(nvarchar(100), SYSDATETIME(), gs.[value]) AS [Without century],
       100+[value] AS [Style with century],
       TRY_CONVERT(nvarchar(100), SYSDATETIME(), 100+gs.[value]) AS [With century]
FROM GENERATE_SERIES(0, 31, 1) AS gs
WHERE ISNULL(TRY_CONVERT(nvarchar(100), SYSDATETIME(), gs.[value]), TRY_CONVERT(nvarchar(100), SYSDATETIME(), gs.[value])) IS NOT NULL
ORDER BY gs.[value];





--- CONVERT() and CAST() will fail if the input cannot
--- be converted. TRY_CONVERT() and TRY_CAST() will
--- just return a NULL value instead, which is helpful
--- if you have data quality issues.

SELECT     CONVERT(date, '2026-13-01', 121);

SELECT TRY_CONVERT(date, '2026-13-01', 121);















-------------------------------------------------------------------
---
--- 3. Different functions, different types, same results:
---
-------------------------------------------------------------------

--- Current date and time
SELECT CURRENT_DATE        AS [CURRENT_DATE],		 -- date
       CURRENT_TIMESTAMP   AS [CURRENT_TIMESTAMP],	 -- datetime
       GETDATE()		   AS [GETDATE()],			 -- datetime
       GETUTCDATE()	       AS [GETUTCDATE()],		 -- datetime
       SYSDATETIME()	   AS [SYSDATETIME()],		 -- datetime2
       SYSUTCDATETIME()    AS [SYSUTCDATETIME()],	 -- datetime2
       SYSDATETIMEOFFSET() AS [SYSDATETIMEOFFSET()]; -- datetimeoffset



--- Constructing a date/time from its parts
SELECT          DATEFROMPARTS(2010, 11, 12)                              AS [date from parts],
       SMALLDATETIMEFROMPARTS(2010, 11, 12, 20, 21)                      AS [smalldatetime from parts],
            DATETIMEFROMPARTS(2010, 11, 12, 20, 21, 22, 123)             AS [datetime from parts],
           DATETIME2FROMPARTS(2010, 11, 12, 20, 21, 22, 123,          3) AS [datetime2(3) from parts],
           DATETIME2FROMPARTS(2010, 11, 12, 20, 21, 22, 123,          4) AS [datetime2(4) from parts],
           DATETIME2FROMPARTS(2010, 11, 12, 20, 21, 22, 123,          5) AS [datetime2(5) from parts],
                              TIMEFROMPARTS(20, 21, 22, 123,          6) AS [time(6) from parts],
      DATETIMEOFFSETFROMPARTS(2010, 11, 12, 20, 21, 22, 123, -4, -30, 7) AS [datetimeoffset(7) from parts]
















-------------------------------------------------------------------
---
--- 4. BAD TYPE. BAD.
---
-------------------------------------------------------------------



--- Believe it or not, even SQL Server Agent uses these
--- kinds of "date" types.
SELECT run_date, run_time, run_duration
FROM msdb.dbo.sysjobhistory;






--- Here's the simplest way I can think of to convert an
--- int date/time into datetime2(0):
SELECT run_date, run_time, run_duration,
       DATETIME2FROMPARTS(
           run_date/10000,          -- Year
           (run_date/100)%100,      -- Month
           run_date%100,            -- Day
           run_time/10000,          -- Hour
           (run_time/100)%100,      -- Minute
           run_time%100,            -- Second
           0, 0                     -- (fractions, precision)
       ),
       TIMEFROMPARTS(
           run_duration/10000,      -- Hour
           (run_duration/100)%100,  -- Minute
           run_duration%100,        -- Second
           0, 0                     -- (fractions, precision)
       )
FROM msdb.dbo.sysjobhistory;

--- % is the "modulo" operator:
--- 123456%100 = 56
---
--- int division always rounds the result down,
--- so 123456/100 = 1234.





/*
--- Alternate proposed solution:

--- 1. Convert the int to a char/varchar and left-pad the time with "000000"
SELECT CAST(h.run_date AS char(8)) AS run_date,
       RIGHT('000000'+CAST(h.run_time AS varchar(6)), 6) AS run_time,
	   RIGHT('000000'+CAST(h.run_duration AS varchar(6)), 6) AS run_duration
FROM msdb.dbo.sysjobhistory AS h;


--- 2. Use STUFF() to insert ":" after characters 4 and 2
SELECT CAST(h.run_date AS char(8)) AS run_date,
       STUFF(STUFF(RIGHT('000000'+CAST(h.run_time AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':') AS run_time,
	   STUFF(STUFF(RIGHT('000000'+CAST(h.run_duration AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':') AS run_duration
FROM msdb.dbo.sysjobhistory AS h;


--- 3. Convert the char/varchar columns to date and time(0) respectively.
SELECT CONVERT(date, CAST(h.run_date AS char(8)), 112) AS run_date,
       CONVERT(time(0), STUFF(STUFF(RIGHT('000000'+CAST(h.run_time AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':'), 8) AS run_time,
	   CONVERT(time(0), STUFF(STUFF(RIGHT('000000'+CAST(h.run_duration AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':'), 8) AS run_duration
FROM msdb.dbo.sysjobhistory AS h;


--- 4. Move the whole computation to a CROSS APPLY and change date -> datetime2(0)
SELECT x.*
FROM msdb.dbo.sysjobhistory AS h
CROSS APPLY (
	SELECT CONVERT(datetime2(0), CAST(h.run_date AS char(8)), 112) AS run_date,
		   CONVERT(time(0), STUFF(STUFF(RIGHT('000000'+CAST(h.run_time AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':'), 8) AS run_time,
		   CONVERT(time(0), STUFF(STUFF(RIGHT('000000'+CAST(h.run_duration AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':'), 8) AS run_duration
	) AS x;


--- 5. Turn the time(0) into (seconds after midnight), then add those to the date column.
SELECT x.*,
       DATEADD(second, x.run_time, x.run_date) AS run_date_time_start,
       DATEADD(second, x.run_time+x.run_duration, x.run_date) AS run_date_time_end
FROM msdb.dbo.sysjobhistory AS h
CROSS APPLY (
	SELECT CONVERT(datetime2(0), CAST(h.run_date AS char(8)), 112) AS run_date,
		   DATEDIFF(second, '00:00:00', CONVERT(time(0), STUFF(STUFF(RIGHT('000000'+CAST(h.run_time AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':'), 8)) AS run_time,
		   DATEDIFF(second, '00:00:00', CONVERT(time(0), STUFF(STUFF(RIGHT('000000'+CAST(h.run_duration AS varchar(6)), 6), 5, 0, ':'), 3, 0, ':'), 8)) AS run_duration
	) AS x;

*/













-------------------------------------------------------------
---
--- 5. Indexing and sargability
---
-------------------------------------------------------------



--- What's the total in parking fines issued in December 2011?




--- This old favourite will not work gracefully on
--- SQL Server, because it isn't sargable.
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE CONVERT(varchar(10), Issued_date, 121) BETWEEN '2011-12-01' AND '2011-12-31';










--- 1.59 million logical reads, 8.9 s. cpu time
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE YEAR(Issued_date)=2011
  AND MONTH(Issued_date)=12;


--- 1.59 million logical reads, 18.0 s. cpu time
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE DATE_BUCKET(month, 1, Issued_date)='2011-12-01';


--- 1.59 million logical reads, 13.5 s. cpu time
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE DATETRUNC(month, Issued_date)='2011-12-01';



--- BONUS CONTENT: Check out the plans for the
--- above three queries; YEAR() and MONTH() do
--- not retain the sort order of the index, so
--- they generate a Hash Match, whereas DATE_BUCKET()
--- and DATETRUNC() do, and thus result in a
--- Stream Aggregate.
---
--- However, in the end, they still perform an
--- Index Scan, so they don't solve our
--- sargability problem here.



--- 5 000 logical reads, 0.03 s. cpu time
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE Issued_date BETWEEN '2011-12-01' AND '2011-12-31';

--- ... but this gives an incorrect result!


--- BONUS CONTENT: The index statistics
DBCC SHOW_STATISTICS('Tickets.Parking_Violations', 'PK_Parking_Violations')




--- 796 000 reads, 10.2 s cpu time
--- Back to non-sargable, but the results are at least correct.
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE DATETRUNC(day, Issued_date) BETWEEN '2011-12-01' AND '2011-12-31';



--- 2 600 logical reads, 0.015 s. cpu time
--- This works, despite the CAST(), because of a SQL optimizer
--- shortcut that "understands" what we're trying to do.
--- The cardinality estimate also works here.
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE CAST(Issued_date AS date) BETWEEN '2011-12-01' AND '2011-12-31';



--- This effectively optimizes as:
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE Issued_date>='2011-12-01'
  AND Issued_date< '2012-01-01';



--- You can even micro-optimize, and eliminate the
--- Merge Interval pattern by using the correct
--- datatype in the predicate:
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE Issued_date>=CAST('2011-12-01' AS datetime2(0))
  AND Issued_date< CAST('2012-01-01' AS datetime2(0));
















-------------------------------------------------------------
---
--- 6. Time zones
---
-------------------------------------------------------------


SELECT SYSDATETIME(),
       SYSDATETIMEOFFSET(),
       CURRENT_TIMEZONE(),
       CURRENT_TIMEZONE_ID();

--- Change the offset (+/- hours)

SELECT SYSDATETIMEOFFSET() AS [Local],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '-07:00') AS [Pacific],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '-04:00') AS [Eastern],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '+00:00') AS [UTC],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '+01:00') AS [CET],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '+05:30') AS [Delhi],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '+08:00') AS [Singapore],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '+10:00') AS [Sydney],
       SWITCHOFFSET(SYSDATETIMEOFFSET(), '+12:00') AS [Auckland]

--- Change the offset to a named timezone

SELECT SYSDATETIMEOFFSET() AT TIME ZONE 'Pacific Standard Time' AS [Pacific],
       SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time' AS [Eastern],
       SYSDATETIMEOFFSET() AT TIME ZONE 'UTC' AS [UTC],
       SYSDATETIMEOFFSET() AT TIME ZONE 'Central European Standard Time' AS [CET],
       SYSDATETIMEOFFSET() AT TIME ZONE 'India Standard Time' AS [Delhi],
       SYSDATETIMEOFFSET() AT TIME ZONE 'Singapore Standard Time' AS [Singapore],
       SYSDATETIMEOFFSET() AT TIME ZONE 'E. Australia Standard Time' AS [Sydney],
       SYSDATETIMEOFFSET() AT TIME ZONE 'New Zealand Standard Time' AS [Auckland];



--- There's even a handy DMV, sys.time_zone_info:

SELECT [name], SYSDATETIMEOFFSET() AT TIME ZONE [name]
FROM sys.time_zone_info
ORDER BY CAST(REPLACE(current_utc_offset, ':', '.') AS numeric(4, 2)), [name];
















-------------------------------------------------------------
---
--- 7. Week math
---
-------------------------------------------------------------




--- DATEFIRST and ISO weeks can trip you up:

SELECT @@DATEFIRST AS [current DATEFIRST];

SET DATEFIRST 1; -- Week starts on Mondays:  ISO 8601 - Europe, China, Oceania
SET DATEFIRST 6; -- week starts on Saturday. Middle East, North Africa
SET DATEFIRST 7; -- Week starts on Sundays:  US, Canada, Brazil, Japan, Israel




--- Weeks start on DATEFIRST day:

SELECT x.Date_column,
	   DATENAME(weekday, x.Date_column) AS [Weekday],

       DATEPART(week, x.Date_column) AS [Week],
	   DATETRUNC(week, x.Date_column) AS [Week datetrunc],
	   DATE_BUCKET(week, 1, x.Date_column) AS [Week datebucket *]
FROM GENERATE_SERIES(0, 365, 1) AS gs
CROSS APPLY (VALUES (DATEADD(day, gs.[value], CAST('2027-01-01' AS date)))) AS x(Date_column)
ORDER BY x.Date_column

--- *) Note how DATE_BUCKET(week) "starts" with 1900-01-01, which is
--- a Monday and thus always aligns to ISO weeks.





--- ISO weeks always start on a Monday.
--- Note what happens to the first couple of days of each year:
SELECT x.Date_column,
	   DATENAME(weekday, x.Date_column) AS [Weekday],

       DATEPART(iso_week, x.Date_column) AS [ISO week],
	   DATETRUNC(iso_week, x.Date_column) AS [ISO week datetrunc]

FROM GENERATE_SERIES(0, 365, 1) AS gs
CROSS APPLY (VALUES (DATEADD(day, gs.[value], CAST('2027-01-01' AS date)))) AS x(Date_column)
ORDER BY x.Date_column






--- Be careful with the "week year":
SELECT x.Date_column,
	   DATENAME(weekday, x.Date_column) AS [Weekday],

       CAST(YEAR(x.Date_column) AS varchar(4))+
       '-'+
	   CAST(DATEPART(iso_week, x.Date_column) AS varchar(2)) AS [ISO week]

FROM GENERATE_SERIES(0, 380, 1) AS gs
CROSS APPLY (VALUES (DATEADD(day, gs.[value], CAST('2026-12-26' AS date)))) AS x(Date_column)
ORDER BY x.Date_column



--- Use the year of the ISO week bucket, not from the year:
SELECT x.Date_column,
	   DATENAME(weekday, x.Date_column) AS [Weekday],

	   CAST(YEAR(DATETRUNC(iso_week, x.Date_column)) AS varchar(4))+
       '-'+
	   CAST(DATEPART(iso_week, x.Date_column) AS varchar(2)) AS [ISO week]

FROM GENERATE_SERIES(0, 380, 1) AS gs
CROSS APPLY (VALUES (DATEADD(day, gs.[value], CAST('2026-12-24' AS date)))) AS x(Date_column)
ORDER BY x.Date_column














--- This is non-sargable, like previous examples, so it will perform terribly:
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE YEAR(Issued_date)=2011
  AND DATEPART(iso_week, Issued_date)=50;

--- Same:
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE DATE_BUCKET(week, 1, Issued_date)='2011-12-12';





--- Let's create a list of 366 days, starting at 2011-01-01:
SELECT DATEADD(day, gs.[value], CAST('2011-01-01' AS date)) AS [date]
FROM GENERATE_SERIES(0, 365, 1) AS gs




--- ... filter that list so we only get week 50 of 2011
SELECT *
FROM (
	SELECT DATEADD(day, gs.[value], CAST('2011-01-01' AS date)) AS [date]
	FROM GENERATE_SERIES(0, 365, 1) AS gs
	) AS rng
WHERE YEAR(DATETRUNC(iso_week, [date]))=2011	-- the ISO week year, not just the year!
  AND DATEPART(iso_week, [date])=50;




--- ... and get the first and last date:
SELECT MIN([date]) AS min_date,
	   MAX([date]) AS max_date
FROM (
	SELECT DATEADD(day, gs.[value], CAST('2011-01-01' AS date)) AS [date]
	FROM GENERATE_SERIES(0, 365, 1) AS gs
	) AS rng
WHERE YEAR(DATETRUNC(iso_week, [date]))=2011
  AND DATEPART(iso_week, [date])=50;




--- Putting it all together:
DECLARE @from date, @to date;

SELECT @from=MIN([date]),
         @to=MAX([date])
FROM (
	SELECT DATEADD(day, gs.[value], CAST('2011-01-01' AS date)) AS [date]
	FROM GENERATE_SERIES(0, 365, 1) AS gs
	) AS rng
WHERE YEAR(DATETRUNC(iso_week, [date]))=2011
  AND DATEPART(iso_week, [date])=50;

SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations AS p
WHERE p.Issued_date>=@from
  AND p.Issued_date<DATEADD(day, 1, @to);






---
--- But what if we can't rewrite the DATEPART() filter in the query?
---



/*
DROP INDEX IF EXISTS Issued_year_week ON Tickets.Parking_Violations;

ALTER TABLE Tickets.Parking_Violations DROP COLUMN IF EXISTS Issued_iso_year;
ALTER TABLE Tickets.Parking_Violations DROP COLUMN IF EXISTS Issued_iso_week;
*/


--- Add pre-computed (persisted) columns
--- 3:03
ALTER TABLE Tickets.Parking_Violations
	ADD Issued_iso_year AS YEAR(DATETRUNC(iso_week, Issued_date)) PERSISTED,
		Issued_iso_week AS DATEPART(iso_week, Issued_date) PERSISTED;

--- ... and index them.
--- 0:54
CREATE INDEX Issued_year_week
	ON Tickets.Parking_Violations (Issued_iso_year, Issued_iso_week)
        INCLUDE (Fine_amount)
	WITH (DATA_COMPRESSION=PAGE);



--- 68 reads, 0 ms cpu time.
SELECT SUM(Fine_amount)
FROM Tickets.Parking_Violations
WHERE YEAR(DATETRUNC(iso_week, Issued_date))=2011
  AND DATEPART(iso_week, Issued_date)=50;


















-------------------------------------------------------------------
---
--- 8. Time for some war stories, and good advice.
---
-------------------------------------------------------------------




DROP TABLE IF EXISTS #Random_dates;

SELECT CAST(x.Issued_date AS date) AS Date_column,
       CAST(x.Issued_date AS time(0)) AS Time_column,
	   CAST(x.Issued_date AS datetime) AS Datetime_column,
	   x.Issued_date AS Datetime2_column
INTO #Random_dates
FROM GENERATE_SERIES(1, 12, 1) AS gs
CROSS APPLY (
	SELECT TOP (100) pv.Issued_date
	FROM Tickets.Parking_Violations AS pv
	WHERE pv.Issued_date>=DATEFROMPARTS(2012, gs.[value], 10)
	  AND pv.Issued_date< DATEFROMPARTS(2012, gs.[value], 20)
	ORDER BY NEWID()
	) AS x;

CREATE CLUSTERED INDEX IX ON #Random_dates (Datetime2_column);


/*
DROP INDEX IF EXISTS UQ_Issue_date_Ticket ON Tickets.Parking_Violations;

--- 34 s.
CREATE UNIQUE INDEX UQ_Issue_date_Ticket
	ON Tickets.Parking_Violations (Issued_date, Ticket_number)
        INCLUDE (Fine_amount)
	WITH (DATA_COMPRESSION=PAGE);
*/







--- Removing the time component from a datetime:
--- ABSOLUTELY DON'T:
SELECT Datetime_column,
       CAST(FLOOR(CAST(Datetime_column AS float)) AS datetime)
FROM #Random_dates;

--- DON'T:
SELECT Datetime_column,
       DATEADD(day, DATEDIFF(day, 0, Datetime_column), 0)
FROM #Random_dates;

--- DO (pre-2022):
SELECT Datetime_column, CAST(Datetime_column AS date)
FROM #Random_dates;

--- DO:
SELECT Datetime_column, DATETRUNC(day, Datetime_column)
FROM #Random_dates;









--- First day of the month:
---------------------------------------

--- DON'T:
SELECT Date_column, CONVERT(date, LEFT(CONVERT(char(8), Date_column, 112), 6)+'01', 112)
FROM #Random_dates;


--- DON'T:
SELECT Date_column, DATEADD(month, DATEDIFF(month, 0, Date_column), 0)
FROM #Random_dates;


--- MAYBE (pre-2022):
SELECT Date_column, DATEFROMPARTS(YEAR(Date_column), MONTH(Date_column), 1)
FROM #Random_dates;


--- EVENT BETTER (2022+):
SELECT Date_column, DATETRUNC(month, Date_column)
FROM #Random_dates;









--- Last day of the month:
---------------------------------------

--- DON'T:
SELECT Date_column,
       DATEADD(day, -1,
           DATEADD(month, 1,
               CONVERT(date,
                       LEFT(CONVERT(char(8), Date_column, 112), 6)+'01',
                       112)))
FROM #Random_dates;


--- DO:
SELECT Date_column,
       EOMONTH(Date_column)
FROM #Random_dates;









--- Last day of the quarter:
---------------------------------------


--- DON'T:
SELECT Date_column,
       EOMONTH(DATEADD(month,
                       3-(MONTH(Date_column)-(DATEPART(quarter, Date_column)-1)*3),
					   Date_column))
FROM #Random_dates;


--- DO (2022+):
SELECT Date_column, EOMONTH(DATETRUNC(quarter, Date_column), 2)
FROM #Random_dates;







--- How many days in the month?
---------------------------------------

--- NOT CLEVER:
SELECT Date_column, DATEDIFF(day, Date_column, DATEADD(month, 1, Date_column))
FROM #Random_dates;



--- CLEVER:
SELECT Date_column, DAY(EOMONTH(Date_column))
FROM #Random_dates;





--- First day of current ISO week (Monday)
------------------------------------------

--- PLEASE, NO:
SELECT Datetime2_column,
       DATEADD(day,
	           0-(DATEPART(weekday, Datetime2_column)
			      +@@DATEFIRST
				  -2)%7,
			   CAST(Datetime2_column AS date))
FROM #Random_dates;


--- MUCH SIMPLER:
SELECT Datetime2_column,
	   DATETRUNC(iso_week, Datetime2_column) AS Monday_of_week
FROM #Random_dates;






--- Birthday/age calculation
---------------------------------------

--- IT'S A TRAP!
SELECT Datetime2_column,
       DATEDIFF(year, Datetime2_column, SYSDATETIME()) AS [Age?],
	   YEAR(SYSDATETIME())-YEAR(Datetime2_column)
FROM #Random_dates;


--- HOW TO FIND THE CORRECT AGE:

--- 1. DATE_BUCKET sorts the datetime column into buckets
SELECT Datetime2_column,
       DATE_BUCKET(year, 1, Datetime2_column)
FROM #Random_dates

--- 2. Set the start date/time of the bucket to SYSDATETIME()
SELECT Datetime2_column,
       DATE_BUCKET(year, 1, Datetime2_column, SYSDATETIME())
FROM #Random_dates

--- 3. Count the years between the bucket and SYSDATETIME()
SELECT Datetime2_column,
       DATE_BUCKET(year, 1, Datetime2_column, SYSDATETIME()),

       -- The correct age calculation:
       DATEDIFF(year,
                DATE_BUCKET(year, 1, Datetime2_column, SYSDATETIME()),
				SYSDATETIME()) AS Age,

       -- ... or, expressed differently:
       YEAR(SYSDATETIME())-
       YEAR(DATE_BUCKET(year, 1, Datetime2_column, SYSDATETIME())) AS Age
FROM #Random_dates






--- 15-minute buckets
---------------------------------------

--- DON'T:
SELECT Datetime2_column,
       DATEADD(minute, (DATEDIFF(minute, 0, Datetime2_column) / 15)*15, 0)
FROM #Random_dates;


-- DO (2022+):
SELECT Datetime2_column, DATE_BUCKET(minute, 15, Datetime2_column)
FROM #Random_dates;






--- Average of dates?
---------------------------------------

--- NOPE:
SELECT AVG(Issued_date)
FROM Tickets.Parking_Violations



--- MAYBE:
SELECT DATEADD(second,
               AVG(DATEDIFF_BIG(second, '2000-01-01', Issued_date)),
               '2000-01-01')
FROM Tickets.Parking_Violations




