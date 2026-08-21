#requires -Version 7.0

<#
================================================================================
 Google ICS Importer
================================================================================

Imports standard iCalendar (.ics) files into a selected Google Calendar.

Features:
    - Imports all *.ics files from the configured folder
    - UTF-8 / UTF-8 BOM support
    - Preserves Unicode characters and diacritics
    - Handles iCalendar line folding
    - Handles iCalendar escaping
    - Supports timed and all-day events
    - Preserves title, date/time, location, description and URL
    - Detects duplicates using the original ICS UID
    - Moves successfully processed files to Imported\
    - Moves failed files to Failed\
    - Uses Google Calendar REST API
    - Compatible with PowerShell 7+
    - Designed to work in Constrained Language Mode


================================================================================
 REQUIREMENTS
================================================================================

PowerShell:

    PowerShell 7.0 or newer

Check your version with:

    $PSVersionTable.PSVersion

The script requires PowerShell 7+.

Do not run it with Windows PowerShell 5.1.


================================================================================
 GOOGLE CLOUD SETUP
================================================================================

The script uses Google OAuth 2.0 and the Google Calendar REST API.

You need:

    1. A Google Cloud project
    2. Google Calendar API enabled
    3. Google Auth Platform configured
    4. An OAuth Desktop application
    5. A Google Calendar ID
    6. Your OAuth Client ID
    7. Your OAuth Client Secret
    8. A Google account authorized as a test user
    9. A refresh token generated during the first run


--------------------------------------------------------------------------------
 1. CREATE A GOOGLE CLOUD PROJECT
--------------------------------------------------------------------------------

Open:

    https://console.cloud.google.com/

Create a new Google Cloud project.

Example project name:

    Google ICS Importer

If you already have a suitable project, you can use it instead.


--------------------------------------------------------------------------------
 2. ENABLE GOOGLE CALENDAR API
--------------------------------------------------------------------------------

This step is REQUIRED.

Open:

    https://console.cloud.google.com/apis/library

Make sure the correct Google Cloud project is selected.

Search for:

    Google Calendar API

Open it and click:

    Enable

The API service used by this script is:

    calendar-json.googleapis.com

Direct API page:

    https://console.developers.google.com/apis/api/calendar-json.googleapis.com/overview

If the Calendar API is disabled, the script will fail with:

    403 Forbidden

    Google Calendar API has not been used in project ...
    or it is disabled.

No API key is required for this script.

The script authenticates using OAuth 2.0.


--------------------------------------------------------------------------------
 3. CONFIGURE GOOGLE AUTH PLATFORM
--------------------------------------------------------------------------------

Open:

    https://console.cloud.google.com/auth/overview

If Google Auth Platform has not been configured yet, start the setup.

Configure the application information.

Application name:

    Google ICS Importer

Provide a support email if requested.

For a personal Google account, use:

    Audience: External

Google currently manages these settings through:

    Google Auth Platform
        -> Branding
        -> Audience
        -> Data Access


--------------------------------------------------------------------------------
 4. ADD YOUR GOOGLE ACCOUNT AS A TEST USER
--------------------------------------------------------------------------------

If the application is configured as:

    External

and it is still in testing mode, your Google account must be listed
as a test user.

Open:

    https://console.cloud.google.com/auth/audience

Find:

    Test users

Click:

    Add users

Add the Google account that will authorize the script.

Example:

    your-account@gmail.com

Save the configuration.

If your Google account is not listed as a test user, authorization may
fail with:

    Error 403: access_denied

    The app is currently being tested and only approved test users
    can access it.

For a personal script used only by yourself, adding your account as
a test user is normally sufficient.

You do not need to publish the application just to use it yourself.


--------------------------------------------------------------------------------
 5. CONFIGURE GOOGLE OAUTH CLIENT
--------------------------------------------------------------------------------

Open:

    https://console.cloud.google.com/auth/clients

Create a new OAuth client.

Select:

    Application type:
        Desktop app

Example name:

    Google ICS Importer

Click:

    Create

Google will generate:

    Client ID
    Client Secret

Copy both values into the USER CONFIGURATION section of this script.

The script uses these values directly.

This script does NOT require:

    credentials.json
    token.json

No Google API key is required.


--------------------------------------------------------------------------------
 6. OAUTH REDIRECT URI
