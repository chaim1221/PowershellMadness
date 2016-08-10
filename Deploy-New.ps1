param (
    [Parameter(Mandatory=$true)][System.String]$buildDefinition,
                                [System.String]$usingBuildPackage = 'Latest',
    [Parameter(Mandatory=$true)][System.String]$toServer
)

# insecure way of storing decryption password
# inherited from legacy system
function get-password {
    if ([System.IO.File]::Exists('C:\IT\scripts\vCAC\DevOps\SWDevTools.txt')) {
        return $(get-content C:\IT\scripts\vCAC\DevOps\SWDevTools.txt)
    } elseif($ENV:EncryptionPW -ne $null) {
        return $ENV:EncryptionPW 
    } else {
        $Password = read-host 'Please enter the DevOps encryption password' -AsSecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    }
}

function parse-buildPackage {
    $parentPath = join-path -Path '\\pv-tfs\B' -ChildPath $buildDefinition
    $choices = $(Get-ChildItem $parentPath | Select-Object LastWriteTime, Name, FullName, Id | sort-object LastWriteTime)
    
    for ([System.Int16]$i = 0; $i -lt $choices.Count; $i++) {
        $choices[$i].Id = $i + 1
    }
    
    if ($usingBuildPackage -eq 'Latest') { 
        return $($choices | Select-Object -Last 1).FullName
    } else {
        return $($choices | Where-Object Name -match $usingBuildPackage | Select-Object -Last 1).FullName
    }
}

function get-servicepath  {
   param
   (
     [System.IO.DirectoryInfo]
     $application
   )

    if ($application.Name.ToLower() -match 'service') {
        $productName = $buildDefinition.split('.')[1].ToLower()
        return "\\$toServer\SW_Websites\api.shiftwise.net\$productName"
    } elseif ($application.Name.ToLower() -match 'monitor') {
        $productName = $($buildDefinition.split('-')[1]).trim() -replace 'Backend','Monitor'
        return "\\$toServer\SW_Services\$productName"
    } else {
        throw "I don't know how to do what you're asking (parsing servicePath)."
    }
}

function deploy-service  {
   param
   (
     [System.IO.DirectoryInfo]
     $application,

     [System.String]
     $servicePath
   )

    write-host "`r`nDeploying" $application.Name "to $toServer" -f White
    write-host "Checking $servicePath exists..."

    if ([System.IO.Directory]::Exists($servicePath)) {
        $backupPath = "\\$toServer\SW_Backups\$buildDefinition"
        write-host "Backing up files to $backupPath..." -f White 
        Copy-Item "$servicePath\*" $backupPath -Force
        write-host '...it does!' -f Green
        clean-filesAndDirectory $application $servicePath
    } else {
        [System.IO.Directory]::CreateDirectory($servicePath)
        write-host '...it does now!' -f Green
    }
    
    write-host "Copying files to $servicePath ..."
    copy-filesRecursive $application $servicePath

    write-host '...done!' -f Green 
}

function transform-configFile  {
   param
   (
     [System.IO.DirectoryInfo]
     $application,

     [System.String]
     $servicePath,

     [System.String]
     $pass
   )

    write-host "`r`nTransforming config files in $servicePath ..." -f Green
    $sqlServer = $($toServer.toLower() -replace 'web','sql').ToUpper()
    & \\prod-vm-tools\Dev_Tools\configuration\ConfigFileTransformer.Console.exe -s $toServer -q $sqlServer -d $servicePath -z $pass | out-null
    write-host '...done!' -f Green
}

function stop-monitorService 
{
   param
   (
     [System.String]
     $filename
   )

    $whoAreYou = $($buildDefinition.split('-')[1]).trim() -replace 'Backend','Monitor'
    write-host "Could not clean $filename`: Attempting to stop " $whoAreYou -f Yellow
    $mostLikelyGuiltyParty = get-wmiObject Win32_Process -ComputerName $toServer | Where-Object{$_.ProcessName -match $whoAreYou}
    $mostLikelyGuiltyParty.Terminate()
    start-sleep -m 800
    Remove-Item -Force $filename
    write-host "File $filename successfully removed, moving on." -f Green
}

