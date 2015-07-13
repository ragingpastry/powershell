function New-ReferenceVM {
    <#
    .SYNOPSIS
     Create a reference VM image based on MDT

    .DESCRIPTION
      The New-ReferenceVM function performs an automated deployment of a reference image. The script is 
      extensible in that it can be used to utilize any task sequence that is available on the MDT server
      that is specified. 

    .PARAMETER ComputerName
      The Hyper-V instance to deploy the reference VM on. This can be an ipaddress or a hostname. Accepts arrays

    .PARAMETER VMName
     The name of the VM to create. This is also the name of the previous VM that should be deleted.

    .PARAMETER VMRam
     The amount of RAM to give to the VM. 2GB is the default

    .PARAMETER VMDiskSpace
     The size of the VHDX disk. 60GB is the default

    .PARAMETER VMNetwork
     The virtual switch to connect the VM to. This should have external internet access. The default is "External Switch"

    .PARAMETER ISOPath
     The LiteTouchPE ISO to use for the VM.

    .PARAMETER TaskSequenceID
     The task sequence ID to be used for the automated deployment. 

    .PARAMETER VHDPath
     The path of the virtual hard disk. This is also the path where the script will search for old VHD's. This path must
     exist on the server

    .PARAMETER DeploymentSharePath
     The path of the deployment share. This uses admin shares

    .NOTES
      Version:        1.1
      Author:         Nick Wilburn
      Creation Date:  May-12-2015
      Purpose/Change: Initial script development
  
    .EXAMPLE
      New-ReferenceVM -TaskSequenceID WinServer2012Cap
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)][string[]]$computername = "",
        [Parameter(ValueFromPipeline=$True)][string]$VMName = "Capture01",
        [Parameter(ValueFromPipeline=$True)][int64]$VMRam = 2GB,
        [Parameter(ValueFromPipeline=$True)][uint64]$VMDiskSpace = 60GB,
        [Parameter(ValueFromPipeline=$True)][string]$VMNetwork = "External Switch",
        [Parameter(ValueFromPipeline=$True)][string]$ISOPath = "C:\LiteTouchPE_x64.iso",
        [Parameter(ValueFromPipeline=$True)][string]$VHDPath = "C:\VM\CAPTURE01.VHDX",
        [Parameter(ValueFromPipeline=$True)][string]$DeploymentSharePath = ""
    )
    DynamicParam{
		New-ValidationDynamicParam -Name 'TaskSequenceID' -Mandatory -ValidateSetOptions (([xml](Get-Content \\PTS-MDT\E$\DeploymentShare\Control\TaskSequences.xml)).tss.ts.ID)
	}

    BEGIN {
        ## Create variables for each dynamic parameter.  If this wasn't done you'd have to reference
		## any dynamic parameter as the key in the $PsBoundParameters hashtable.
		$PsBoundParameters.GetEnumerator() | foreach { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    }
    PROCESS {
        $VMSearch = $VMName
        # Remove any existing VM's with name matching in $VMName
        if ($VMSearch -eq $VMName) {
            if ((Get-VM -ComputerName $ComputerName -Name $VMName -ErrorAction SilentlyContinue).State -eq "Running") {
                Send-MailMessage -SmtpServer "smtpgate.email.arizona.edu" -From "blah@email.arizona.edu" -To "now4@email.arizona.edu" -Subject "Reference Image creation previous attempt failed" -Body "Something went wrong with the last reference image capture process. Please connect to CAPTURE01 on LAB01.domain.com and solve any issues."
                exit
            }
            # Run remotely so VHDPath can be used
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {param($VHDPath,$VMName)
                
                Remove-VM -Name $VMName -Force -ErrorAction SilentlyContinue
                if (Test-Path $VHDPath) {
                    Remove-Item $VHDPath -Force
                }

            } -Args $VHDPath,$VMName
        }

       
        Set-TaskSequence -MDTServerName 'mdtservername' -TaskSequenceID $TaskSequenceID -DeploymentSharePath $DeploymentSharePath
        
        # Create a new VM with specified configuration
        ## TODO ##
        # For some reason this has to be done via PSRemoting. When trying to call the New-VM cmdlet, the network adapter being
        # added to the SwitchName parameter is from the local machine, not the machine specified in the ComputerName parameter
        Invoke-Command -ComputerName $ComputerName -ScriptBlock { param($VMName,$VMRam,$VHDPath,$VMDiskSpace,$VMNetwork)
            New-VM -Name $VMName -MemoryStartupBytes $VMRam -NewVHDPath $VHDPath -NewVHDSizeBytes $VMDiskSpace -SwitchName $VMNetwork
        } -Args $VMName,$VMRam,$VHDPath,$VMDiskSpace,$VMNetwork
        
        Set-VMDvdDrive -ComputerName $ComputerName -VMName $VMName -Path $ISOPath
        Start-VM -ComputerName $ComputerName -Name $VMName
        
        # Email receiver@domain.com informing that the reference image creation has begun as scheduled
        Send-MailMessage -SmtpServer "smtpgate.email.arizona.edu" -From "blah@email.arizona.edu" -To "now4@email.arizona.edu" -Subject "Reference Image creation has begun" -Body "Please monitor for an email in about 2-3 hours telling that the reference image creation process has successfully finished."
    }

}

