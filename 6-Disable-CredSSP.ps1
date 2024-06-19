<#
This script is responsible for disabling the CredSSP configuration that was enabled earlier in the process.
It disables the CredSSP client and server roles using the Disable-WSManCredSSP cmdlet.
It also removes the registry keys that were created to enable the CredSSP functionality.
The script defines two helper functions, Get-TrustedHost and Remove-TrustedHost, to manage the trusted hosts list in the WinRM configuration.
Finally, it removes the trusted host entry for the FSx instance's FQDN using the Remove-TrustedHost function.
The script handles any exceptions that might occur during the CredSSP disabling process.
#>
# Disable CredSSP
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
    # $FQDN = (Resolve-DnsName $(hostname) -Type A).Name located in MigrationParameters.ps1
    Remove-TrustedHost $FQDN

}
Catch{Write-Output $_}
