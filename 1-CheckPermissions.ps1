#########################################################################
# CHECK LOCAL FOLDER PERMISSIONS ON SOURCE FILE SERVER
#########################################################################
# If no shares found on source server exit out.
$ShareFolder = Get-SmbShare -Special $false | Where-Object { $_.Name -cnotmatch '^(ADMIN|IPC|PRINT|[A-Z])\$' }
if (($ShareFolder -eq $null) -or ($ShareFolder.Count -eq 0)) {
    Write-Log -Level ERROR -Message "The system found 0 shares on source file server, mandatory ShareFolder parameter should not be null or empty."
    exit 1
}

# Check ShareRoot for null or white space and exit if true
if ([string]::IsNullOrWhiteSpace($ShareRootFolder)) {
    Write-Log -Level ERROR -Message "No Source ShareRoot folder specified, please run MigrationParameters.ps1 again"
    Write-Output "No Source ShareRoot folder specified, please run MigrationParameters.ps1 again"
    exit 1
}

# Install AD module for PowerShell and DNS as per the prerequisites
$RSAT = Get-WindowsFeature -Name RSAT-AD-PowerShell, RSAT-ADDS-Tools, RSAT-DNS-Server
if (-not $RSAT.Installed) {
    Install-WindowsFeature RSAT-AD-PowerShell, RSAT-ADDS-Tools, RSAT-DNS-Server
}

# Output share info to XML as a backup and to recreate shares later
if (Test-Path $LogLocation\SmbShares.xml) {
    $Now = (Get-Date).ToString("MMddyyhhmmss")
    Rename-Item -Path $LogLocation\SmbShares.xml -NewName "$Now-oldSmbShares.xml"
}

# Export source file server shares to XML
try {
    $ShareFolder | Export-Clixml -Path $LogLocation\SmbShares.xml
}
catch {
    Write-Log -Level ERROR -Message "Error exporting SMB shares to XML: $($_.Exception.Message)"
    Write-Output "Error exporting SMB shares to XML: $($_.Exception.Message)"
    exit 1
}


# NTFS PERMISSION CHECK: Get ACLs on each share folder and stop if local admin group is found
foreach ($share in $ShareFolder) {
    Write-Output "Checking $($share.Path)"
    Write-Log -Level INFO -Message "Checking $($share.Path)"
    # Get the current folder NTFS permissions
    $GetAccess = (Get-ACL -Path $share.path).Access
    # Check if local administrators group exists on folder permissions
    if ($GetAccess.IdentityReference -contains "BUILTIN\Administrators") {
        # Check if DomainAdminGroup also exists
        if ($GetAccess.IdentityReference -contains "$NetBIOS\$DomainAdminGroup") {
            Write-Output "Local Admin Group and $DomainAdminGroup both found on $($share.Path). No need to modify permissions."
            Write-Log -Level INFO -Message "Local Admin Group and $DomainAdminGroup both found on $($share.Path). No need to modify permissions."
        }
        else {
            Write-Host "ERROR: Found local admin group on $($share.Path) please modify permissions to use domain group as local groups will not have access on FSx" -ForeGroundColor Red
            Write-Log -Level ERROR -Message "Found local admin group on $($share.Path) please modify permissions to use domain group as local groups will not have access on FSx"
            Write-Host $($GetAccess.IdentityReference) -ForeGroundColor Green
            Write-Log -Level ERROR -Message "$($GetAccess.IdentityReference)"
            # Ask customer if they would like to add the correct NTFS permissions to the folder.
            $FixPermissions = Read-Host -Prompt 'Would you like to ADD NTFS domain group permission? Insert Yes or No?'
            if ($FixPermissions -cmatch "^(?i)y(?:es)?$") {
                $ACLPath = "$($share.Path)"
                $Identity = $DomainAdminGroup
                $FileSystemRight = "FullControl"
                $Propagation = "0" # 0 None Specifies that no inheritance flags are set.
                $inheritance = "3" # 3 The ACE is inherited by child container objects.
                $RuleType = "Allow"
                Try {
                    $ACL = Get-Acl -Path $ACLPath
                    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $FileSystemRight, $inheritance, $Propagation, $RuleType)
                    $ACL.SetAccessRule($AccessRule)
                    $ACL | Set-Acl -Path $ACLPath
                    Write-Host "The domain group $DomainAdminGroup has been added to $ACLPath" -ForegroundColor Green
                }
                Catch {
                    $ErrorMsg = $_.Exception.Message
                    Write-Log -Level ERROR -Message "Set folder permissions error: $ErrorMsg"
                    Write-Host "Set folder permissions error: $ErrorMsg" -ForeGroundColor Red
                }
            }
            else {
                Write-Host "Please ensure that you have at least one DOMAIN Group with NTFS permissions added to share folders!" -ForeGroundColor Red
            }
        }
    }
    else {
        Write-Output "Local Admin Group check passed! You can proceed to use AWS DataSync or Robocopy to migrate data to FSx"
        Write-Log -Level INFO -Message "Local Admin Group check passed! You can proceed to use AWS DataSync or Robocopy to migrate data to FSx"
    }

    # Get the current share permissions
    $SharePermissions = (Get-SmbShareAccess -Name $share.Name)

    # SHARE PERMISSION CHECK - is the local administrators group on the share
    $IsAdminGroupPresent = $SharePermissions | Where-Object { $_.AccountName -eq "$LocalAdminGroup" }

    if ($IsAdminGroupPresent) {
        # Ask customer if they would like to add the correct SMB share permissions to the folder.
        $FixSMBPermissions = Read-Host -Prompt 'Would you like to script to remove local admin permissions and add domain group permission on SMB share? Insert Yes or No?'
        if ($FixSMBPermissions -cmatch "^(?i)y(?:es)?$") {
            # Remove the local administrators group from the share permissions
            Revoke-SmbShareAccess -Name "$($share.Name)" -AccountName "$LocalAdminGroup"

            # Add the domain administrators group to the share permissions
            Grant-SmbShareAccess -Name "$($share.Name)" -AccountName $DomainAdminGroup -AccessRight Full

            # Write to log
            Write-Log -Level INFO -Message "The local administrators group has been replaced with the domain administrators group in the share permissions."
            Write-Output "The $DomainAdminGroup group has been added to the share permissions."
        }
        else {
            Write-Output "Please remove local admin group from SMB permission manually to continue"
            Write-Log -Level ERROR -Message "Please remove local admin group from SMB permission manually to continue"
        }
    }
}
