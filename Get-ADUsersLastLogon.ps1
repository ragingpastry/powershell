function Get-ADUsersLastLogon {
    <#
    .SYNOPSIS
    Get a last login timestamp for a specific user or groups of users.
    .DESCRIPTION
    This function will return a PS object containing a SAM account name and last logon timestamp
    of a user, or group of users.
    .PARAMETER SamAccountName
    The account name to search for. Can be an array
    .Example
    Get-ADUser -Filter * | Select -expand SamAccountName | Get-ADUsersLastLogon -Hours 2000 | sort -Property LastLogonTimeStamp
    #>
    [CmdletBinding()] param(
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string[]]$SamAccountName
    )
    BEGIN {
        $OldUsers = @()
    }

    PROCESS {
        ForEach($name in $SamAccountName) {
            
            $properties = @{
                'SamAccountName' = ''
                'LastLogonTimestamp' = ''
            }

            $obj = New-Object psobject -Property $properties
            $lastLogon = Get-AdObject -Filter "SamAccountName -eq '$name'" -Properties lastLogonTimeStamp | select -expand lastLogonTimeStamp
            Try {
                $daytime = [DateTime]::FromFileTime($lastLogon)
                $obj.SamAccountName = "$name"
                $obj.LastLogonTimeStamp = $daytime
                $OldUsers += $obj
                 
            }
            Catch {
                Write-Verbose "Cannot find last logon for user: $name"
            }
        }
    }
    END {
        return $OldUsers
    }
}
 