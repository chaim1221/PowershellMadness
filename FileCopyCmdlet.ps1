function ExitWithError {
    param ($ErrorMessage) 
    Write-Error $ErrorMessage
    Write-Host "`n`tUsage:`n`n`t.\FileCopyCmdlet.ps1 Source Target`n"
    Exit
}


function Validate {
    param ($InputValues)

    [string]$errorMessage = ""

    if ($InputValues[0] -eq $null -or -not (Test-Path $InputValues[0])) 
    {
        $errorMessage = "Sorry, `"" + $InputValues[0] + "`" doesn't seem to exist."
        ExitWithError $errorMessage
    }

    if ($InputValues[1] -eq $null -or -not (Test-Path $InputValues[1] -PathType Container))
    {
        $errorMessage = "Please specify a valid directory as the second argument."
        ExitWithError $errorMessage
    }

    [string]$predictedResult = $InputValues[1] + (Split-Path $InputValues[0] -Leaf)
    
    if (Test-Path $predictedResult)
    {
        $errorMessage = "The file or files " + (Split-Path $InputValues[0] -Leaf) + " already exist!"
        ExitWithError $errorMessage
    }

    if ($InputValues[2] -ne $null)
    {
        [string]$errorMessage = "Sorry, `"" + $InputValues[2] + "`" is not a valid argument."
        ExitWithError $errorMessage
    }
}

Write-Host "`nFileCopyCmdlet created September 18, 2015 by Chaim Eliyah for ShiftWise`n"
Validate $args
Copy-Item $args[0] $args[1]
Write-Host "`nExiting without errors."
