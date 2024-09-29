<#
This PowerShell script is designed to remove the existing Service Principal Names (SPNs) associated with the aliases of the source file server's computer object in Active Directory, and then add the 
appropriate SPNs to the Active Directory computer object of the destination AWS FSx file system.

Here's a breakdown of what the script does:

    Validate Alias: The script first checks if the $Alias variable is null or empty. If it is, the script exits safely.

    Remove SPNs from Source File Server: The script loops through each alias in the $Alias variable and performs the following actions:
        Finds the computer object in Active Directory that has the alias set as an SPN.
        Checks if the SPN exists for the alias.
        If the SPN exists, the script removes the SPN from the computer object using the Set-AdComputer cmdlet.
        If the msDS-AdditionalDnsHostname attribute exists, the script removes the alias from this attribute as well.

    Add SPNs to FSx File System: After removing the SPNs from the source file server, the script invokes a remote PowerShell session on the destination FSx file system and performs the following actions:
        Resolves the DNS name of the FSx file system to get the computer host name.
        Retrieves the Active Directory computer object for the FSx file system.
        Extracts the domain name from the computer object's distinguished name.
        Checks if the alias matches the domain name of the FSx file system.
        If the alias matches, the script adds the alias to the msDS-AdditionalDnsHostname attribute of the FSx file system's computer object using the Set-ADObject cmdlet.
        The script also sets the appropriate SPNs for the alias using the setspn command.

The script requires the following variables to be set:

    $Alias: The list of aliases associated with the source file server.
    $FSxDnsName: The DNS name of the FSx file system.
    $FSxAdminUserCredential: The credentials for an administrative user on the FSx file system.

These variable values are set via the MigrationParameters.ps1 file and loaded into memory using:  . .\MigrationParameters.ps1
The main purpose of this script is to ensure that the necessary SPNs are set up on the destination FSx file system to enable seamless access to the file shares, especially when using Kerberos authentication. By removing the SPNs from the source file server and adding them to the FSx file system, the script helps to avoid potential authentication issues during the migration process.