#ref $CM_Data
function start-myService  {
   param
   (
     [System.IO.DirectoryInfo]
     $application,

     [System.String]
     $servicePath,

     [System.String]
     $pass
   )

    if ($application.Name.ToLower() -match 'monitor') {
        $serviceName = $($($buildDefinition.split('-')[1]).trim() -replace 'Backend','Monitor')
        $serverGroup = $CM_Data.Servers | Where-Object Name -eq $toServer | %{ $_.ServerGroup }
        $serviceUsername = $CM_Data.Services | Where-Object ServiceName -match Login | % { $_.ServiceStatus } | Where-Object ServerGroup -eq $serverGroup | % { $_.CredentialReference }
        $servicePasswordHash = $([Origin.CM.CoreObjects.Library]::GetCredentials($CM_Data, $serviceUsername)).Password
        $servicePassword = [Origin.CM.Common.Crypto]::Decrypt($servicePasswordHash, $pass)
        $serviceUsername = 'SW\' + $serviceUsername
        $exec = $serviceName + '.exe'
        $pathToExec = join-path -Path $servicePath -ChildPath $exec
        & $pathToExec uninstall
        & $pathToExec install -username:$serviceUsername -password:$servicePassword start
    }
}

function clean-filesAndDirectory 
{
   param
   (
     [System.IO.DirectoryInfo]
     $application,

     [System.String]
     $servicePath
   )

    write-host "Cleaning $servicePath..." -f White
    $allFilesInPath = Get-ChildItem $servicePath -Recurse | Where-Object { ! $_.PSIsContainer } | foreach { $_.FullName }
    foreach ($filename in $allFilesInPath)
    {
        try {
            Remove-Item -Force $filename -ErrorAction Stop
        } catch [System.UnauthorizedAccessException] {
            stop-monitorService $filename
        } catch [System.IO.IOException] {
            stop-monitorService $filename
        }
    }

    if ([System.IO.Directory]::Exists($servicePath)) {
        Remove-Item -Recurse -Force $servicePath
        write-host "Directory $servicePath and all children successfully removed." -f Green
    } else {
        write-host "That's weird. Directory $servicePath does not exist." -f Yellow
    }
    New-Item -Path $servicePath -type Directory -Force

    write-host "Folder successfully cleaned and recreated.`r`n" -f Green
}

function copy-filesRecursive 
{
   param
   (
     [System.IO.DirectoryInfo]
     $applicationDir,

     [System.String]
     $servicePath
   )

    $applicationContents = Get-ChildItem $applicationDir.FullName | foreach { 
        if ( $_.PSIsContainer ) {
            $childPath = join-path -Path $servicePath -ChildPath $_.Name
            mkdir $childPath
            copy-filesRecursive $_ $childPath
        } else {
            Copy-Item $_.FullName $servicePath -Force
        }
    }
}

write-host "`r`nYE NEW DEPLOY TOOL...`r`n" -f Green

$opsPass = get-password

$buildPackageToUse = parse-buildPackage
$toServer = if ($toServer -eq 'localhost') { $ENV:COMPUTERNAME } else { $toServer }

write-host 'Deploying the following...' -f White
write-host 'Build Definition:    ' -f Gray -NoNewLine; write-host $buildDefinition -f Cyan
write-host 'Using Build Package: ' -f Gray -NoNewLine; write-host $buildPackageToUse -f Cyan
write-host 'To Server:           ' -f Gray -NoNewLine; write-host $toServer -f Cyan

if ($buildDefinition.ToLower() -match 'backend') {
    write-host "...as a backend service.`r`n" -f White

    $allApplications = Get-ChildItem $buildPackageToUse

    write-host 'The service contains the following components:' -f White
    % -inputObject $allApplications -process {
        write-host '  -' $_.Name -f Cyan
    }

    % -inputObject $allApplications -process {
        $servicePath = get-servicepath($_)
        deploy-service $_ $servicePath
        transform-configFile $_ $servicePath $opsPass
        start-myService $_ $servicePath $opsPass
    }
} elseif ($buildDefinition.ToLower() -match 'website') {
    write-host '...as a website.' -f White
    throw 'Wait just kidding I have no idea how to do that!'
} else {
    throw "I'm sorry, Dave, but I'm afraid I can't do that (Could not parse build definition)."
}

write-host ''
foreach ($line in $(get-content '\\prod-vm-tools\Dev_Tools\bin\ASCII\Success-New.txt')) { write-host $line -f Green }
Pause-Seconds -inSeconds 5 -inShow $false
Stop-Process $PID
