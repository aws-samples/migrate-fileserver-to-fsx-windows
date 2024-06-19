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
    Set-Item -Path "WSMan:\localhost\client\trustedhosts" -value $FQDN -Force
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



