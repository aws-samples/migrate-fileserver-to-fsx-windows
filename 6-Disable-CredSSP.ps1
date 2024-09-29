<#
The provided script is responsible for disabling the CredSSP configuration that was previously enabled. 

    Disable CredSSP Client and Server Roles:
        The script uses the Disable-WSManCredSSP cmdlet to disable the CredSSP client and server roles.

    Remove Registry Keys:
        The script removes the following registry keys that were created to enable the CredSSP functionality:
            HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials
            HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly
            HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain

    Helper Functions:
        The script defines two helper functions: Get-TrustedHost and Remove-TrustedHost.
        Get-TrustedHost retrieves the list of trusted hosts from the WinRM configuration.
        Remove-TrustedHost removes the specified hosts from the trusted hosts list.

    Remove Trusted Host:
        The script uses the Remove-TrustedHost function to remove the FQDN of the host from the trusted hosts list.
        The FQDN is expected to be defined in a separate file, MigrationParameters.ps1, which is not provided in the given code.

    Error Handling:
        The script wraps the entire disabling process in a try-catch block to handle any exceptions that might occur during the execution.

Overall, the script is responsible for disabling the CredSSP configuration, removing the related registry keys, and removing the FQDN of the host from the trusted hosts list. 
This is typically done after the CredSSP configuration has been enabled and is no longer needed.

The $FQDN variable, is expected to be supplied by the MigrationParameters file when running . .\MigrationParameters.ps1 
Without this file, the script will not be able to remove the trusted host entry for the FQDN.

#>

Try
{
    $ErrorActionPreference = "Stop"
    Disable-WSManCredSSP Client
    Disable-WSManCredSSP Server
    Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials' -ErrorAction Ignore
    Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly' -ErrorAction Ignore
    Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain' -ErrorAction Ignore
    
    function Get-TrustedHost {
        [CmdletBinding()]
        [OutputType([String[]])]
        param(
            [String]
            $Pattern    
        )
        
        $trustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    
        if ($trustedHosts -eq '') {
            @()
        }
        else {
            if ([String]::IsNullOrWhiteSpace($Pattern)) {
                $trustedHosts.Split(',')
            }
            else {
                $trustedHosts.Split(',') | Where-Object { $_ -match $Pattern }
            }
        }
    }
    
    function Remove-TrustedHost {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline=$true)]
            [String[]]
            $Computer
        )
    
        Begin {
            $trustedHosts = @(Get-TrustedHost)
        }
        Process {
            $trustedHosts = $trustedHosts | Where-Object { $Computer -notcontains $_ }
        }
        End {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($trustedHosts -join ',' ) -Force
        }
    }
    #Restore the TrustedHosts list from the file created by Enable-CredSSP.ps1 under C:\Trustedhosts.txt:
    $TrustedHostsFromFile = Get-Content -Path "C:\TrustedHosts.txt"
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "$TrustedHostsFromFile" 

}Catch{
    Write-Output $_
}