--------------------------------------------------------------------------------

The script uses:

    http://localhost

as its OAuth redirect URI.

This is intentional.

After successful authorization Google redirects the browser to:

    http://localhost/?code=...

The script does not host a web page on localhost.

Instead, you manually copy the complete URL from the browser address bar
and paste it into PowerShell.

The OAuth client must therefore be:

    Desktop app

Do not create a Web application OAuth client for this script.


--------------------------------------------------------------------------------
 7. FIND THE TARGET GOOGLE CALENDAR ID
--------------------------------------------------------------------------------

Open:

    https://calendar.google.com/

Find the calendar into which the ICS events should be imported.

Open:

    Calendar
        -> Settings and sharing
        -> Integrate calendar

Find:

    Calendar ID

Examples:

    primary

or:

    abc123456789@group.calendar.google.com

Copy the Calendar ID.

Put it into:

    CalendarId = "..."

The Google account used during OAuth must have permission to add events
to this calendar.

For a calendar owned by the same Google account, this is normally already
the case.


--------------------------------------------------------------------------------
 8. CONFIGURE THE SCRIPT
--------------------------------------------------------------------------------

At the beginning of the script find:

    $config = @{

Configure:

    CalendarId
    IcsFolder
    ClientId
    ClientSecret
    RefreshToken


Example:

    CalendarId = "abc123@group.calendar.google.com"

    IcsFolder = "D:\Downloads\ics"

    ClientId = "1234567890-xxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com"

    ClientSecret = "GOCSPX-xxxxxxxxxxxxxxxxxxxxxxxx"

    RefreshToken = ""


Do not copy these example values literally.


--------------------------------------------------------------------------------
 9. FIRST RUN - AUTHORIZE GOOGLE
--------------------------------------------------------------------------------

For the first run leave:

    RefreshToken = ""

Run the script from PowerShell 7:

    .\ICS-GoogleImporter.ps1

The script will open the Google authorization page.

If the browser does not open automatically, the script will display
the authorization URL.

Open the URL manually if necessary.


--------------------------------------------------------------------------------
 10. GOOGLE AUTHORIZATION
--------------------------------------------------------------------------------

Sign in using the Google account that was added as a test user.

Google will display the permissions requested by the application.

The script requests:

    https://www.googleapis.com/auth/calendar

This allows the application to read and modify Google Calendar data.

Authorize the application.


--------------------------------------------------------------------------------
 11. COPY THE CALLBACK URL
--------------------------------------------------------------------------------

After authorization Google redirects the browser to:

    http://localhost/?code=...

The browser may display an error or an empty page because the script does
not actually host a web page on localhost.

This is expected.

Copy the COMPLETE URL from the browser address bar.

Example:

    http://localhost/?iss=https://accounts.google.com&code=4/0ATs...&scope=https://www.googleapis.com/auth/calendar

Paste the complete URL into PowerShell when the script asks:

    Paste the callback URL here:


--------------------------------------------------------------------------------
 12. SAVE THE REFRESH TOKEN
--------------------------------------------------------------------------------

The script will exchange the authorization code for a Google refresh token.

It will display:

    Google Refresh Token

Copy the entire refresh token.

Put it into:

    RefreshToken = "..."

Example:

    RefreshToken = "1//0xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

Save the script.

IMPORTANT:

The refresh token is sensitive.

Treat it like a password.

Do not publish it to GitHub, paste it into public forums, or share it
with other people.


--------------------------------------------------------------------------------
 13. RUN THE IMPORTER
--------------------------------------------------------------------------------

After the refresh token has been configured, simply run:

    .\ICS-GoogleImporter.ps1

The script will:

    1. Authenticate using the refresh token
    2. Find *.ics files
    3. Parse the ICS files
    4. Detect duplicate events using ICS UID
    5. Create missing events in the selected Google Calendar
    6. Move successful files to Imported\
    7. Move failed files to Failed\


================================================================================
 FILE STRUCTURE
================================================================================

Example:

    D:\Downloads\ics\
        event1.ics
        event2.ics

After successful processing:

    D:\Downloads\ics\
        Imported\
            event1.ics
            event2.ics

Failed files are moved to:

    D:\Downloads\ics\
        Failed\
            event1.ics


================================================================================
 DUPLICATE DETECTION
================================================================================

The importer uses the original ICS:

    UID

to identify events.

The UID is stored in Google Calendar as a private extended property:

    IcsUID

If the same ICS event is imported again, the importer detects the existing
event and skips it.

This allows the same ICS file to be processed repeatedly without creating
duplicate Google Calendar events.


================================================================================
 SECURITY
================================================================================

Sensitive values:

    ClientSecret
    RefreshToken

Do not publish them.

The Client ID is not itself a password, but it should still not be
unnecessarily exposed.

If this script is stored in Git, consider keeping the actual configuration
in a separate local file that is excluded through .gitignore.


================================================================================
 TROUBLESHOOTING
================================================================================

ERROR:

    403 Forbidden
    Google Calendar API has not been used in project ...
    or it is disabled.

Solution:

    Enable Google Calendar API in the Google Cloud project.


ERROR:

    403 access_denied
    The app is currently being tested and only approved test users
    can access it.

Solution:

    Add the Google account to:

        Google Auth Platform
            -> Audience
            -> Test users


ERROR:

    redirect_uri_mismatch

Solution:

    Make sure the OAuth client is a Desktop application.

The script uses:

    http://localhost


ERROR:

    Google did not return a refresh token.

Solution:

    Make sure the authorization request uses:

        access_type=offline
        prompt=consent

The script already does this.

If necessary, revoke the application's existing authorization from your
Google account and perform the first-run authorization again.


ERROR:

    Google authentication successful
    but Calendar API returns 403

Solution:

    Make sure Google Calendar API is enabled in the SAME Google Cloud
    project that owns the OAuth Client ID.


ERROR:

    Cannot invoke method. Method invocation is supported only on core types
    in this language mode.

Solution:

    The script is designed for Constrained Language Mode.

Make sure you are running the current version of the script.

Check:

    $ExecutionContext.SessionState.LanguageMode

The script should avoid .NET methods that are blocked by Constrained
Language Mode.


================================================================================
 QUICK SETUP CHECKLIST
================================================================================

Google Cloud:

    [ ] Google Cloud project created
    [ ] Google Calendar API enabled
    [ ] Google Auth Platform configured
    [ ] Application configured as External
    [ ] Google account added as Test user
    [ ] OAuth Desktop client created
    [ ] Client ID copied
    [ ] Client Secret copied

Google Calendar:

    [ ] Target calendar created/selected
    [ ] Calendar ID copied
    [ ] Authorizing Google account has permission to edit the calendar

PowerShell:

    [ ] PowerShell 7+ installed
    [ ] ICS folder configured
    [ ] ClientId configured
    [ ] ClientSecret configured
    [ ] CalendarId configured
    [ ] First authorization completed
    [ ] RefreshToken configured

Files:

    [ ] *.ics files placed into IcsFolder


================================================================================
 IMPORTANT
================================================================================

This script does NOT require:

    - credentials.json
    - token.json
    - Google API key
    - Google Cloud service account
    - Google Cloud SDK
    - Google Calendar desktop application
    - any PowerShell module
    - any third-party PowerShell package

The script communicates directly with:

    Google OAuth 2.0
    Google Calendar REST API


================================================================================
#>


Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


# ============================================================
# USER CONFIGURATION
# ============================================================

$config = @{

    # ========================================================
    # REQUIRED
    # ========================================================

    # Google Calendar ID where ICS events will be imported
    CalendarId = "PASTE_CALENDAR_ID_HERE"

    # Folder containing ICS files
    IcsFolder = "D:\Downloads\ics"

    # Google OAuth Client ID
    ClientId = "PASTE_CLIENT_ID_HERE"

    # Google OAuth Client Secret
    ClientSecret = "PASTE_CLIENT_SECRET_HERE"


    # ========================================================
    # FIRST RUN
    # ========================================================

    # Leave empty on the first run.
    # The script will guide you through Google authorization
    # and obtain a refresh token.
    RefreshToken = ""


    # ========================================================
    # OPTIONAL
    # ========================================================

    # Move successfully imported ICS files to:
    # <IcsFolder>\Imported\
    ArchiveImportedFiles = $true
}


# ============================================================
# INTERNAL CONFIGURATION
# ============================================================

$ImportedFolder = Join-Path $config.IcsFolder "Imported"
$FailedFolder   = Join-Path $config.IcsFolder "Failed"

$GoogleTokenEndpoint = "https://oauth2.googleapis.com/token"
$GoogleAuthEndpoint  = "https://accounts.google.com/o/oauth2/v2/auth"
$GoogleCalendarApi   = "https://www.googleapis.com/calendar/v3"

$GoogleScope = "https://www.googleapis.com/auth/calendar"

$OAuthRedirectUri = "http://localhost"


# ============================================================
# OUTPUT HELPERS
# ============================================================

function Write-Info {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[INFO] $Message"
}


function Write-Ok {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[OK]   $Message"
}


function Write-Skip {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[SKIP] $Message"
}


function Write-Fail {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}


# ============================================================
# GENERAL HELPERS
# ============================================================

function Ensure-Directory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}


