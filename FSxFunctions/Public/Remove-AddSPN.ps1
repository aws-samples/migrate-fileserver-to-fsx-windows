<#
  The function performs the following tasks:
  Dot-sources the Write-Log.ps1 module to have access to the Write-Log function.
  Loops through the provided aliases and checks if the corresponding Service Principal Name (SPN) exists on the source file server's Active Directory computer object.
  If the SPN exists, the function removes the SPN and the msDS-AdditionalDnsHostname attribute using the Set-ADComputer cmdlet.
  After removing the SPNs from the source file server, the function uses Invoke-Command to add the new SPN to the FSx instance's Active Directory computer object.

  The function handles any exceptions that might occur during the SPN management process.
  To use this function, you would need to import the RemoveAddSPN.psm1 module in your main script:
  
  Import-Module -Name $PSScriptRoot\RemoveAddSPN.psm1 -Verbose
  And then you can call the Remove-AddSPN function like this:
  Remove-AddSPN -Alias $Alias -FSxAdminUserCredential $FSxAdminUserCredential -FQDN $FQDN
#>
function Remove-AddSPN {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Alias,
        [Parameter(Mandatory = $true)]
        [pscredential]$FSxAdminUserCredential,
        [Parameter(Mandatory = $true)]
        [string]$FQDN
    )

    . $PSScriptRoot\Write-Log.ps1

    # Remove SPN from source file server
    foreach ($item in $Alias) {
        try {
            $identity = [string]$item.Split(".")[0]
            Import-Module ActiveDirectory
            $targetDomainController = (Get-ADDomainController -Discover).Name
            $filter = [string]"HOST/" + "$identity"

            Write-Output "Checking if SPN exist for $filter"
            Write-Log -Level INFO -Message "Checking if SPN exist for $filter"

            Write-Host "Check if SPNs of the alias are linked to a computer object" -ForeGroundColor Green
            $getSPN = Get-ADObject -filter { servicePrincipalName -eq $filter } -Server $targetDomainController -Credential $FSxAdminUserCredential

            Write-Output "Current SPN $filter is linked to $($getSPN.Name)"
            Write-Log -Message "Current SPN $filter is linked to $($getSPN.Name)"

            if ($null -eq $getSPN -or $getSPN -eq "") {
                Write-Output "SPN not found for $filter"
                Write-Log -Level INFO -Message "SPN not found for $filter"
            }
            else {
                $identity = $getSPN.Name
                Write-Output "Deleting SPN for $item on computer object $identity"
                Write-Log -Level INFO -Message "Deleting SPN for $item on computer object $identity"

                # Remove SPNs
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("HOST/$item")} -Server $targetDomainController -Credential $FSxAdminUserCredential
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("HOST/" + $item.Split('.')[0])} -Server $targetDomainController -Credential $FSxAdminUserCredential
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("TERMSRV/$item")} -Server $targetDomainController -Credential $FSxAdminUserCredential
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("TERMSRV/" + $item.Split('.')[0])} -Server $targetDomainController -Credential $FSxAdminUserCredential
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("RestrictedKrbHost/$item")} -Server $targetDomainController -Credential $FSxAdminUserCredential
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("RestrictedKrbHost/" + $item.Split('.')[0])} -Server $targetDomainController -Credential $FSxAdminUserCredential

                # Remove msDS-AdditionalDnsHostname
                $getMSAdditional = (Get-ADComputer -Identity $identity -Properties "msDS-AdditionalDnsHostname" -Server $targetDomainController | Select-Object -ExpandProperty "msDS-AdditionalDnsHostname")
                if ($getMSAdditional -contains $item.Split('.')[0]) {
                    $aliasLower = $item.Split('.')[0] + [char]0 + "$"
                    $aliasUpper = $aliasLower.ToUpper()
                    foreach ($dnsItem in $getMSAdditional) {
                        if ($dnsItem -eq $aliasUpper) {
                            Write-Output "Removing $dnsItem"
                            Set-ADComputer -Identity $identity -Remove @{"msDS-AdditionalDnsHostname" = $aliasUpper} -Server $targetDomainController
                            Set-ADComputer -Identity $identity -Remove @{"msDS-AdditionalDnsHostname" = $aliasUpper} -Server $targetDomainController
                        }
                        if ($dnsItem -eq $item) {
                            Write-Output "Removing $dnsItem"
                            Set-ADComputer -Identity $identity -Remove @{"msDS-AdditionalDnsHostname" = $item} -Server $targetDomainController
                        }
                    }
                }

                # Remove SMB port 445 SPN
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("HOST/$item" + ":445")} -Server $targetDomainController -Credential $FSxAdminUserCredential
                Set-ADComputer -Identity $identity -ServicePrincipalName @{Remove = ("HOST/" + $item.Split('.')[0] + ":445")} -Server $targetDomainController -Credential $FSxAdminUserCredential
            }
        }
        catch {
            Write-Output $_
            Write-Log -Level ERROR -Message $_
        }
    }

    # Add SPN to FSx
    Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential -ScriptBlock {
        foreach ($item in $using:Alias) {
            $fileSystemHost = (Resolve-DnsName $using:FQDN | Where-Object Type -eq 'A')[0].Name.Split(".")[0]
            $fsxAdComputer = (Get-ADComputer -Identity $fileSystemHost)
            Set-ADComputer -Identity $fsxAdComputer -Add @{"msDS-AdditionalDnsHostname" = $item}
            SetSpn /S ("HOST/" + $item.Split('.')[0]) $fsxAdComputer.Name
            SetSpn /S ("HOST/" + $item) $fsxAdComputer.Name
        }
    }
}
