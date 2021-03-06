<#
.SYNOPSIS
	This script is for launching ShiftWise deployments from TeamCity.
 
.DESCRIPTION
	This script is for launching ShiftWise deployments from 
	TeamCity. It has a few required parameters. Pertinent 
	information is gathered from the SW Dev Tools Configuration 
	Management Data File and the TFS server.
	
	-Product = Name of the Product to deploy.
	-Server = Name of the server to deploy to.
	-BuildDefinition = Name of the Team Build Build Definition to query for Build Packages.

.EXAMPLE
	TeamCity-Wrapper.ps1 -Product ESP -Server PROD-VM-DEV04

.NOTES
	More information on the SW Dev Tools can be found at:  http://wiki/Engineering.SW-Dev-Tools.ashx
#>

# todo: more elegant "throw" statement for Server
Param( 	[System.String]$Product = $(throw 'Product name is required. This should be the name of the TeamCity configuration.'),
        [System.String]$Server = $(throw 'Server name is required. Use the Web server name only.')
)

# Get the SW Dev Tools Encryption Password (if not already entered)
Write-Smart $('Validating DevTools PW') 'Highlight'
if (Check-LocalEncryptionPasswordFile)
{
	$EncryptionPassword = $ENV:EncryptionPW
	Validate-EncryptionPassword -TestPassword $EncryptionPassword
} else {
	throw ('Cannot verify the DevTools encryption password.')
}

# Get the target application server to deploy to 
# There is no purpose in getting the objects, they're not used...
Write-Smart $('Getting server information') 'Highlight'
if( $CM_Data.Servers.Name -contains $Server )
{
    $CM_WebServer = [Origin.CM.CoreObjects.Library]::GetSWServer( $CM_Data, $Server )
    $SQLServer = $Server -replace 'WEB', 'SQL'
} else {
    throw ('Server name is not valid.')
}
if ( -not $CM_Data.Servers.Name.ToLower() -contains $SQLServer.ToLower() )
{
    throw ('SQL Server name not found in list.')
} else {
    $CM_SQLServer = [Origin.CM.CoreObjects.Library]::GetSWServer( $CM_Data, $SQLServer )
}

# Validate product to deploy
Write-Smart $('Getting product information.')
$CMDataHasNoSuchProduct = -not $CM_Data.Products.Name -contains $Product
$ProductDoesNotApply = -not [Origin.CM.CoreObjects.Library]::ProductAppliesToServer( $CM_Data, $Server, $Product )
$ProductIsNotAssociated = -not [Origin.CM.CoreObjects.Library]::IsProductAssociatedWithServer( $CM_Data, $Server, $Product )
if ( $CMDataHasNoSuchProduct -or $ProductDoesNotApply -or $ProductIsNotAssociated )
{
    throw ("Cannot deploy $Product to $Server")
}

# Start package
Write-Smart $('TeamCity Deployment Wrapper') 'Title'
$DateTimeLog = (Get-Date -Format s) -replace ':', '.'
$LogFile = "C:\SW_Internal\SWDevTools\Deployments\$Product\TeamCity-Wrapper for " + $Product + ' to ' + $Server + ' - ' + $DateTimeLog + '.html'

# LogFile
Write-Smart $("Logging to $LogFile") 'Highlight'
$Ignore = Use-HTMLLogFile -LogFilename $LogFile

# Determine build definition
$BuildDefinition = 'Local Build'
Write-Smart $('Using Build Definition: ' + $BuildDefinition) 'Highlight'
$SourceLocation = $pwd.Path
Write-Smart $("Using local build definition from $SourceLocation") 'Highlight'

# Determine if/how Test Seeding Script Deployment Occur
$TestSeedingScriptPath = Join-Path -Path $SourceLocation -ChildPath 'SeedScript-Test.sql'
$TestSeedingScriptExists = Test-Path( $TestSeedingScript )
if( -not $DeployTestSeedingScript -and $TestSeedingScriptExists )
{
    Write-Smart $("Test Seeding Script found for $Product, but you specified it should not be deployed.") 'Warning'
}


# Set DacPac variables; Warn if DacPacs exist but won't be deployed

# we don't really need these variables, they default to the following values.
$DeployDacPacs = $true
$DeployTestSeedingScript = $true
$DeployGlobalSQLScripts = $true
$BlockOnPossibleDataLoss = $true
$CreateNewDatabase = $false
$GenerateSmartDefaults = $false
# end we don't really need