function Get-UrlEncoded {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return [Uri]::EscapeDataString($Value)
}


# ============================================================
# GOOGLE OAUTH
# ============================================================

function Get-GoogleAuthorizationUrl {

    $parameters = @(
        "client_id=$(Get-UrlEncoded $config.ClientId)"
        "redirect_uri=$(Get-UrlEncoded $OAuthRedirectUri)"
        "response_type=code"
        "scope=$(Get-UrlEncoded $GoogleScope)"
        "access_type=offline"
        "prompt=consent"
    )

    return "${GoogleAuthEndpoint}?" + ($parameters -join "&")
}


function Get-GoogleRefreshTokenInteractive {

    $authorizationUrl =
        Get-GoogleAuthorizationUrl


    Write-Host ""
    Write-Host "============================================================"
    Write-Host " Google Authorization"
    Write-Host "============================================================"
    Write-Host ""

    Write-Info "Opening Google authorization page..."

    Start-Process $authorizationUrl


    Write-Host ""
    Write-Host "If the browser does not open automatically, use this URL:"
    Write-Host ""
    Write-Host $authorizationUrl -ForegroundColor Cyan
    Write-Host ""

    Write-Host "After authorization, Google will redirect the browser."
    Write-Host "Copy the COMPLETE URL from the browser address bar."
    Write-Host ""

    $callbackUrl =
        Read-Host "Paste the callback URL here"


    if (
        [string]::IsNullOrWhiteSpace($callbackUrl)
    ) {

        throw "No callback URL was provided."
    }


    # Extract the authorization code directly from the callback URL.
    # This avoids System.Web.HttpUtility, which is blocked by
    # Constrained Language Mode.

    $code = $null

    if ($callbackUrl -match '(?:\?|&)code=([^&]+)') {
        $code = $Matches[1]
    }


    # Check whether Google returned an OAuth error.

    $oauthError = $null

    if ($callbackUrl -match '(?:\?|&)error=([^&]+)') {
        $oauthError = $Matches[1]
    }


    if (-not [string]::IsNullOrWhiteSpace($oauthError)) {
        throw "Google OAuth error: $oauthError"
    }


    if ([string]::IsNullOrWhiteSpace($code)) {

        throw @"
No authorization code was found in the callback URL.

Make sure you copied the complete URL from the browser address bar.
"@
    }


    Write-Info "Authorization code received."
    Write-Info "Requesting refresh token from Google..."


    $body = @{
        client_id     = $config.ClientId
        client_secret = $config.ClientSecret
        code          = $code
        grant_type    = "authorization_code"
        redirect_uri  = $OAuthRedirectUri
    }


    try {

        $response =
            Invoke-RestMethod `
                -Method Post `
                -Uri $GoogleTokenEndpoint `
                -ContentType "application/x-www-form-urlencoded" `
                -Body $body
    }
    catch {

        throw "Google token request failed: $($_.Exception.Message)"
    }


    if (
        [string]::IsNullOrWhiteSpace(
            $response.refresh_token
        )
    ) {

        throw @"
Google did not return a refresh token.

Make sure the OAuth authorization request included:
    access_type=offline
    prompt=consent

If the application was already authorized, revoke its previous access
and authorize it again.
"@
    }


    return $response.refresh_token
}