function Set-TaskSequence {
    [CmdletBinding()] 
    param(
        [Parameter(ValueFromPipeline=$True)][string]$MDTServerName = "PTS-MDT.ptsaz.arizona.edu",
        [Parameter(ValueFromPipeline=$True)][string]$TaskSequenceID,
        [Parameter(ValueFromPipeline=$True)][string]$DeploymentSharePath
    )

    # Ensure we are connecting and modifying the right thing.
    Write-Debug "Connecting to $DeploymentSharePath."
    Write-Debug "Modifying $DeploymentSharePath"
    Write-Debug "$(Get-Content $DeploymentSharePath\Control\CustomSettings.ini | ForEach-Object { if ($_ -like "TaskSequenceID=*") { $_ -replace "$_","TaskSequenceID=$TaskSequenceID"} else {Write-Output $_} } )"

    # We write the modified content to a new file first, then move with the -Force flag to overwrite the old file.
    # Windows filelocking seems to get in the way if we try to Get-Content | Set-Content on the same file
    Get-Content $DeploymentSharePath\Control\CustomSettings.ini | ForEach-Object { if ($_ -like "TaskSequenceID=*") { $_ -replace "$_","TaskSequenceID=$TaskSequenceID"} else {Write-Output $_} } | Set-Content $DeploymentSharePath\Control\CustomSettings.ini.tmp
    Move-Item -Force $DeploymentSharePath\Control\CustomSettings.ini.tmp $DeploymentSharePath\Control\CustomSettings.ini
    
    ## Update the deployment share after we are done. We first check if the MDTProvider PSProvider is already mounted
    ## TODO
    # If PSProvider is already mounted the script should find the mount name, and use that instead of DS:
    $PSProviders = Invoke-Command -ComputerName $MDTServerName -ScriptBlock { Get-PSDrive | Select -expand Provider | Select -expand Name -ErrorAction SilentlyContinue}
    if ($PSProviders -contains "MDTProvider") {
        Invoke-Command -ComputerName $MDTServerName -ScriptBlock { param($DeploymentSharePath) 
            Update-MDTDeploymentShare -Path DS:
        } -args $DeploymentSharePath
    }
    else {
        Invoke-Command -ComputerName $MDTServerName -ScriptBlock { param($DeploymentSharePath) 
            Import-Module 'C:\Program Files\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1' 
            New-PSDrive -Name DS -PSProvider mdtprovider -Root $DeploymentSharePath
            if ($? -eq $True) {
            Write-Output $DeploymentSharePath
                Update-MDTDeploymentShare -Path DS:
            } 
        } -args $DeploymentSharePath
    }
}

function New-ValidationDynamicParam {
	[CmdletBinding()]
	[OutputType('System.Management.Automation.RuntimeDefinedParameter')]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory)]
		[array]$ValidateSetOptions,
		[switch]$Mandatory,
		[string]$ParameterSetName = '__AllParameterSets',
		[switch]$ValueFromPipeline,
		[switch]$ValueFromPipelineByPropertyName
	)
	
	$AttribColl = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
	$ParamAttrib = New-Object System.Management.Automation.ParameterAttribute
	$ParamAttrib.Mandatory = $Mandatory.IsPresent
	$ParamAttrib.ParameterSetName = $ParameterSetName
	$ParamAttrib.ValueFromPipeline = $ValueFromPipeline.IsPresent
	$ParamAttrib.ValueFromPipelineByPropertyName = $ValueFromPipelineByPropertyName.IsPresent
	$AttribColl.Add($ParamAttrib)
	$AttribColl.Add((New-Object System.Management.Automation.ValidateSetAttribute($ValidateSetOptions)))
	$RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter($Name, [string], $AttribColl)
	$RuntimeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
	$RuntimeParamDic.Add($Name, $RuntimeParam)
	$RuntimeParamDic
}
