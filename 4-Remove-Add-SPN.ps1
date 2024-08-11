<#
This script is responsible for removing the existing Service Principal Name (SPN) from the source file server's Active Directory computer object and then,
adding the new SPN to the FSx instance's Active Directory computer object.
The script first loops through the provided aliases and checks if the corresponding SPN exists on the source file server's computer object. If found, it removes the SPN using the Set-AdComputer cmdlet.
It also checks and removes the msDS-AdditionalDnsHostname attribute if it exists.
In the second part of the script, it invokes a remote PowerShell session on the FSx instance and adds the new SPN using the SetSpn tool and the Set-AdComputer cmdlet.
The script handles any exceptions that might occur during the SPN management process.
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
            $Identity = [string]$item.Split(".")[0]
            Import-Module ActiveDirectory 
            
            #Finding Domain Controller to Fulfill AD Request
            $TargetDomainController = (Get-ADDomainController -Discover).Name
            
            # Add Alias to the search filter
            $Filter = [string]"HOST/"+"$Identity"
    
            Write-Output "Checking if SPN exist for $($Filter)"
            Write-Log -Level INFO -Message "Checking if SPN exist for $($Filter)"
    
            Write-Host "Check if SPNs of the alias are linked to a computer object" -ForeGroundColor Green
            $GetSPN = Get-ADObject -filter {servicePrincipalName -eq $Filter} -Server $TargetDomainController -Credential $FSxAdminUserCredential
    
            Write-Output "Current SPN $($Filter) is linked to $($GetSPN.Name)"
            Write-Log -Message "Current SPN $($Filter) is linked to $($GetSPN.Name)"
    
            if ( ($null -eq $GetSPN) -or ("" -eq $GetSPN) )
            {
                Write-Output "SPN not found for $($Filter) "
                Write-Log -Level INFO -Message "SPN not found for $($Filter)"
            }else
            {
                # IF SPN of alias exists anywhere in domain, delete SPN
                $Identity = $GetSPN.Name
                Write-Output "Deleting SPN for $($item) on computer object $($Identity)"
                Write-Log -Level INFO -Message "Deleting SPN for $($item) on computer object $($Identity)"
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
    
    