function Get-GoogleAccessToken {

    if (
        [string]::IsNullOrWhiteSpace(
            $config.RefreshToken
        )
    ) {

        throw "Google RefreshToken is empty."
    }


    $body = @{
        client_id     = $config.ClientId
        client_secret = $config.ClientSecret
        refresh_token = $config.RefreshToken
        grant_type    = "refresh_token"
    }


    try {

        $response =
            Invoke-RestMethod `
                -Method Post `
                -Uri $GoogleTokenEndpoint `
                -ContentType "application/x-www-form-urlencoded" `
                -Body $body
    }
    catch {

        throw "Unable to refresh Google access token: $($_.Exception.Message)"
    }


    if (
        [string]::IsNullOrWhiteSpace(
            $response.access_token
        )
    ) {

        throw "Google did not return an access token."
    }


    return $response.access_token
}


# ============================================================
# GOOGLE API
# ============================================================

function Invoke-GoogleApi {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("GET", "POST")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$AccessToken,

        [object]$Body
    )


    $headers = @{
        Authorization = "Bearer $AccessToken"
    }


    $parameters = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
    }


    if ($null -ne $Body) {

        $parameters.ContentType =
            "application/json; charset=utf-8"

        $parameters.Body =
            $Body |
            ConvertTo-Json -Depth 20 -Compress
    }


    try {

        return Invoke-RestMethod @parameters
    }
    catch {

        $message =
            $_.Exception.Message

        if (
            -not [string]::IsNullOrWhiteSpace(
                $_.ErrorDetails.Message
            )
        ) {

            $message +=
                " | " +
                $_.ErrorDetails.Message
        }

        throw $message
    }
}


