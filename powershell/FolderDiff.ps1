<#
   Script to compare content of two folders 

   Last Update: 07.05.2026
   author: xxxvodnikxxx
#>


# --- Define folder paths ---
$Folder1 = "D:\Downloads\refFolder1"
$Folder2 = "D:\Downloads\refFolder2"

# --- Get list of files (relative paths) ---
$files1 = Get-ChildItem -Path $Folder1 -File -Recurse | ForEach-Object {
    $_.FullName.Substring($Folder1.Length + 1)
}

$files2 = Get-ChildItem -Path $Folder2 -File -Recurse | ForEach-Object {
    $_.FullName.Substring($Folder2.Length + 1)
}

# --- Compare folders ---
$onlyInFolder1 = $files1 | Where-Object { $_ -notin $files2 }
$onlyInFolder2 = $files2 | Where-Object { $_ -notin $files1 }
$inBoth = $files1 | Where-Object { $_ -in $files2 }

# --- Output results ---
Write-Host "`nFiles only in ${Folder1}:"
$onlyInFolder1

<# optionally  #> 
Write-Host "`nFiles only in ${Folder2}:"
$onlyInFolder2

<# optionally  #> 
Write-Host "`nFiles in both folders:"
$inBoth
