#########################################################################
# 3 # RECREATE FILE SHARES ON FSX USING POWERSHELL REMOTING
#########################################################################
## Validate if PowerShell Endpoints are reachable
$TestDestPS = (Invoke-Command -ConfigurationName FSxRemoteAdmin -ComputerName $FSxDestRPSEndpoint -Credential $FSxAdminUserCredential -ErrorAction Stop -ScriptBlock {Get-FSXSmbShare})
if (!($TestDestPS)){
    Write-Output "PowerShell Endpoint Not Reachable"
    Write-Log -Level ERROR -Message "PowerShell Endpoint Not Reachable"
    Start-Sleep -Seconds 5
    exit 1
}

# Get shares from XML export on local file server
$shares = Import-Clixml -Path $LogLocation\SmbShares.xml

# Prep share creation parameters
$FSxAcceptedParameters = ("ContinuouslyAvailable", "Description", "ConcurrentUserLimit", "CATimeout", "FolderEnumerationMode", "CachingMode", "FullAccess", "ChangeAccess", "ReadAccess", "NoAccess", "SecurityDescriptor", "Name", "EncryptData")

## Create shares on destination FSx
foreach ($item in $shares) {
            $param = @{};
            Foreach ($property in $item.psObject.properties) {
                if ($property.Name -In $FSxAcceptedParameters) {
                    $param[$property.Name] = $property.Value
                }
            }
         
            Write-Output "About to create $($item.Name)"
            Write-Log -Level INFO -Message "About to create $($item.Name)"
            Try
            {
                $ShareName = $item.Name
                if ($TestDestPS.Name -match $ShareName){
                    Write-Output "Share already exists, skipping"
                    Write-Log -Level INFO -Message "Share already exists, skipping"
            
                }else{
                    Invoke-Command -ConfigurationName FSxRemoteAdmin -ComputerName $FSxDestRPSEndpoint -ErrorVariable errmsg -ScriptBlock {New-FSxSmbShare -Path D:\$Using:ShareName -Credential $Using:FSxAdminUserCredential @Using:param}
                }
            }
            Catch
            {
                Write-Log -Level ERROR -Message $_
            }
            
}