function Test-GoogleEventExists {
    param(
        [Parameter(Mandatory)]
        [string]$CalendarId,

        [Parameter(Mandatory)]
        [string]$Uid,

        [Parameter(Mandatory)]
        [string]$AccessToken
    )


    $encodedCalendarId =
        [Uri]::EscapeDataString($CalendarId)


    $encodedProperty =
        [Uri]::EscapeDataString(
            "IcsUID=$Uid"
        )


    $uri =
        "$GoogleCalendarApi/calendars/$encodedCalendarId/events" +
        "?privateExtendedProperty=$encodedProperty" +
        "&maxResults=1" +
        "&showDeleted=false"


    $result =
        Invoke-GoogleApi `
            -Method GET `
            -Uri $uri `
            -AccessToken $AccessToken


    return (
        $null -ne $result.items -and
        $result.items.Count -gt 0
    )
}


function New-GoogleEvent {
    param(
        [Parameter(Mandatory)]
        [string]$CalendarId,

        [Parameter(Mandatory)]
        [string]$AccessToken,

        [Parameter(Mandatory)]
        [hashtable]$Event
    )


    $encodedCalendarId =
        [Uri]::EscapeDataString($CalendarId)


    $uri =
        "$GoogleCalendarApi/calendars/$encodedCalendarId/events"


    return Invoke-GoogleApi `
        -Method POST `
        -Uri $uri `
        -AccessToken $AccessToken `
        -Body $Event
}


# ============================================================
# ICS FILE READING
# ============================================================

function Read-IcsFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Read the ICS file as UTF-8.
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    # Remove UTF-8 BOM if present.
    $text = $text -replace '^\uFEFF', ''

    # Normalize line endings.
    $text = $text -replace "`r`n", "`n"
    $text = $text -replace "`r", "`n"

    # Split physical lines.
    $physicalLines = $text -split "`n"

    # Use a normal PowerShell array.
    $lines = @()

    foreach ($line in $physicalLines) {

        # Handle iCalendar line folding.
        if (
            ($line.StartsWith(" ") -or $line.StartsWith("`t")) -and
            $lines.Count -gt 0
        ) {
            $lines[$lines.Count - 1] =
                $lines[$lines.Count - 1] + $line.Substring(1)
        }
        else {
            $lines += $line
        }
    }

    return $lines
}


# ============================================================
# ICS VALUE PARSING
# ============================================================

function Unescape-IcsValue {
    param(
        [AllowEmptyString()]
        [string]$Value
    )


    if ($null -eq $Value) {
        return ""
    }


    $Value =
        $Value -replace '\\n', "`n"

    $Value =
        $Value -replace '\\N', "`n"

    $Value =
        $Value -replace '\\,', ","

    $Value =
        $Value -replace '\\;', ";"

    $Value =
        $Value -replace '\\\\', "\"


    return $Value
}


