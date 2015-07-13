## This script will install IE 10 on all computers within the specified OU
## Usage:
## .\installIE10.ps1 -ou "OU=BUSO Business Office Computers,OU=PTS Building,OU=PTSAZ_Computers,DC=ptsaz,DC=arizona,DC=edu"
## This will install IE10 on all computers in the Business Office. 

## Change this to change the logfile


function Write-Log {
    Param(
        [String] $logstring
    )

    $timestamp = Get-Date -Format yyy-MM-dd[HH:mm:ss]
    Add-Content $logfile -value "$timestamp - $logstring"
}


function Install-Software {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,
        ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string[]]$computer = 'localhost',
        [System.Management.Automation.PSCredential]$cred,
        [Parameter(Mandatory=$True)][string]$softwarePath,
        [string]$msiArgs = '/quiet /update-no /norestart'

    )
    
    $scripblock = { 
        
        $softwareName = "$($softwarePath.split('\')[-1])"
        $user = $env:username
        $LogFile = "C:\Users\$user\$softwareName.log"




        Write-Log("Installing $softwareName on $($computer)")
        Write-Host("Installing $softwareName on $($computer)")
        
        if( $(Test-Path "\\$computer\C$\$softwareName") -eq $false) {
            Copy-Item "$softwarePath" -Destination "\\$computer\C$\$softwareName"

        }

        Invoke-Command -computername $computer -Credential $cred -scriptblock{param($computer,$softwareName)([WMICLASS]"\\$computer\ROOT\CIMV2:win32_process").Create("msiexec /L*v C:\$softwareName.log /qn /i C:\$softwareName")} -Argumentlist $computer,$softwareName > C:\Users\$user\tmperr.txt 2>&1
        
        $err = Get-Content "C:\Users\$user\tmperr.txt"
        if (Select-String -Path "C:\Users\$user\tmperr.txt" -Pattern "(^[R])*([0]$)") {
            Write-Log("Received ReturnValue 0. We were most likely successful in installing $softwareName into $($computer)")
            Write-Host("Received ReturnValue 0. We were most likely successful in installing $softwareName into $($computer)")
        }
        else {
            Write-Host("Error logging onto $($computer). Please check the logs.") -foregroundcolor red -backgroundcolor black
            Write-Log($err)
        }

        if($(Test-Path C:\Users\$user\tmperr.txt) -eq $true) {
            Remove-Item "C:\Users\$user\tmperr.txt"
        }
    }

    Invoke-Parallel -InputObject $computer  -ScriptBlock $scriptBlock
}
