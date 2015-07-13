function Get-ADUsersOldLogon {
    <#
    .SYNOPSIS
    Get a last login timestamp for a specific user or groups of users who havn't logged in for X hours.
    .DESCRIPTION
    This function will return a PS object containing a SAM account name and last logon timestamp
    of a user, or group of users. This function accepts 2 parameters. One to specify the SAM account name
    and one to specify the time (in hours).
    .PARAMETER SamAccountName
    The account name to search for. Can be an array
    .PARAMETER Hours
    The number of hours used in the search. Any account that hasn't logged in for X hours will be returned
    .Example
    Get-ADUser -Filter * | Select -expand SamAccountName | Get-ADUsersOldLogon -Hours 2000 | sort -Property LastLogonTimeStamp
    #>
    [CmdletBinding()] param(
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string[]]$SamAccountName = (Get-ADUser -Filter * | select -expand SamAccountName),
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$Hours = '6000'
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
                if(((Get-Date).Subtract($daytime) | Select -expand TotalHours) -gt "$Hours") {
                    $obj.SamAccountName = "$name"
                    $obj.LastLogonTimeStamp = $daytime
                    $OldUsers += $obj
                } 
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
 