function Parse-IcsProperty {
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )


    $colonIndex =
        $Line.IndexOf(":")


    if ($colonIndex -lt 1) {
        return $null
    }


    $left =
        $Line.Substring(
            0,
            $colonIndex
        )


    $value =
        $Line.Substring(
            $colonIndex + 1
        )


    $parts =
        $left -split ";"


    $name =
        $parts[0].ToUpperInvariant()


    $parameters = @{}


    for (
        $i = 1;
        $i -lt $parts.Count;
        $i++
    ) {

        $parameter =
            $parts[$i]


        $eqIndex =
            $parameter.IndexOf("=")


        if ($eqIndex -gt 0) {

            $parameterName =
                $parameter.Substring(
                    0,
                    $eqIndex
                ).ToUpperInvariant()


            $parameterValue =
                $parameter.Substring(
                    $eqIndex + 1
                )


            $parameters[$parameterName] =
                $parameterValue
        }
    }


    return @{
        Name       = $name
        Parameters = $parameters
        Value      = Unescape-IcsValue $value
    }
}


function Get-IcsEvents {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )


    $lines =
        Read-IcsFile -Path $Path


    $events = @()


    $currentEvent = $null


    foreach ($line in $lines) {

        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }


        $upper =
            $line.ToUpperInvariant()


        if ($upper -eq "BEGIN:VEVENT") {

            $currentEvent = @{}

            continue
        }


        if ($upper -eq "END:VEVENT") {

            if ($null -ne $currentEvent) {
                $events += $currentEvent
            }

            $currentEvent = $null

            continue
        }


        if ($null -eq $currentEvent) {
            continue
        }


        $property =
            Parse-IcsProperty -Line $line


        if ($null -eq $property) {
            continue
        }


        $name =
            $property.Name


        if (
            -not $currentEvent.ContainsKey($name)
        ) {

            $currentEvent[$name] =
                $property
        }
    }


    return $events
}


# ============================================================
# ICS DATE / TIME
# ============================================================

function Convert-IcsDateTime {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Property
    )


    $value =
        $Property.Value


    $isDateOnly =
        (
            $Property.Parameters.ContainsKey("VALUE") -and
            $Property.Parameters["VALUE"].ToUpperInvariant() -eq "DATE"
        )


    if (
        $isDateOnly -or
        $value -match '^\d{8}$'
    ) {

        $date =
            [DateTime]::ParseExact(
                $value,
                "yyyyMMdd",
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None
            )


        return @{
            IsDateOnly = $true
            DateTime   = $date
            IsUtc      = $false
            TimeZone   = $null
        }
    }


    $hasUtc =
        $value.EndsWith("Z")


    $cleanValue =
        $value.TrimEnd("Z")


    $formats = @(
        "yyyyMMdd'T'HHmmss",
        "yyyyMMdd'T'HHmm"
    )


    $dateTime = $null


    foreach ($format in $formats) {

        try {

            $dateTime =
                [DateTime]::ParseExact(
                    $cleanValue,
                    $format,
                    [Globalization.CultureInfo]::InvariantCulture,
                    [Globalization.DateTimeStyles]::None
                )

            break
        }
        catch {
        }
    }


    if ($null -eq $dateTime) {

        throw "Unable to parse ICS date/time: $value"
    }


    $timeZone = $null


    if (
        $Property.Parameters.ContainsKey("TZID")
    ) {

        $timeZone =
            $Property.Parameters["TZID"]
    }


    return @{
        IsDateOnly = $false
        DateTime   = $dateTime
        IsUtc      = $hasUtc
        TimeZone   = $timeZone
    }
}


function Convert-IcsDateTimeToGoogle {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parsed
    )


    if ($Parsed.IsDateOnly) {

        return @{
            date =
                $Parsed.DateTime.ToString(
                    "yyyy-MM-dd",
                    [Globalization.CultureInfo]::InvariantCulture
                )
        }
    }


    if ($Parsed.IsUtc) {

        return @{
            dateTime =
                $Parsed.DateTime.ToUniversalTime().ToString(
                    "yyyy-MM-dd'T'HH:mm:ss'Z'",
                    [Globalization.CultureInfo]::InvariantCulture
                )

            timeZone = "UTC"
        }
    }


    $result = @{
        dateTime =
            $Parsed.DateTime.ToString(
                "yyyy-MM-dd'T'HH:mm:ss",
                [Globalization.CultureInfo]::InvariantCulture
            )
    }


    if (
        -not [string]::IsNullOrWhiteSpace(
            $Parsed.TimeZone
        )
    ) {

        $result.timeZone =
            $Parsed.TimeZone
    }


    return $result
}


