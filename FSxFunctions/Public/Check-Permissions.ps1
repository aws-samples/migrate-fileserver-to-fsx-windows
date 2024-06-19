<#
    The function performs the following tasks:
    Installs the necessary RSAT (Remote Server Administration Tools) features.
    Checks if the $ShareRootFolder is null or empty, and exits if it is.
    Exports the current SMB shares to an XML file as a backup.
    Loops through each share folder and checks the NTFS permissions, prompting the user to add the domain administrators group if the local administrators group is found.
    Checks the SMB share permissions and prompts the user to remove the local administrators group and add the domain administrators group if found.
    The function uses the Write-Log function from the Write-Log.ps1 module to log the actions taken during the permission check process.

    Import-Module -Name $PSScriptRoot\Check-Permissions.ps1 -Verbose
    And then you can call the Check-Permissions function like this:
    Check-Permissions -ShareRootFolder $ShareRootFolder -LogLocation $LogLocation -DomainAdminGroup $DomainAdminGroup -LocalAdminGroup $LocalAdminGroup
#>
function Check-Permissions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ShareRootFolder,
        [Parameter(Mandatory = $true)]
        [string]$LogLocation,
        [Parameter(Mandatory = $true)]
        [string]$DomainAdminGroup,
        [Parameter(Mandatory = $true)]
        [string]$LocalAdminGroup
    )

    # Install Prerequisites
    Install-WindowsFeature RSAT-AD-PowerShell, RSAT-ADDS-Tools, RSAT-DNS-Server
    
    . $PSScriptRoot\Write-Log.ps1
    # Check ShareRoot not null
    if ([string]::IsNullOrEmpty($ShareRootFolder)) {
        Write-Log -Level ERROR -Message "No ShareRoot specified, please edit the variables section at the top of the script"
        Write-Output "No ShareRoot specified, please edit the variables section at the top of the script"
        return
    }

    # Output share info to XML as a backup and to recreate shares later
    $shareFolder = Get-SmbShare -Special $false | Where-Object { $_.Name -cnotmatch '^(ADMIN|IPC|PRINT|[A-Z])\$' }
    if (Test-Path -Path "$LogLocation\SmbShares.xml") {
        $now = (Get-Date).ToString("MMddyyhhmm")
        Rename-Item -Path "$LogLocation\SmbShares.xml" -NewName "$now-oldSmbShares.xml"
    }
    $shareFolder | Export-Clixml -Path "$LogLocation\SmbShares.xml"

    # Validates mandatory parameters for null and empty values
    if ($null -eq $shareFolder -or $shareFolder.Count -eq 0) {
        Write-Log -Level ERROR -Message "Mandatory input parameters should not be null or empty."
        return
    }

    # NTFS PERMISSION CHECK: Get ACLs on each share folder and stop if local admin group is found
    foreach ($share in $shareFolder) {
        Write-Output "Checking $($share.Path)"
        Write-Log -Level INFO -Message "Checking $($share.Path)"
        $getAccess = (Get-Acl -Path $share.Path).Access
        if (($getAccess.IdentityReference -contains "BUILTIN\Administrators") -and ($getAccess.IdentityReference -notcontains $DomainAdminGroup)) {
            Write-Host "ERROR: Found local admin group on $($share.Path) please modify permissions to use domain group as local groups will not have access on FSx" -ForeGroundColor Red
            Write-Log -Level ERROR -Message "Found local admin group on $($share.Path) please modify permissions to use domain group as local groups will not have access on FSx"
            Write-Host $getAccess.IdentityReference -ForeGroundColor Green
            Write-Log -Level ERROR -Message $getAccess.IdentityReference

            $fixPermissions = Read-Host -Prompt 'Would you like to ADD NTFS domain group permission? Insert Yes or No?'
            if ($fixPermissions -match "^(?i)y(?:es)?$") {
                $aclPath = "$($share.Path)"
                $identity = $DomainAdminGroup
                $fileSystemRight = "FullControl"
                $propagation = "0"
                $inheritance = "3"
                $ruleType = "Allow"
                try {
                    $acl = Get-Acl -Path $aclPath
                    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $fileSystemRight, $inheritance, $propagation, $ruleType)
                    $acl.SetAccessRule($accessRule)
                    $acl | Set-Acl -Path $aclPath
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    Write-Log -Level ERROR -Message "Set folder permissions error: $errorMsg"
                    Write-Host "Set folder permissions error: $errorMsg" -ForeGroundColor Red
                }
            }
            else {
                Write-Host "Please ensure that you have at least one DOMAIN Group with NTFS permissions added to share folders!" -ForeGroundColor Red
            }
        }
        else {
            Write-Output "Local Admin Group check passed! You can proceed to use AWS DataSync or Robocopy to migrate data to FSx"
            Write-Log -Level INFO -Message "Local Admin Group check passed! You can proceed to use AWS DataSync or Robocopy to migrate data to FSx"
        }

        $sharePermissions = Get-SmbShareAccess -Name $share.Name
        $isAdminGroupPresent = $sharePermissions | Where-Object { $_.AccountName -eq $LocalAdminGroup }

        if ($isAdminGroupPresent) {
            $fixSmbPermissions = Read-Host -Prompt 'Would you like to script to remove local admin permissions and add domain group permission on SMB share? Insert Yes or No?'
            if ($fixSmbPermissions -match "^(?i)y(?:es)?$") {
                Revoke-SmbShareAccess -Name "$($share.Name)" -AccountName $LocalAdminGroup
                Grant-SmbShareAccess -Name "$($share.Name)" -AccountName $DomainAdminGroup -AccessRight Full
                Write-Log -Level INFO -Message "The local administrators group has been replaced with the domain administrators group in the share permissions."
                Write-Output "The $DomainAdminGroup group has been added to the share permissions."
            }
            else {
                Write-Output "Please remove local admin group from SMB permission manually to continue"
                Write-Log -Level ERROR -Message "Please remove local admin group from SMB permission manually to continue"
            }
        }
    }
}
