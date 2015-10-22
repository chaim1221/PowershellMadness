param (
    [int]$DaysAgo = 145,
    [string]$FileType = "*.*"
)

[string]$webDirectory = "C:\inetpub\wwwroot"

try
{
    Get-ChildItem -File -filter $FileType -recurse -path $webDirectory | 
    ? {$_.LastWriteTime -ge (get-date).AddDays(-1 * $DaysAgo) -and $_.Name -notmatch "nlog" } | 
    Select-Object FullName, LastWriteTime |
    Group-Object LastWriteTime
}
catch
{
    $Host.UI.WriteErrorLine("Whoops! An error occurred.")
}
# TODO get grouping to actually work