# ============================================================
# ICS -> GOOGLE EVENT
# ============================================================

function Convert-IcsEventToGoogleEvent {
    param(
        [Parameter(Mandatory)]
        [hashtable]$IcsEvent
    )


    if (-not $IcsEvent.ContainsKey("UID")) {
        throw "VEVENT does not contain UID."
    }


    if (-not $IcsEvent.ContainsKey("DTSTART")) {
        throw "VEVENT does not contain DTSTART."
    }


    if (-not $IcsEvent.ContainsKey("SUMMARY")) {
        throw "VEVENT does not contain SUMMARY."
    }


    $uid =
        $IcsEvent["UID"].Value


    $summary =
        $IcsEvent["SUMMARY"].Value


    $startParsed =
        Convert-IcsDateTime `
            -Property $IcsEvent["DTSTART"]


    $start =
        Convert-IcsDateTimeToGoogle `
            -Parsed $startParsed


    $googleEvent = @{
        summary = $summary

        start = $start

        extendedProperties = @{
            private = @{
                IcsUID = $uid
            }
        }
    }


    if ($IcsEvent.ContainsKey("DTEND")) {

        $endParsed =
            Convert-IcsDateTime `
                -Property $IcsEvent["DTEND"]


        $googleEvent.end =
            Convert-IcsDateTimeToGoogle `
                -Parsed $endParsed
    }
    else {

        if ($startParsed.IsDateOnly) {

            $googleEvent.end = @{
                date =
                    $startParsed.DateTime.
                    AddDays(1).
                    ToString(
                        "yyyy-MM-dd",
                        [Globalization.CultureInfo]::InvariantCulture
                    )
            }
        }
        else {

            $end =
                $startParsed.DateTime.AddHours(1)


            $googleEvent.end = @{
                dateTime =
                    $end.ToString(
                        "yyyy-MM-dd'T'HH:mm:ss",
                        [Globalization.CultureInfo]::InvariantCulture
                    )
            }


            if (
                -not [string]::IsNullOrWhiteSpace(
                    $startParsed.TimeZone
                )
            ) {

                $googleEvent.end.timeZone =
                    $startParsed.TimeZone
            }
        }
    }


    if ($IcsEvent.ContainsKey("LOCATION")) {

        $googleEvent.location =
            $IcsEvent["LOCATION"].Value
    }


    if ($IcsEvent.ContainsKey("DESCRIPTION")) {

        $googleEvent.description =
            $IcsEvent["DESCRIPTION"].Value
    }


    if ($IcsEvent.ContainsKey("URL")) {

        $googleEvent.source = @{
            title = "iCalendar event"
            url   = $IcsEvent["URL"].Value
        }
    }


    return $googleEvent
}


# ============================================================
# VALIDATE CONFIGURATION
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " Google ICS Importer"
Write-Host "============================================"
Write-Host ""


if (
    [string]::IsNullOrWhiteSpace(
        $config.CalendarId
    ) -or
    $config.CalendarId -eq "PASTE_CALENDAR_ID_HERE"
) {

    throw "CalendarId is not configured."
}


if (
    [string]::IsNullOrWhiteSpace(
        $config.IcsFolder
    )
) {

    throw "IcsFolder is not configured."
}


if (
    [string]::IsNullOrWhiteSpace(
        $config.ClientId
    ) -or
    $config.ClientId -eq "PASTE_CLIENT_ID_HERE"
) {

    throw "ClientId is not configured."
}


if (
    [string]::IsNullOrWhiteSpace(
        $config.ClientSecret
    ) -or
    $config.ClientSecret -eq "PASTE_CLIENT_SECRET_HERE"
) {

    throw "ClientSecret is not configured."
}


if (
    -not (Test-Path -LiteralPath $config.IcsFolder)
) {

    throw "ICS folder does not exist: $($config.IcsFolder)"
}


