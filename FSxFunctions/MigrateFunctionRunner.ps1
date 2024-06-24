# Import the required modules
cd $FunctionsFolderPath
Import-Module .\FSxFunctions.psm1 -Verbose

# Enable CredSSP
Enable-CredSSP -FQDN $FQDN

# Check permissions on source file server
Get-Permissions -ShareRootFolder $ShareRootFolder -LogLocation $LogLocation -DomainAdminGroup $DomainAdminGroup -LocalAdminGroup $LocalAdminGroup

# Copy data to FSx using Robocopy
Invoke-Robocopy -SourceFolder $ShareRootFolder -FSxDriveLetter $FSxDriveLetter -FSxDNSName $FSxDNSName -LogLocation $LogLocation -UseRoboCopyForDataTransfer $UseRoboCopyForDataTransfer

# Recreate shares on FSx
Invoke-RecreateShares -FSxDestRPSEndpoint $FSxDestRPSEndpoint -FSxAdminUserCredential $FSxAdminUserCredential -LogLocation $LogLocation

# Remove SPN from source file server and add SPN to FSx
Remove-AddSPN -Alias $Alias -FSxAdminUserCredential $FSxAdminUserCredential -FQDN $FQDN

# Update aliases and create CNAME records
Update-AliasAndCNAME -Alias $Alias -FSxDNSName $FSxDNSName -FSxAdminUserCredential $FSxAdminUserCredential

# Disable CredSSP
Disable-CredSSP -FQDN $FQDN
