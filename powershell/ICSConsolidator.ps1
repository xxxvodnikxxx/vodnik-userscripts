<#
 ICS Consolidator – Compatible with Constrained Language Mode (UTF-8 compatible)

 Loads the .ics files from the specified folder, extracts events, and consolidates them into a single .ics file.

 Last Update: 07.05.2026
 Author: xxxvodnikxxx
#>



# Set source folder and output file path
$source = "D:\Downloads\ics"
$outputFile = "$source\consolidated.ics"

# Get all .ics files
$icsFiles = Get-ChildItem -Path $source -Filter *.ics

# Initialize header array
$consolidatedContent = @(
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//vodnikovo.cz//script//EN"
)

# Process each file
foreach ($file in $icsFiles) {
    Write-Host "Processing file: $file" -ForegroundColor Cyan

    # Read file content with UTF-8 encoding
    $fileContent = Get-Content -Path $file.FullName -Encoding utf8
    $isEvent = $false
    $eventBuffer = @()
    $eventIndex = 0
    $eventSummary = ""
    $eventStart = ""
    $eventLocation = ""

    # Process each line
    foreach ($line in $fileContent) {
        if ($line -eq "BEGIN:VEVENT") {
            $isEvent = $true
            $eventBuffer = @()
            $eventSummary = ""
            $eventStart = ""
            $eventLocation = ""
        }

        if ($isEvent) {
            $eventBuffer += $line
            if ($line -like "SUMMARY:*") {
                $eventSummary = $line.Substring(8) # Extract after "SUMMARY:"
            }
            if ($line -like "DTSTART*") {
                $eventStart = $line.Substring(8) # Extract after "DTSTART"
            }
            if ($line -like "LOCATION:*") {
                $eventLocation = $line.Substring(9) # Extract after "LOCATION:"
            }
        }

        if ($line -eq "END:VEVENT") {
            $isEvent = $false
            $eventIndex = $eventIndex + 1
            Write-Host "  - Event #$eventIndex found in $file" -ForegroundColor Gray
            if ($eventSummary) {
                Write-Host "    Summary: $eventSummary" -ForegroundColor Gray
            } else {
                Write-Host "    Summary: (No summary found)" -ForegroundColor Gray
            }
            if ($eventStart) {
                # Convert DTSTART (YYYYMMDDTHHMMSSZ) to DD-MM-YYYY HH:MM
                $datePart = $eventStart.Substring(0, 8)
                $timePart = $eventStart.Substring(9, 6)
                $formattedDate = "$($datePart.Substring(6, 2))-$($datePart.Substring(4, 2))-$($datePart.Substring(0, 4)) $($timePart.Substring(0, 2)):$($timePart.Substring(2, 2))"
                Write-Host "    Start: $formattedDate" -ForegroundColor Gray
            } else {
                Write-Host "    Start: (No start date found)" -ForegroundColor Gray
            }
            if ($eventLocation) {
                Write-Host "    Location: $eventLocation" -ForegroundColor Gray
            } else {
                Write-Host "    Location: (No location found)" -ForegroundColor Gray
            }
            $consolidatedContent += $eventBuffer
        }
    }

    if ($eventIndex -eq 0) {
        Write-Host "  No events found in $file" -ForegroundColor DarkYellow
    }
}

# Add calendar end
$consolidatedContent += "END:VCALENDAR"

# Write output file using UTF-8 encoding
$consolidatedContent | Out-File -FilePath $outputFile -Encoding utf8

Write-Host ""
Write-Host "Done! Output written to: $outputFile" -ForegroundColor Green