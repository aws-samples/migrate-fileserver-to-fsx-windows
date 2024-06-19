<#
  The function performs the following tasks:
  Dot-sources the Write-Log.ps1 module to have access to the Write-Log function.
  Disables the CredSSP client and server roles using the Disable-WSManCredSSP cmdlet.
  Removes the specific registry keys that were created to enable the CredSSP functionality.
  Defines two helper functions, Get-TrustedHost and Remove-TrustedHost, to manage the trusted hosts list in the WinRM configuration.
  Calls the Remove-TrustedHost function to remove the trusted host entry for the $FQDN.
  The function handles any exceptions that might occur during the CredSSP disabling process.
  
  To use this function, you would need to import the DisableCredSSP.psm1 module in your main script:
  Import-Module -Name $PSScriptRoot\DisableCredSSP.psm1 -Verbose
  And then you can call the Disable-CredSSP function like this:
  Disable-CredSSP -FQDN $FQDN
#>

function Disable-CredSSP {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )

    . $PSScriptRoot\Write-Log.ps1

    try {
        $errorActionPreference = "Stop"
        Disable-WSManCredSSP -Role Client
        Disable-WSManCredSSP -Role Server
        Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials' -ErrorAction Ignore
        Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly' -ErrorAction Ignore
        Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain' -ErrorAction Ignore
    }
    catch {
        Write-Output $_
    }

    function Get-TrustedHost {
        [CmdletBinding()]
        [OutputType([string[]])]
        param (
            [string]$Pattern
        )

        $trustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value

        if ([string]::IsNullOrWhiteSpace($trustedHosts)) {
            @()
        }
        else {
            if ([string]::IsNullOrWhiteSpace($Pattern)) {
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
            [Parameter(ValueFromPipeline = $true)]
            [string[]]$Computer
        )

        Begin {
            $trustedHosts = @(Get-TrustedHost)
        }
        Process {
            $trustedHosts = $trustedHosts | Where-Object { $Computer -notcontains $_ }
        }
        End {
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($trustedHosts -join ',') -Force
        }
    }

    Remove-TrustedHost $FQDN
}