# Determine if/how Global SQL Script Deployment Occur
if( -not $DeployGlobalSQLScripts )
{
    Write-Smart $('As specified, Global SQL Scripts will NOT be deployed.') 'Warning'
}

# first expression always evaluates to false
if ( -not $DeployDacPacs -and ($CM_Data.Databases | Where-Object ProductReference -eq $Product).DacPacs.Count -ge 1)
{
    Write-Smart ("DacPacs exist for $Product, but you specified that they should not be deployed.") 'Warning'
}

$CleanupDacPac = $false
$DacPacTestPath = Join-Path -Path $SourceLocation -ChildPath 'ShiftWise.Login.Database\bin\Debug\ShiftWise.Login.Database.dacpac'
Write-Smart $("Attempting to copy $DacPacTestPath to $SourceLocation.") 'Highlight'
if (Test-Path $DacPacTestPath)
{
    Copy-Item $DacPacTestPath $SourceLocation -Force
    $CleanupDacPac = $true
    Write-Smart $('Success!') 'Success'
}

# hack in the TFS folder structure
Write-Smart $('Hacking together the folder structure expected by Deploy-SWProduct.ps1') 'Highlight'

#### Only preparing services for now
if (Test-Path -Path "$SourceLocation\$Product.Services")
{
	$componentSourcePath = "$SourceLocation\_PublishedWebSites\$Product.Services"
	if (Test-Path -Path $componentSourcePath){ Remove-Item "$componentSourcePath\*"	}
	else { mkdir $componentSourcePath }
	
	Copy-Item "$SourceLocation\$Product.Services\bin" $componentSourcePath -Recurse
	Copy-Item -Path "$SourceLocation\$Product.Services\*" -Include '*.asax','*.config'  -Destination $componentSourcePath -Recurse
}

# Start deployment
Write-Smart $('Executing Deploy-SWProduct.ps1') 'Highlight'
$PS1_Deploy_SWProduct_Base = Join-Path -Path "$ENV:SWDevTools_Bin" -ChildPath '\Deploy-SWProduct.ps1'
$ForcePastErrors = $true

Write-Smart $("$PS1_Deploy_SWProduct_Base -Product $Product -DestinationServer $Server -SourceLocation $SourceLocation -DestinationSQLServer $SQLServer -DeployDacPacs $DeployDacPacs -DeployTestSeedingScript $DeployTestSeedingScript -EncryptionPassword ******* -BlockOnPossibleDataLoss $BlockOnPossibleDataLoss -CreateNewDatabase $CreateNewDatabase -GenerateSmartDefaults $GenerateSmartDefaults -ForcePastErrors $ForcePastErrors") 'Normal'

& $PS1_Deploy_SWProduct_Base -Product $Product -DestinationServer $Server -SourceLocation $SourceLocation -DestinationSQLServer $SQLServer -DeployDacPacs $DeployDacPacs -DeployTestSeedingScript $DeployTestSeedingScript -DeployGlobalSQLScripts $DeployGlobalSQLScripts -EncryptionPassword $ENV:EncryptionPW -BlockOnPossibleDataLoss $BlockOnPossibleDataLoss -CreateNewDatabase $CreateNewDatabase -GenerateSmartDefaults $GenerateSmartDefaults -ForcePastErrors $ForcePastErrors 

# Fini
if ($CleanupDacPac) { 
    Write-Smart $('Cleaning up from DacPac deploy...') 'Highlight'
    $CleanupPath = Join-Path -Path $SourceLocation -ChildPath 'ShiftWise.Login.Database.dacpac'
    Remove-Item $CleanupPath
}

$PrimaryVCacNumber = $Server.Split('-')[2]
Write-Smart $("Setting environment variable PrimaryVCacNumber set to $PrimaryVCacNumber") 'Highlight'
setx.exe PrimaryVCacNumber $PrimaryVCacNumber
# And, because PowerShell is dumb:
$ENV:PrimaryVCacNumber=$PrimaryVCacNumber

Write-Smart 'TeamCity-Wrapper.ps1 has completed deployment.' 'Success'
$Ignore = Close-HTMLLogFile -LogFilename $LogFile
