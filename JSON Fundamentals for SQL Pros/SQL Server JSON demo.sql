USE JSON_demo;
GO



EXECUTE sys.sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE;
GO



-- GRANT EXECUTE ANY EXTERNAL ENDPOINT TO [database_principal_name];




-------------------------------------------------------------------------------
--- Fetch security wait times for Arlanda Airport
-------------------------------------------------------------------------------

--- https://apideveloper.swedavia.se/signin










-------------------------------------------------------------------------------
--- Set up a database-scoped credential
-------------------------------------------------------------------------------

-- CREATE MASTER KEY ENCRYPTION BY PASSWORD='super-secret-master-key-password-here';

CREATE DATABASE SCOPED CREDENTIAL [https://api.swedavia.se/waittimepublic/v2]
WITH IDENTITY = 'HTTPEndpointHeaders',
     SECRET = '{"Ocp-Apim-Subscription-Key": "your-super-secret-api-key-goes-here"}';
GO






-------------------------------------------------------------------------------
--- Get security wait times
-------------------------------------------------------------------------------

DECLARE @response nvarchar(max);

EXECUTE sys.sp_invoke_external_rest_endpoint
    @url=N'https://api.swedavia.se/waittimepublic/v2/airports/ARN',
    @credential=[https://api.swedavia.se/waittimepublic/v2],
    @method='GET',
    @response=@response OUTPUT;

--- This is the raw JSON
SELECT @response;

--- JSON_QUERY() parses the JSON blob and returns a specific selection of it,
--- in this case the "waitTimes" array in the "result" attribute:
SELECT JSON_QUERY(@response, '$.result.waitTimes');

--- OPENJSON returns one JSON blob for each member of the waitTimes array:
SELECT * FROM OPENJSON(@response, '$.result.waitTimes');

--- OPENJSON ... WITH outputs a recordset with one row per array member,
--- and specific attributes in columns
SELECT *
FROM OPENJSON(@response, '$.result.waitTimes')
    WITH (
        id          int             '$.id',
        terminal    nvarchar(100)   '$.terminal',
        queueName   nvarchar(100)   '$.queueName',
        isFastTrack bit             '$.isFastTrack',
        currentProjectedWaitTime int '$.currentProjectedWaitTime'
    );

--- JSON_VALUE() returns a specific scalar value from the JSON blob,
--- using a JSON path expression:
SELECT JSON_VALUE(@response, '$.result.waitTimes[6].queueName');

GO








-------------------------------------------------------------------------------
--- Practical example: Replacing an ETL job with T-SQL.
---
--- All upcoming departures from Stockholm Arlanda Airport:
-------------------------------------------------------------------------------

DECLARE @airport char(3)='ARN';
DECLARE @url nvarchar(max)=
    N'https://api.swedavia.se/flightinfo/v2/'+@airport+
    N'/departures/'+CONVERT(varchar(10), SYSDATETIME(), 121);

DECLARE @response nvarchar(max);

EXECUTE sys.sp_invoke_external_rest_endpoint
    @url=@url,
    @credential=[https://api.swedavia.se/flightinfo/v2],
    @method='GET',
    @response=@response OUTPUT;

SELECT @response;



TRUNCATE TABLE dbo.departures;

WITH parsed_json AS (
    SELECT *
    FROM OPENJSON(@response, '$.result.flights')
        WITH (
            id          varchar(10)     '$.flightId',
            codeshare   varchar(10)     '$.codeShareData[0]',
            terminal    varchar(10)     '$.locationAndStatus.terminal',
            callsign    varchar(10)     '$.flightLegIdentifier.callsign',
            airline     varchar(10)     '$.airlineOperator.iata',
            departureTimeUtc datetime2(0) '$.departureTime.scheduledUtc',
            departure   varchar(3)      '$.flightLegIdentifier.departureAirportIata',
            destination varchar(3)      '$.flightLegIdentifier.arrivalAirportIata',
            via         varchar(3)      '$.flightLegIdentifier.viaDestinations[0].airportIATA',
            registration varchar(10)    '$.flightLegIdentifier.aircraftRegistration'
        ))

INSERT INTO dbo.departures
SELECT *
FROM parsed_json;

GO

SELECT *
FROM dbo.departures
WHERE destination='LHR'
ORDER BY departureTimeUtc





-------------------------------------------------------------------------------
--- Turn our recordset back into JSON using "FOR JSON"
-------------------------------------------------------------------------------

--- Plain SELECT *
SELECT *
FROM dbo.departures
FOR JSON PATH, ROOT('departures');



--- Explicit JSON schema
SELECT id AS [flight.flightNo],
       codeshare AS [flight.codeshare],
       airline,
       departure AS [departure.iata],
       departureTimeUtc AS [departure.time],
       destination,
       registration AS [aircraft.registration]
FROM dbo.departures
FOR JSON PATH, ROOT('departures');

GO




--- Put the JSON blob in a json variable
DROP TABLE IF EXISTS dbo.blobs;

DECLARE @blob json=(
    SELECT id AS [flight.flightNo],
        codeshare AS [flight.codeshare],
        airline,
        departure AS [departure.iata],
        departureTimeUtc AS [departure.time],
        destination,
        registration AS [aircraft.registration]
    FROM dbo.departures
    FOR JSON PATH, ROOT('departures'));

--- ... and save it in a table:
SELECT 1 AS id,
       @blob AS blob
INTO dbo.blobs;






-------------------------------------------------------------------------------
--- Modify data in the table
-------------------------------------------------------------------------------

SELECT JSON_MODIFY(blob, '$.departures[0].destination', 'XXX')
FROM dbo.blobs
WHERE id=1;

UPDATE dbo.blobs
SET blob=JSON_MODIFY(blob, '$.departures[0].destination', 'XXX')
WHERE id=1;

UPDATE dbo.blobs
SET blob.modify('$.departures[0].destination', 'XXX')
WHERE id=1;


SELECT * FROM dbo.blobs;


GO









-------------------------------------------------------------------------------
--- Bonus content:
-------------------------------------------------------------------------------








--- JSON_ARRAY()
--- ------------
--- Creates an array of JSON objects
DECLARE @a json=N'{ "a1": 101, "name": "Test value 1" }',
        @b json=N'{ "a2": 102, "name": "Test value 2" }',
        @c json=N'{ "a3": 103, "name": "Test value 3" }';

SELECT JSON_ARRAY(@a, @b, @c);

--- ... and JSON_ARRAY() can also be used to create a regular array of values:
SELECT JSON_ARRAY('Test value 1', 'Test value 2', 'Test value 3', 'Test value 4');

GO






--- JSON_ARRAYAGG()
--- ---------------
--- Creates a JSON array of values
SELECT JSON_ARRAYAGG(v)
FROM (
    VALUES ('Text value 1'),
           ('Text value 2'),
           ('Text value 3')
    ) AS x(v);

GO



--- ... but JSON_ARRAYAGG() works the same as JSON_ARRAY()
--- if you pass JSON objects as inputs:
DECLARE @a json=N'{ "id": 101, "name": "Test value 1" }',
        @b json=N'{ "id": 102, "name": "Test value 2" }',
        @c json=N'{ "id": 103, "name": "Test value 3" }';

SELECT JSON_ARRAYAGG(v)
FROM (
    VALUES (@a),
           (@b),
           (@c)
    ) AS x(v);

GO






--- JSON_OBJECT() 
--- -------------
--- does what it says on the tin - it constructs a JSON object.

SELECT JSON_OBJECT('id': 101, 'name': 'Test value 1');

--- Similar to just casting a plain string as JSON...
SELECT CAST('{ "id": 101, "name": "Test value 1" }' AS json);

--- ... but useful for "parameterizing" your JSON objects:
SELECT JSON_OBJECT('id': 101, 'name': [name]) AS the_new_hotness,
       '{ "id": 101, "name": '+QUOTENAME([name], '"')+'}'
FROM (
    VALUES ('Test value 1')
    ) AS x([name]);

GO






--- JSON_OBJECTAGG()
--- ----------------
--- aggregates multiple rows into properties on a single JSON object:

SELECT JSON_OBJECTAGG(x.attr:x.val) AS the_new_hotness,
       '{'+STRING_AGG(
            QUOTENAME(attr, '"')+', '+CAST(val AS nvarchar(10)),
            ', ')+
        '}' AS old_school
FROM (
    VALUES ('width', 100.12),
           ('height', 200.34),
           ('depth', 55.1)
    ) AS x(attr, val);




