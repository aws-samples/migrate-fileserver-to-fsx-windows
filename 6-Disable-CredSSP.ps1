<#
This PowerShell script performs the following actions:

Disables the CredSSP Client and Server functionality using the Disable-WSManCredSSP cmdlet.
Removes the registry keys related to the CredSSP delegation policies:
    HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials
    HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly
    HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain
Restores the TrustedHosts list from a file located at C:\TrustedHosts.txt using the Set-Item cmdlet.
If any errors occur during the script execution, they are caught and output using the Write-Output cmdlet.

Please note that the script references a file named C:\TrustedHosts.txt, which is created by 0-Enable-CredSSP.ps1.

#>

Try
{
    Disable-WSManCredSSP Client
    Disable-WSManCredSSP Server
    Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials' -ErrorAction Ignore
    Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly' -ErrorAction Ignore
    Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain' -ErrorAction Ignore

    Write-Host "Restore TrustedHosts list from the file C:\TrustedHosts.txt" -ForegroundColor Green 
    $TrustedHostsFromFile = Get-Content -Path "C:\TrustedHosts.txt"
    Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "$TrustedHostsFromFile" 

}Catch{
    Write-Output $_
}
