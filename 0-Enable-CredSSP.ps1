<#
This script is designed to enable the Credential Security Support Provider (CredSSP) on both the server and client sides. 
    Enable CredSSP on the Server Side:
        The script uses the Enable-WSManCredSSP cmdlet with the -Role Server parameter to enable CredSSP on the server side.
        It handles any exceptions that may occur during the execution of this command using a try-catch block.

    Enable CredSSP on the Client Side:
        The script uses the Enable-WSManCredSSP cmdlet with the -Role Client parameter to enable CredSSP on the client side.
        It also sets the trustedhosts and credSSP values in the WinRM configuration using the Set-Item cmdlet.
        Again, it uses a try-catch block to handle any exceptions that may occur.

    Create a Registry Key:
        The script checks if the HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly registry key exists, and if not, it creates it.
        It then sets the value of the 1 registry key to *, using the New-ItemProperty cmdlet.
        This step is also wrapped in a try-catch block to handle any exceptions.

    Restart the WinRM Service:
        Finally, the script restarts the WinRM service using the Restart-Service cmdlet.

The purpose of this script is to enable CredSSP on both the server and client sides, which is a security protocol that allows the delegation of user credentials from the client to the server. 
This is used by the Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential to make DNS CNAME changes. 
The script also creates a registry key that allows the use of fresh credentials when using NTLM authentication, which can be useful in certain scenarios.
https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-credssp#allowfreshcredentials

Overall, this script is a useful tool for configuring CredSSP on Windows systems.

#>
# Enable CredSSP
$FQDN = (Resolve-DnsName $(hostname) -Type A).Name
Try
{
    Write-Output 'Enabling CredSSP for Server'
    Enable-WSManCredSSP -Role Server -Force -ErrorAction Stop
}
Catch [System.Exception]
{
    Write-TerminatingError "Failed to enable CredSSP for Server $_"
}

Try
{
    Write-Output 'Enabling CredSSP for Client'
    Enable-WSManCredSSP -Role Client -DelegateComputer $FQDN -Force -ErrorAction Stop
    # Trusted Hosts Backup Existing
    Get-item WSMan:\localhost\Client\TrustedHosts    
    $ExistingTrustedHosts = (Get-Item -Path "WSMan:\localhost\client\trustedhosts").Value
    # If nothing exists, set the FQDN of source server as trusted host
    if ([String]::IsNullOrEmpty($ExistingTrustedHosts))
    {
        Write-Host "No trusted hosts found in list, adding $FQDN" -ForegroundColor Green
        Set-Item -Path "WSMan:\localhost\client\trustedhosts" -Value $FQDN -Force
    }else{
            Write-Host "Export the existing TrustedHosts list to C:\TrustedHosts.txt" -ForegroundColor Green
            $ExistingTrustedHosts | Out-File -FilePath "C:\TrustedHosts.txt"
            # Check if the $FQDN is already in the Trusted Hosts list
            if ($ExistingTrustedHosts -like "*$FQDN*")
            {
                Write-Host "$FQDN is already in the Trusted Hosts list. No action taken." -ForegroundColor Green
            }
            else
            {
                
                if (![String]::IsNullOrEmpty($FQDN))
                {
                    # Add the new host to the TrustedHosts list temporarily
                    Write-Host "Adding $FQDN to existing TrustedHosts list" -ForegroundColor Green
                    # WSMAN provider has some dynamic parameters that appears only when you are in a WSMAN path for example -Concatenate
                    Set-Item -Path "WSMan:\localhost\client\trustedhosts" -Value $FQDN -Concatenate -Force
                }
            }
    } 

    Set-Item -Path "WSMan:\localhost\service\auth\credSSP" -Value $True -Force
}
Catch [System.Exception]
{
    Write-Output "Failed to enable CredSSP for Client $_"
}

$Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows"
if (!(Test-Path "$Key\CredentialsDelegation")) {
    New-Item $Key -Name CredentialsDelegation | Out-Null
}

Try
{
    New-Item -Path $Key\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Force
    New-ItemProperty -Path $Key\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value * -PropertyType String -ErrorAction Stop
}
Catch [System.Exception]
{
    Write-Output "Failed to add new registry key to enable CredSSP $_"
}
Restart-Service WinRM
