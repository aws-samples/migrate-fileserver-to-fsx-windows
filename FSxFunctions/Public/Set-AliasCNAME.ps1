<#
  The function performs the following tasks:
  Dot-sources the Write-Log.ps1 module to have access to the Write-Log function.
  Checks if the $Alias array is not null.
  Uses Invoke-Command to execute the CNAME record management logic on the remote machine specified by the $FQDN variable.
  Retrieves the domain name and the DNS server computer names using the Get-CimInstance and Resolve-DnsName cmdlets.
  Loops through each alias and checks if the corresponding CNAME record already exists. If so, it removes the existing record.
  Creates a new CNAME record that maps the alias to the $FSxDNSName using the Add-DnsServerResourceRecordCName cmdlet.
  The function handles any exceptions that might occur during the CNAME record management process.
  
  To use this function, you would need to import the AliasAndCNAME.psm1 module in your main script:
  Import-Module -Name $PSScriptRoot\AliasAndCNAME.psm1 -Verbose
  And then you can call the Update-AliasAndCNAME function like this:
  Update-AliasAndCNAME -Alias $Alias -FSxDNSName $FSxDNSName -FSxAdminUserCredential $FSxAdminUserCredential
#>
function Set-AliasAndCNAME {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Alias,
        [Parameter(Mandatory = $true)]
        [string]$FSxDNSName,
        [Parameter(Mandatory = $true)]
        [pscredential]$FSxAdminUserCredential
    )

    . $PSScriptRoot\Write-Log.ps1

    if ($null -ne $Alias) {
        Write-Output "Aliases found creating CNAME for $Alias"

        Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential -ScriptBlock {
            try {
                $zoneName = ((Get-CimInstance Win32_ComputerSystem).Domain)
                $dnsServerComputerName = (Resolve-DnsName $zoneName -Type NS | Where-Object Type -eq 'A' | Select-Object -ExpandProperty Name)
            }
            catch {
                Write-Output $_.Exception.Message
            }

            foreach ($item in $using:Alias) {
                $aliasHost = $item.Split('.')[0]
                Write-Output "Checking for existing CNAME $aliasHost"

                foreach ($dnsServer in $dnsServerComputerName) {
                    $dnsRecord = Get-DnsServerResourceRecord -ZoneName $zoneName -Name $aliasHost -ComputerName $dnsServer -RRType CName -ErrorAction SilentlyContinue
                }

                if ($dnsRecord) {
                    Write-Output "Existing CNAME found, removing $dnsRecord"
                    Remove-DnsServerResourceRecord -ZoneName $zoneName -Name $aliasHost -ComputerName $dnsServerComputerName[0] -RRType CName -Force
                }

                Write-Output "Creating CNAME record for our alias $aliasHost to map to FSxDNS $using:FSxDNSName"
                foreach ($dnsServer in $dnsServerComputerName) {
                    Add-DnsServerResourceRecordCName -Name $aliasHost -ComputerName $dnsServer -HostNameAlias $using:FSxDNSName -ZoneName $zoneName
                }

                Write-Output $dnsRecord
            }
        }
    }
    else {
        Write-Output "No alias found, no CNAME required"
    }
}
