function Activate-Office {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)][string]$OfficeVersion = "2013"
    )

    $ActivationKeyTable = @{
        "2013"     = ""
        "2010"     = ""
    }

    try {
        if ($ActivationKeyTable.ContainsKey($OfficeVersion)) {
            if ($OfficeVersion -eq "2013") {
                cscript.exe 'C:\Program Files (x86)\Microsoft Office\Office15\OSPP.VBS' /inpkey:$ActivationKeyTable.2013
                cscript.exe 'C:\Program Files (x86)\Microsoft Office\Office15\OSPP.VBS' /act
            }
            elseif ($OfficeVersion -eq "2010") {
                cscript.exe 'C:\Program Files (x86)\Microsoft Office\Office14\OSPP.VBS' /inpkey:$ActivationKeyTable.2010
                cscript.exe 'C:\Program Files (x86)\Microsoft Office\Office14\OSPP.VBS' /act
            }
            else {
                Write-Error "No OfficeVersion found in ActivationKeyTable"
                exit
            }
        }
    }
    catch {
        Write-Error $_
    }
}
        
