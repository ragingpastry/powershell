function Activate-Windows {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)][string]$OperatingSystem = "Windows7"
    )

    $ActivationKeyTable = @{
        "windows7"     = ""
        "windows8.1"   = ""
        "server2012R2" = ""
        "server2008R2" = ""
        "server2012"   = ""
    }

    try {
        if ($ActivationKeyTable.ContainsKey($OperatingSystem.ToLower())) {
            cscript.exe 'C:\Windows\System32\slmgr.vbs' /ipk $ActivationKeyTable.($OperatingSystem.ToLower())
            cscript.exe 'C:\Windows\System32\slmgr.vbs' /ato
        }
        else {
            Write-Error "No operating found in KeyTable"
        }
    }
    catch {
        Write-Error $_
    }
}