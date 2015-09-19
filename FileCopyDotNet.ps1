function ExitWithError {
    param ($ErrorMessage) 
    $Host.UI.WriteErrorLine($ErrorMessage)
    $Host.UI.Write("`n`tUsage:`n`n`t.\FileCopyCmdlet.ps1 Source Target`n")
    Exit
}


function Validate {
    param ($InputValues)

    [string]$errorMessage = ""

    if ($InputValues[0] -eq $null -or -not ([System.IO.File]::Exists($InputValues[0])))
    {
        #here we lost the ability to copy multiple files with wildcards.
        $errorMessage = "Sorry, `"" + $InputValues[0] + "`" doesn't seem to exist."
        ExitWithError $errorMessage
    }

    if ($InputValues[1] -eq $null -or -not ([System.IO.Directory]::Exists($InputValues[1])))
    {
        $errorMessage = "Please specify a valid directory as the second argument."
        ExitWithError $errorMessage
    }

    [string]$predictedResult = $InputValues[1] + ([System.IO.Path]::GetFileName($InputValues[0]))

    if ([System.IO.File]::Exists($predictedResult))
    {
        $errorMessage = "The file or files " + $predictedResult + " already exist!"
        ExitWithError $errorMessage
    }

    if ($InputValues[2] -ne $null)
    {
        [string]$errorMessage = "Sorry, `"" + $InputValues[2] + "`" is not a valid argument."
        ExitWithError $errorMessage
    }
}

$Host.UI.Write("`nFileCopyCmdlet created September 18, 2015 by Chaim Eliyah for ShiftWise`n")
Validate $args
#[System.IO.File]::Copy($args[0], $args[1], $false)
$Host.UI.Write("`nExiting without errors.")
