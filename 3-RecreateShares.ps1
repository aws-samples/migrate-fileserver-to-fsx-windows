<#
This script is responsible for recreating the file shares on the FSx instance using PowerShell remoting.
It first checks if the PowerShell endpoint on the FSx instance is reachable by invoking the Get-FSXSmbShare cmdlet.
The script then imports the SMB share information from the XML file created earlier and loops through each share.
For each share, it checks if the share already exists on the FSx instance. If not, it creates the share using the New-FSxSmbShare cmdlet and the parameters extracted from the imported share object.
The script handles any exceptions that might occur during the share creation process.
#>
#########################################################################
# RECREATE FILE SHARES ON FSX USING POWERSHELL REMOTING
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

    Try
    {
        $SharePath = "D:\$($item.Path.Substring($item.Path.LastIndexOf('\') + 1))"
        # Construct the FSx-based share path 
        $SharePath = "D:\$shareName"
        # [System.IO.Path] is a .NET class that provides methods for working with file and directory paths.
        # For example, if $item.Path is "C:\share1\Finance", then [System.IO.Path]::GetFileName($item.Path) would return "Finance" so we can recreate the share on FSx D:\Finance
        $shareName = [System.IO.Path]::GetFileName($item.Path) 
        if ($TestDestPS.Name -match $item.Name){
            Write-Output "Share already exists, skipping"
            Write-Log -Level INFO -Message "Share already exists, skipping"
        }else{
            Write-Output "About to create a share called $($item.Name)"
            Write-Log -Level INFO -Message "About to create a share called $($item.Name)"
            $CreateShare = Invoke-Command -ConfigurationName FSxRemoteAdmin -ComputerName $FSxDestRPSEndpoint -ErrorVariable errmsg -ScriptBlock {New-FSxSmbShare -Path $Using:SharePath -Credential $Using:FSxAdminUserCredential @Using:param}
            Write-Output $CreateShare
        }
    }
    Catch
    {
        Write-Log -Level ERROR -Message $_
    }
}
