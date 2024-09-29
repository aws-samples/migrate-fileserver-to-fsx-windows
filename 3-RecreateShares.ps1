 <#
Validate PowerShell Endpoint Connectivity: The script checks if the PowerShell endpoint for the destination FSx file system is reachable. If not, it logs an error and exits.

Import Shares from XML: The script imports the list of shares from the XML file generated in the previous script.

Prepare Share Creation Parameters: The script filters the share properties to only include the parameters that are accepted by the New-FSxSmbShare cmdlet.

Recreate Shares on FSx: The script loops through each share and creates a new share on the destination FSx file system using the Invoke-Command cmdlet and the New-FSxSmbShare cmdlet. 

It constructs the share path on the FSx file system based on the share name.
#>

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
        Write-Output "About to create a share called $($item.Name)"
        Write-Log -Level INFO -Message "About to create a share called $($item.Name)"
        if ($item.Path -match '^[A-CE-Z]:\\') {
         $SharePath = 'D:' + $item.Path.Substring(2)
        } else {
            $SharePath = $item.Path
        }
        if ($TestDestPS.Name -match $item.Name){
            Write-Output "Share already exists, skipping"
            Write-Log -Level INFO -Message "Share already exists, skipping"
        }
        else {
         $CreateShare = Invoke-Command -ConfigurationName FSxRemoteAdmin -ComputerName $FSxDestRPSEndpoint -ErrorVariable errmsg -ScriptBlock {New-FSxSmbShare -Path $Using:SharePath -Credential $Using:FSxAdminUserCredential @Using:param}
         Write-Output $CreateShare
        }
       
    }
    Catch
    {
        Write-Log -Level ERROR -Message $_
        Write-Output $_
    }
}
