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
        Remove-TrustedHost $FQDN
    
    }
    Catch{Write-Output $_}