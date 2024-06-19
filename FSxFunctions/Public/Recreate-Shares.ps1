<#
    The function performs the following tasks:
    Dot-sources the Write-Log.ps1 module to have access to the Write-Log function.
    Checks if the PowerShell endpoint on the FSx instance is reachable by invoking the Get-FSXSmbShare cmdlet.
    Imports the SMB share information from the XML file created earlier.
    Defines a list of accepted parameters for the New-FSxSmbShare cmdlet.
    Loops through each share and creates it on the FSx instance using the Invoke-Command cmdlet and the accepted parameters.
    
    The function handles any exceptions that might occur during the share creation process.
    To use this function, you would need to import the RecreateShares.psm1 module in your main script:
    
    Import-Module -Name $PSScriptRoot\RecreateShares.psm1 -Verbose
    And then you can call the Invoke-RecreateShares function like this:
    Invoke-RecreateShares -FSxDestRPSEndpoint $FSxDestRPSEndpoint -FSxAdminUserCredential $FSxAdminUserCredential -LogLocation $LogLocation
#>
function Invoke-RecreateShares {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FSxDestRPSEndpoint,
        [Parameter(Mandatory = $true)]
        [pscredential]$FSxAdminUserCredential,
        [Parameter(Mandatory = $true)]
        [string]$LogLocation
    )

    . $PSScriptRoot\Write-Log.ps1

    # Validate if PowerShell Endpoints are reachable
    $testDestPs = Invoke-Command -ConfigurationName FSxRemoteAdmin -ComputerName $FSxDestRPSEndpoint -Credential $FSxAdminUserCredential -ErrorAction Stop -ScriptBlock { Get-FSXSmbShare }
    if (-not $testDestPs) {
        Write-Output "PowerShell Endpoint Not Reachable"
        Write-Log -Level ERROR -Message "PowerShell Endpoint Not Reachable"
        Start-Sleep -Seconds 5
        return
    }

    # Get shares from XML export on local file server
    $shares = Import-Clixml -Path "$LogLocation\SmbShares.xml"

    # Prep share creation parameters
    $fsxAcceptedParameters = @("ContinuouslyAvailable", "Description", "ConcurrentUserLimit", "CATimeout", "FolderEnumerationMode", "CachingMode", "FullAccess", "ChangeAccess", "ReadAccess", "NoAccess", "SecurityDescriptor", "Name", "EncryptData")

    # Create shares on destination FSx
    foreach ($item in $shares) {
        $param = @{}
        foreach ($property in $item.PSObject.Properties) {
            if ($property.Name -in $fsxAcceptedParameters) {
                $param[$property.Name] = $property.Value
            }
        }

        Write-Output "About to create $($item.Name)"
        Write-Log -Level INFO -Message "About to create $($item.Name)"
        try {
            $shareName = $item.Name
            if ($testDestPs.Name -match $shareName) {
                Write-Output "Share already exists, skipping"
                Write-Log -Level INFO -Message "Share already exists, skipping"
            }
            else {
                Invoke-Command -ConfigurationName FSxRemoteAdmin -ComputerName $FSxDestRPSEndpoint -ErrorVariable errmsg -ScriptBlock { New-FSxSmbShare -Path "D:\$Using:ShareName" -Credential $Using:FSxAdminUserCredential @Using:param }
            }
        }
        catch {
            Write-Log -Level ERROR -Message $_
        }
    }
}
