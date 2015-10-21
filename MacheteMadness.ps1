param (
    [int]$DaysAgo = 30,
    [string]$FileType = "*.*"
)

[string]$webDirectory = "C:\inetpub\wwwroot"

function DisplayUsage {
    Write-Host ("In display usage")
    Exit
}

try
{
    Get-ChildItem -filter $FileType -recurse -path C:\inetpub\wwwroot | where {$_.LastWriteTime -gt (get-date).AddDays(-1 * $DaysAgo)}
}
catch
{
    $Host.UI.WriteErrorLine("Whoops! An error occurred.")
    DisplayUsage
}