#>
#########################################################################
# REMOVE SPN FROM SOURCE FILE SERVER
######################################################################### 
# To find and delete existing DNS alias SPNs on the original file system's Active Directory computer object
 if ([string]::IsNullOrEmpty($Alias)) {
    Write-Output "No alias set, exit safely"
    Write-Log -Level INFO -Message "No alias set, exit safely"
    exit 0
 }else
 {
    foreach ($item in $Alias){     
        # Get the computer object that has the Alias set as an SPN
        Try
        {
            # Check if the alias is already in FQDN format
            if ($item.Contains("."))
            {
                $Identity = [string]$item.Split(".")[0]
            }
            else
            {
                # Assume the alias is a short hostname and append the domain
                $GetDomain = (Get-ADDomain).DNSRoot
                $Identity = $item + "." + $GetDomain
            }
            
            $Identity = [string]$item.Split(".")[0]
            Import-Module ActiveDirectory 
            
            #Finding Domain Controller to Fulfill AD Request
            $TargetDomainController = (Get-ADDomainController -Discover).Name
            
            # Add Alias to the search filter
            $Filter = [string]"HOST/"+"$Identity"
    
            Write-Output "Checking if SPN exist for $($Filter)"
            Write-Log -Level INFO -Message "Checking if SPNs of the alias $($Filter) is linked to a computer object"
    
            Write-Host "Checking if SPNs of the alias $($Filter) is linked to a computer object" -ForeGroundColor Green
            $GetSPN = Get-ADObject -filter {servicePrincipalName -eq $Filter} -Server $TargetDomainController -Credential $FSxAdminUserCredential
    
            Write-Output "Current SPN $($Filter) is linked to $($GetSPN.Name)"
            Write-Log -Message "Current SPN $($Filter) is linked to $($GetSPN.Name)"
    
            if ([string]::IsNullOrEmpty($GetSPN)){
                Write-Output "No SPN record found for $($Filter) skipping delete SPN"
                Write-Log -Level INFO -Message "No SPN record found for $($Filter) skipping delete SPN"
            }else
            {
                # IF SPN of alias exists anywhere in domain, delete SPN
                $Identity = $GetSPN.Name
                Write-Output "Deleting SPN of the source server $($item) from computer object $($Identity)"
                Write-Log -Level INFO -Message "Deleting SPN of the source server $($item) from computer object $($Identity)"
                # HOST SPN FQDN
                Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("HOST/$item")} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                # HOST SPN HostName
                #  Need to use hostname now to avoid Set-AdComputer : Cannot find an object with identity: 'EC2AMAZ-12345.mytestdomain.local' under: 'DC=mytestdomain,DC=local'.  
                Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("HOST/" + $item.Split('.')[0] )} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                # Terminal Services FQDN
                Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("TERMSRV/$item")} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                # Terminal Services HostName
                Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("TERMSRV/" + $item.Split('.')[0] )} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                # Restricted Kerberos Host FQDN
                Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("RestrictedKrbHost/$item")} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                # Restricted Kerberos HostName
                Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("RestrictedKrbHost/" + $item.Split('.')[0] )} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                # Check if the ms-additionaldnsname attribute exists
                # Remove msDS-AdditionalDnsHostname
                # Use hostname instead of FQDN to avoid  Get-ADComputer : Cannot find an object with identity: 'computername.mytestdomain.local'     
                $GetMSAdditional = (Get-ADComputer -Identity $Identity -Properties msDS-AdditionalDnsHostname -Server $TargetDomainController | Select-Object -ExpandProperty msDS-AdditionalDnsHostname)
                if ($GetMSAdditional -contains $item.Split('.')[0])
                {
                    # The item stored in Get-ADcomputer has an invisible $null or unicode value of 0 which causes the if statement to fail, fixed it by adding [char]0 
                    $AliasLower = $item.Split('.')[0] +[char]0+"$"
                    $AliasUpper = $AliasLower.ToUpper()
                    # Remove the additional DNS name from the computer object
                    foreach ($DNSitem in $GetMSAdditional)
                    {
                        # Remove msDS-AdditionalDnsHostname
                        if ($DNSitem -eq "$AliasUpper") 
                        {
                            Write-Output "Removing $($DNSitem)"
                            Set-AdComputer -Identity $Identity -Remove @{"msDS-AdditionalDnsHostname"="$AliasUpper"} -Server $TargetDomainController
                            # Weird bug, need to run this twice to remove.
                            Set-AdComputer -Identity $Identity -Remove @{"msDS-AdditionalDnsHostname"="$AliasUpper"} -Server $TargetDomainController
                        }
                        # Remove FQDN msDS-AdditionalDnsHostname
                        if ($DNSitem -eq $item)
                        {
                            Write-Output "Removing $($DNSitem)"
                            Set-AdComputer -Identity $Identity -Remove @{"msDS-AdditionalDnsHostname"="$item"} -Server $TargetDomainController 
                        }
                    } 
                    # Remove any SMB port 445 SPN
                    Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("HOST/$item"+":445")} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                    Set-AdComputer -Identity $Identity -ServicePrincipalName @{Remove=("HOST/" + $item.Split('.')[0] + ":445")} -Server $TargetDomainController -Credential $FSxAdminUserCredential
                } 
    
            }
        }
        Catch
        {
            Write-Output $_
            Write-Log -Level ERROR -Message $_
        }
    
    }  
    
    #########################################################################
    ## ADD SPN TO FSX
    #########################################################################
    Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential -ScriptBlock {
        foreach ($item in $using:Alias) {
            ## Set SPNs for FSx file system AD computer object
            $FileSystemHost = (Resolve-DnsName $Using:FSxDnsName | Where-Object Type -eq 'A')[0].Name.Split(".")[0]
            Write-Output "FileSystemHost: $FileSystemHost"
    
            $FSxAdComputer = Get-ADComputer -Identity $FileSystemHost
            Write-Output "FSxAdComputer: $FSxAdComputer"
    
            $FSxDomainName = $FSxAdComputer.DistinguishedName -replace "^.*?DC=",""
            $FSxDomainName = $FSxDomainName -replace ",DC=","."
            Write-Output "FSxDomainName: $FSxDomainName"
    
            # Check if the alias matches the domain name of the file server
            if ($item.EndsWith(".$FSxDomainName")) {
                Write-Output "Alias $item matches the domain name of the file server ($FSxDomainName)"
                Set-ADObject -Identity $FSxAdComputer -Add @{"msDS-AdditionalDnsHostname"="$item"}
                setspn -S "HOST/$($item.Split('.')[0])" $FSxAdComputer.Name
                setspn -S "HOST/$item" $FSxAdComputer.Name
            }
            else {
                Write-Output "Alias $item does not match the domain name of the file server ($FSxDomainName). Skipping SPN setup."
            }
        }
    }
    
}    
    
    
