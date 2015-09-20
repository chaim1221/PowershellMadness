[string]$hosts = "C:\windows\system32\drivers\etc\hosts"
[bool]$removing = $false
$catHosts = cat $hosts

function ExitWithErrors {
    $Host.UI.WriteErrorLine("ERROR: Exiting with errors.")
    Exit
}

function DisplayUsage {
    Write-Warning "Incorrect parameters."
    Write-Host "`n`tUsage:`n`n`t.\Set-Adapter-DNS.ps1 IPv4Address Namespace [-Remove]`n"
}

function Validate {
    param ($InputValues)
    
    [bool]$removeParamErrors = ($InputValues[2] -ne $null -and $InputValues[2] -ne "-Remove")
    [bool]$namespaceErrors = $InputValues[1] -eq $null -or (($InputValues[1] -split "\.").Count -ne 3)
    [bool]$ipParamErrors = $InputValues[0] -eq $null -or (($InputValues[0] -split "\.").Count -ne 4)
    
    if ($removeParamErrors -or $namespaceErrors -or $ipParamErrors)
    {
        DisplayUsage
        ExitWithErrors
    }
}

function ExitIfMatches {
    param ([string]$IpAddress, [string]$Namespace, [string]$Removing)
    
    if ($Removing -eq "-Remove") 
    { 
        Set-Variable -scope 1 -Name "Removing" -Value $true 
    }
    else
    {
        [bool]$shouldExit = $false;
        $ipAddressMatches = $catHosts | where { $_ -match "^(?!#).*$IpAddress.*" }
        $namespaceMatches = $catHosts | where { $_ -match "^(?!#).*$Namespace.*" }

        if ($ipAddressMatches) { 
            $values = foreach ($line in $ipAddressMatches) { ($line -split "\s+") | Select-Object -Last 1 }
            [string]$warning = "\hosts already contains at least one value for ($IpAddress): $values"
            
            Write-Warning $warning 
            foreach ($value in $values)
            {
                if ($value -eq $Namespace)
                { 
                    [string]$error = "ERROR: Of these, $value already matches $Namespace"
                    $Host.UI.WriteErrorLine($error)
                    $shouldExit = $true 
                }
            }
        }
        
        if ($namespaceMatches)
        {
            $values = foreach ($line in $namespaceMatches) { ($line -split "\s+") | Select-Object -Last 1 }

            foreach ($value in $values)
            {
                if ($value -eq $Namespace)
                { 
                    [string]$error = "ERROR: \hosts already contains a value for ($Namespace); multiple entries are not allowed!"
                    $Host.UI.WriteErrorLine($error)
                    $shouldExit = $true
                }
            }
        }
        
        if ($shouldExit)
        {
            ExitWithErrors
        }
    }
}

function WriteLine {
    param ([string]$IpAddress, [string]$Namespace)
    [string]$date = Get-Date -Format F
    [bool]$hasPermission = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (!$hasPermission)
    {
        ExitWithErrors
    }

    if (!$removing)
    {
        [string]$value = "`n# Added by Set-Adapter-DNS $date`n$IpAddress`t$Namespace`n"

        Write-Host `nAdding the following lines to ($hosts):`n
        Write-Host $value
        Write-Host "To remove the above values, simply run this script with the same arguments followed by -Remove."

        Add-Content $hosts $value
    }
    else
    {
        $namespaceMatches = $catHosts | where { $_ -match "^(?!#).*\s$Namespace.*" }
    
        Write-Warning "Removing the following lines from ($hosts):"
     
        if ($namespaceMatches -eq $null) 
        { 
            Write-Warning "Nothing to remove!" 
        }
        else 
        {
            foreach ($match in $namespaceMatches)
            {
                Write-Host $match
                $catHosts | %{ $_ -replace "^$match", "# Line removed by Set-Adapter-DNS:`n# $match" } | Set-Content $hosts
            }
        }
    }
}

Write-Host "`nSet-Adapter-DNS created July 29, 2015 by Chaim Eliyah`n"
Validate $args
ExitIfMatches $args[0] $args[1] $args[2]
WriteLine $args[0] $args[1]
Write-Host "`nExiting without errors."
