<#
This PowerShell script is designed to create a CNAME (Canonical Name) record in the DNS server for an alias and link it to the hostname of an Amazon FSx (File System) server.

Here's a breakdown of the script:

    Alias Check: The script first checks if the $Alias variable is not null or an empty string. If it's not, the script proceeds to the next step.

    DNS Zone and Server Retrieval: The script tries to retrieve the DNS zone name and the DNS server computer name using the Get-CimInstance and Resolve-DnsName cmdlets.

    CNAME Record Management: For each item in the $Alias array:
        The script checks if the CNAME record for the alias already exists by using the Get-DnsServerResourceRecord cmdlet. If the record exists, it is removed using the 
        Remove-DnsServerResourceRecord cmdlet.
        The script then creates a new CNAME record using the Add-DnsServerResourceRecordCName cmdlet, linking the alias to the $FSxDNSName value (the hostname of the Amazon FSx server).

    Error Handling: The script uses a Try/Catch block to handle any exceptions that might occur during the DNS record management process.

    Output: The script provides some output to the user, indicating the actions it's taking (creating/removing CNAME records).

This script is designed to be run on the source file server with CredSSP auth enabled (specified by the $FQDN variable) using the credentials provided in the $FSxAdminUserCredential variable. 

Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential

The script uses the Invoke-Command cmdlet to execute the DNS management tasks on the Active Directory DNS server using the -Credential parameter to supply credentials.
Add-DnsServerResourceRecordCName cmdlet does not offer a way to provide credentials, hence the Invoke-Command with -Credential workaround is being used.

The script is useful for automating the process of creating CNAME records for aliases that point to the Amazon FSx server, which can be helpful in scenarios where you need to manage multiple aliases or 
update them frequently.

#>
#########################################################################
## RECREATE DNS CNAME RECORD FOR ALIAS AND LINK TO FSX HOSTNAME
#########################################################################
# If variable $Alias is not null or not an empty string, run code block
if (![string]::IsNullOrEmpty($Alias)) 
{
    Write-Output "Aliases found creating CNAME for $($Alias)"

    Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential -ScriptBlock {

        Try
        {
            $ZoneName=((Get-CimInstance Win32_ComputerSystem).Domain)
            $DnsServerComputerName = (Resolve-DnsName $ZoneName -Type NS | Where-Object Type -eq 'A' | Select-Object -ExpandProperty Name)
        }
        Catch
        {
            Write-Output $_.Exception.Message
            #exit 1
        }

        foreach ($item in $using:Alias)
        {
            $AliasHost=$item.Split('.')[0]
            Write-Output "Checking for existing CNAME $AliasHost"
            # Expecting an error record not found so silently continue or pipe to out-null.
             foreach ($DnsServer in $DnsServerComputerName){
                $DnsRecord = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $AliasHost -ComputerName $DnsServer -RRType CName -ErrorAction SilentlyContinue
            }
            if ($DnsRecord)
            {
                Write-Output "Existing CNAME found, removing $DnsRecord"
                Remove-DnsServerResourceRecord -ZoneName $ZoneName -Name $AliasHost -ComputerName $DnsServerComputerName[0] -RRType CName -Force
            }
            Write-Output "Creating CNAME record for our alias $AliasHost to map to FSxDNS $Using:FSxDNSName"
            foreach ($DnsServer in $DnsServerComputerName){
            Add-DnsServerResourceRecordCName -Name $AliasHost -ComputerName $DnsServer -HostNameAlias $Using:FSxDNSName -ZoneName $ZoneName
            }
            Write-Output $DnsRecord
        }
    }# End Invoke Command

}
else
{
    Write-Output "No alias found, no CNAME required"
}
