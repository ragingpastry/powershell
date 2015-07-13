function Remove-LocalAdministrator {
    
    $accounts = @("Administrator")
    ForEach($user in $accounts) {
        try {
            Write-Verbose "Attempting to connect to $computer"
            $account = [ADSI]("WinNT://./$user,user")
            if (!($account.name)) {
                Write-Verbose "Unable to connect to $_ with ADSI. Do we have privileges?"
                exit
            }
            Write-Verbose "Setting userFlag 0x2 on Administrator account"
            $account.invokeSet("userFlags",$account.userFlags[0] -BOR 2)
            $account.commitChanges()
            Write-Verbose "$user account disabled"
        }
        catch {
            Write-Verbose "Unable to remove local Administrator account. $_"
            break
        }
    }
       
}

Remove-LocalAdministrator