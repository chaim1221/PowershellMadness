
Add-Type -TypeDefinition @"
    public enum ValidFirstArgs {
        List,
        Start,
        Stop,
        Bounce,
        Help
    }
"@

Add-Type -TypeDefinition @"
    public enum ValidSecondArgs {
        All,
        Started,
        Stopped,
        Restarting,
        ById
    }
"@

function DisplayUsage {
    Write-Host "`n`tUsage:`n`n`t.\IISMadness.ps1 [ -List | -Start | -Stop | -Bounce ] [ -All | -Started | -Stopped | -Restarting | -ById ] [Id] `n"
    Write-Host "`tWhere -List displays information, -Start spins up, -Stop stops, and -Bounce restarts the specified websites.`n"
    Write-Host "`t-All means all websites, -Started affects only started websites, -Stopped affects only stopped websites, and -Restarting affects only websites that are restarting.`n"
    Write-Host "`tYou can also use the -ById option to specify the ID of the website you want to start, stop, or bounce."

    Exit
}


function ExitWithError {
    param ($ErrorMessage) 

    $Host.UI.WriteErrorLine($ErrorMessage)
    DisplayUsage
}

function ValidateArgs {
    param ($Inputs)

    [string]$errorMessage = ""

    if ($Inputs -eq $null) {
        $errorMessage += "`nInputs null."
    }
        
    if (-not [System.Enum]::IsDefined([ValidFirstArgs], ($Inputs[0] -replace "-", ""))) {
        $errorMessage += "`nFirst argument inappropriate."
    }

    if ($Inputs[0] -eq "-Help") {
        DisplayUsage
    }
    
    if (-not [System.Enum]::IsDefined([ValidSecondArgs], ($Inputs[1] -replace "-", ""))) {
        $errorMessage += "`nSecond argument inappropriate."
    }

    if ($Inputs[1] -ne "-ById" -and $Inputs[2] -ne $null) {
        $errorMessage += "`nToo many arguments."
    }

    if ($Inputs[2] -notmatch "^\d*$") {
        $errorMessage += "`nThe third argument, if supplied, must be the listed ID of a website."
    }

    if ($Inputs.Count > 3) {
        $errorMessage += "`nToo many arguments."
    }

    if ($errorMessage -ne "") {
        ExitWithError $errorMessage
    }

    return $true
}

if (ValidateArgs($args)) {
    [string]$grep = ""

    switch ($args[1])
    {
        "-All" { }
        "-Started" { $grep = "Started" }
        "-Stopped" { $grep = "Stopped" }
        "-Restarting" { $grep = "Restarting" }
        "-ById" { $grep = $args[2].ToString() }
    }

    switch ($args[0])
    {
        "-List" {
            if ($grep -eq "") { 
                Get-Website 
            } 
            if ($grep -match "^\d*$") { 
                Get-Website | Where { $_.Id -eq $grep }
            }
            else {
                Get-Website | Where { $_.State -eq $grep }
            }
        }
        "-Start" {
            if ($grep -eq "") {
                foreach ($website in (Get-Website))
                {
                    $website.Start()
                }
            }
            if ($grep -match "^\d*$") {
                foreach ($website in (Get-Website))
                {
                    if ($website.Id -eq $grep) { $website.Start() }
                }
            }
            else {
                foreach ($website in (Get-Website))
                {
                    if ($website.State -eq $grep) { $website.Start() }
                }
            }
        }
        "-Stop" {
            if ($grep -eq "") {
                foreach ($website in (Get-Website))
                {
                    $website.Stop()
                }
            }
            if ($grep -match "^\d*$") {
                foreach ($website in (Get-Website))
                {
                    if ($website.Id -eq $grep) { $website.Stop() }
                }
            }
            else {
                foreach ($website in (Get-Website))
                {
                    if ($website.State -eq $grep) { $website.Start() }
                }
            }
        }
        "-Bounce" {
            if ($grep -eq "") {
                foreach ($website in (Get-Website))
                {
                    $website.Stop()
                    $website.Start()
                }
            }
            if ($grep -match "^\d*$") {
                foreach ($website in (Get-Website))
                {
                    if ($website.Id -eq $grep) { 
                        $website.Stop() 
                        $website.Start()
                    }
                }
            }
            else {
                foreach ($website in (Get-Website))
                {
                    if ($website.State -eq $grep) { 
                        $website.Stop()
                        $website.Start() 
                    }
                }
            }
        }
    }
}
