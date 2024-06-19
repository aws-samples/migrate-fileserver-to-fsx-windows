#########################################################################
# 6 # RECREATE DNS CNAME RECORD FOR ALIAS AND LINK TO FSX HOSTNAME
#########################################################################

if ($null -ne $Alias)
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