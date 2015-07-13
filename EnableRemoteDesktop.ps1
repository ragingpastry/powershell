$cred = Get-Credential -Username ptsaz\Administrator -Message "Admin Password"
ForEach($computer in $(Get-ADComputer -Filter 'Name -like "PTS-*"' -SearchBase "DC=ptsaz,DC=arizona,DC=edu" | Select -expand Name)) {
    $RDP = Get-WmiObject -Class Win32_TerminalServiceSetting `
            -Namespace root\CIMV2\TerminalServices `
            -Computer $Computer `
            -Authentication 6 `
            -ErrorAction Continue `
            -Credential $cred
    $result = $RDP.SetAllowTsConnections(1,1)
    if($result.ReturnValue -eq 0) {
    Write-Host "$Computer : Enabled RDP Successfully"
    "$Computer : RDP Enabled Successfully"
    }  
    else {
    Write-Host "$Computer : Failed to enabled RDP"
    "$Computer : Failed to enable RDP"
    }
}