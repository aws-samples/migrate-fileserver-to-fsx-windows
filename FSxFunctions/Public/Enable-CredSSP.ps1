<#
The script is designed to enable CredSSP (Credential Security Support Provider) on both the server and client sides.
It performs the following tasks:
Enables CredSSP on the server side using the Enable-WSManCredSSP cmdlet.
Enables CredSSP on the client side, also using the Enable-WSManCredSSP cmdlet, and sets the trustedhosts and credSSP values in the WinRM configuration.
Creates a new registry key HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly if it doesn't already exist, and sets the value 1 to *.
The script uses try-catch blocks to handle any exceptions that might occur during the execution of the commands.
It also restarts the WinRM service at the end.
USAGE:
$FQDN = (Resolve-DnsName $(hostname) -Type A).Name
Enable-CredSSP -FQDN $FQDN
#>
function Enable-CredSSP {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )

    try {
        Write-Log -Level INFO -Message 'Enabling CredSSP for Server'
        Enable-WSManCredSSP -Role Server -Force -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Log -Level ERROR -Message "Failed to enable CredSSP for Server: $_"
    }

    try {
        Write-Log -Level INFO -Message 'Enabling CredSSP for Client'
        Enable-WSManCredSSP -Role Client -DelegateComputer $FQDN -Force -ErrorAction Stop
        Set-Item -Path "WSMan:\localhost\client\trustedhosts" -value $FQDN -Force
        Set-Item -Path "WSMan:\localhost\service\auth\credSSP" -Value $True -Force
    }
    catch [System.Exception] {
        Write-Log -Level ERROR -Message "Failed to enable CredSSP for Client: $_"
    }

    $key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
    if (!(Test-Path "$key\CredentialsDelegation")) {
        New-Item $key -Name CredentialsDelegation | Out-Null
    }

    try {
        New-Item -Path $key\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Force
        New-ItemProperty -Path $key\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value * -PropertyType String -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Log -Level ERROR -Message "Failed to add new registry key to enable CredSSP: $_"
    }

    Restart-Service WinRM
}