Ensure-Directory -Path $ImportedFolder
Ensure-Directory -Path $FailedFolder


Write-Info "ICS folder      : $($config.IcsFolder)"
Write-Info "Target calendar : $($config.CalendarId)"
Write-Host ""


# ============================================================
# GOOGLE AUTHENTICATION
# ============================================================

if (
    [string]::IsNullOrWhiteSpace(
        $config.RefreshToken
    )
) {

    Write-Info "No Google refresh token configured."
    Write-Info "Starting first-time Google authorization."
    Write-Host ""


    $refreshToken =
        Get-GoogleRefreshTokenInteractive


    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Yellow

    Write-Host " Google Refresh Token" `
        -ForegroundColor Yellow

    Write-Host "============================================================" `
        -ForegroundColor Yellow

    Write-Host ""

    Write-Host $refreshToken `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Copy this value into:"
    Write-Host ""
    Write-Host '    RefreshToken = "..."'
    Write-Host ""

    exit 0
}


$accessToken =
    Get-GoogleAccessToken


Write-Ok "Google authentication successful."

Write-Host ""


# ============================================================
# FIND ICS FILES
# ============================================================

$icsFiles = @(
    Get-ChildItem `
        -LiteralPath $config.IcsFolder `
        -Filter "*.ics" `
        -File
)


if ($icsFiles.Count -eq 0) {

    Write-Info "No .ics files found."

    exit 0
}


Write-Info "Found $($icsFiles.Count) ICS file(s)."

Write-Host ""


$imported = 0
$skipped  = 0
$failed   = 0


# ============================================================
# PROCESS FILES
# ============================================================

foreach ($file in $icsFiles) {

    Write-Host "--------------------------------------------"
    Write-Host "File: $($file.Name)"


    try {

        $events =
            Get-IcsEvents `
                -Path $file.FullName


        if ($events.Count -eq 0) {

            throw "No VEVENT found."
        }


        Write-Info "Events found: $($events.Count)"


        $fileSuccessful = $true


        foreach ($icsEvent in $events) {

            try {

                if (-not $icsEvent.ContainsKey("UID")) {

                    throw "VEVENT does not contain UID."
                }


                if (-not $icsEvent.ContainsKey("SUMMARY")) {

                    throw "VEVENT does not contain SUMMARY."
                }


                $uid =
                    $icsEvent["UID"].Value


                $summary =
                    $icsEvent["SUMMARY"].Value


                Write-Info "Event: $summary"
                Write-Info "UID  : $uid"


                $exists =
                    Test-GoogleEventExists `
                        -CalendarId $config.CalendarId `
                        -Uid $uid `
                        -AccessToken $accessToken


                if ($exists) {

                    Write-Skip "$summary - already exists."

                    $skipped++

                    continue
                }


                $googleEvent =
                    Convert-IcsEventToGoogleEvent `
                        -IcsEvent $icsEvent


                $created =
                    New-GoogleEvent `
                        -CalendarId $config.CalendarId `
                        -AccessToken $accessToken `
                        -Event $googleEvent


                Write-Ok "$summary"

                $imported++
            }
            catch {

                $fileSuccessful = $false

                $failed++

                Write-Fail $_.Exception.Message
            }
        }


        if (
            $fileSuccessful -and
            $config.ArchiveImportedFiles
        ) {

            $destination =
                Join-Path `
                    $ImportedFolder `
                    $file.Name


            Move-Item `
                -LiteralPath $file.FullName `
                -Destination $destination `
                -Force


            Write-Ok "Moved to Imported\"
        }
    }
    catch {

        $failed++

        Write-Fail $_.Exception.Message

        try {

            $destination =
                Join-Path `
                    $FailedFolder `
                    $file.Name


            Move-Item `
                -LiteralPath $file.FullName `
                -Destination $destination `
                -Force


            Write-Info "Moved to Failed\"
        }
        catch {

            Write-Fail `
                "Unable to move failed file: $($_.Exception.Message)"
        }
    }


    Write-Host ""
}


# ============================================================
# SUMMARY
# ============================================================

Write-Host "============================================"
Write-Host " Summary"
Write-Host "============================================"
Write-Host ""

Write-Host "Imported : $imported"
Write-Host "Skipped  : $skipped"
Write-Host "Failed   : $failed"

Write-Host ""
