<#
The script is designed to check the NTFS and SMB share permissions on the source file server.
It first installs the necessary RSAT (Remote Server Administration Tools) features.
It defines a Write-Log function to log messages to a log file.
The script checks if the $ShareRootFolder variable is set and exits with an error message if it's not.
It exports the current SMB shares to an XML file as a backup.
The script then loops through each share folder and checks the NTFS permissions. 
If the local administrators group is found, it prompts the user to add the domain administrators group with full control permissions.
It also checks the SMB share permissions and prompts the user to remove the local administrators group and add the domain administrators group if found.
The script provides clear and informative error messages and logs the actions taken.
#>
#########################################################################
# CHECK LOCAL FOLDER PERMISSIONS ON SOURCE FILE SERVER
#########################################################################
# Install Prerequisites
Install-WindowsFeature RSAT-AD-PowerShell,RSAT-ADDS-Tools,RSAT-DNS-Server
## Log function to write to log file
Function Write-Log {
  [CmdletBinding()]
  Param(
  [Parameter(Mandatory=$False)]
  [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
  [String]
  $Level = "INFO",
  [Parameter(Mandatory=$True)]
  [string]
  $Message,
  [Parameter(Mandatory=$False)]
  [string]
  $Logfile
  )
  $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
  $Line = "$Stamp $Level $Message"
  $Logfilepath = "$LogLocation\FsxMigrate.log"
  if (!(Test-path $Logfilepath)){
    New-Item $Logfilepath
  }
  If($Logfilepath) {
      Add-Content $Logfilepath -Value $Line
  }
  Else {
      Write-Output $Line
  }

}
# Check ShareRoot not null
if ($null -eq $ShareRootFolder -or "" -eq $ShareRootFolder ){
    Write-Log -Level ERROR -Message "No ShareRoot specified, please edit the variables section at the top of the script"
    Write-Output "No ShareRoot specified, please edit the variables section at the top of the script"
    exit 1
}

# Output share info to XML as a backup and to recreate shares later
$ShareFolder= Get-SmbShare -Special $false | ? {$_.Name -cnotmatch '^(ADMIN|IPC|PRINT|[A-Z])\$' }
if (Test-path $LogLocation\SmbShares.xml){
    $Now = (Get-Date).ToString("MMddyyhhmmss")
    Rename-Item -Path $LogLocation\SmbShares.xml -NewName $Now-oldSmbShares.xml
    
}
$ShareFolder| Export-Clixml -Path $LogLocation\SmbShares.xml

# Validates mandatory parameters for null and empty values
if ( ($ShareFolder -eq $null) -or ($ShareFolder.Count -eq 0) ){
    Write-Log -Level ERROR -Message "Mandatory input parameters should not be null or empty."
    exit 1
}

# NTFS PERMISSION CHECK: Get ACLs on each share folder and stop if local admin group is found
foreach ($share in $ShareFolder)
{
    Write-Output "Checking $($share.Path)"
    Write-Log -Level INFO -Message "Checking $($share.Path)"
    # Get the current folder NTFS permissions
    $GetAccess = (Get-ACL -Path $share.path).Access
    # Check if local administrators group exists on folder permissions
    if ( ($GetAccess.IdentityReference -contains "BUILTIN\Administrators") -and ($GetAccess.IdentityReference -notcontains "$DomainAdminGroup") )
    {
        Write-Host "ERROR: Found local admin group on $($share.Path) please modify permissions to use domain group as local groups will not have access on FSx" -ForeGroundColor Red
        Write-Log -Level ERROR -Message "Found local admin group on $($share.Path) please modify permissions to use domain group as local groups will not have access on FSx"
        Write-Host $($GetAccess.IdentityReference) -ForeGroundColor Green
        Write-Log -Level ERROR -Message "$($GetAccess.IdentityReference)"
        # Ask customer if they would like to add the correct NTFS permissions to the folder.
        $FixPermissions = Read-Host -Prompt 'Would you like to ADD NTFS domain group permission? Insert Yes or No?'
        if ($FixPermissions -cmatch "^(?i)y(?:es)?$") 
        {
            $ACLPath = "$($share.Path)"
            $Identity = "$DomainAdminGroup"
            $FileSystemRight = "FullControl"
            $Propagation = "0" # 0 None Specifies that no inheritance flags are set.
            $inheritance = "3" # 3 The ACE is inherited by child container objects.
            $RuleType = "Allow"
            Try {
                $ACL = Get-Acl -Path $ACLPath
                $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity,$FileSystemRight,$inheritance,$Propagation,$RuleType)
                $ACL.SetAccessRule($AccessRule)
                $ACL | Set-Acl -Path $ACLPath
            }
            Catch {
                $ErrorMsg = $_.Exception.Message
                Write-Log -Level ERROR -Message "Set folder permissions error: $ErrorMsg"
                Write-Host "Set folder permissions error: $ErrorMsg" -ForeGroundColor Red
            }
        }
        else
        {
            Write-Host "Please ensure that you have at least one DOMAIN Group with NTFS permissions added to share folders!" -ForeGroundColor Red
        } 

    }else
    {
        Write-Output "Local Admin Group check passed! You can proceed to use AWS DataSync or Robocopy to migrate data to FSx"
        Write-Log -Level INFO -Message "Local Admin Group check passed! You can proceed to use AWS DataSync or Robocopy to migrate data to FSx"
    }
    # Get the current share permissions
    $SharePermissions = (Get-SmbShareAccess -Name $share.Name)

    # SHARE PERMISSION CHECK - is the local administrators group on the share
    $IsAdminGroupPresent = $SharePermissions | Where-Object { $_.AccountName -eq "$LocalAdminGroup" }

    if ($IsAdminGroupPresent) 
    {
        # Ask customer if they would like to add the correct SMB share permissions to the folder.
        $FixSMBPermissions = Read-Host -Prompt 'Would you like to script to remove local admin permissions and add domain group permission on SMB share? Insert Yes or No?'
        if ($FixSMBPermissions -cmatch "^(?i)y(?:es)?$")
        {
            # Remove the local administrators group from the share permissions
            Revoke-SmbShareAccess -Name "$($share.Name)" -AccountName "$LocalAdminGroup"

            # Add the domain administrators group to the share permissions
            Grant-SmbShareAccess -Name "$($share.Name)" -AccountName $DomainAdminGroup -AccessRight Full
            
            # Write to log
            Write-Log -Level INFO -Message "The local administrators group has been replaced with the domain administrators group in the share permissions."
            Write-Output "The $($DomainAdminGroup) group has been added to the share permissions."
        }
        else
        {
            Write-Output "Please remove local admin group from SMB permission manually to continue"
            Write-Log -Level ERROR -Message "Please remove local admin group from SMB permission manually to continue"
        }
    
    } 

}
