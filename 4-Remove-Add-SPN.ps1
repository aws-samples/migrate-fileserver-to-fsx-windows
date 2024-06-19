 #########################################################################
# 4 # REMOVE SPN FROM SOURCE FILE SERVER
######################################################################### 
# To find and delete existing DNS alias SPNs on the original file system's Active Directory computer object
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
# 5 # ADD SPN TO FSX
#########################################################################
Invoke-Command -Authentication Credssp -ComputerName $FQDN -Credential $FSxAdminUserCredential -ScriptBlock {
    foreach ($item in $using:Alias){
         ## Set SPNs for FSx file system AD computer object
        $FileSystemHost = (Resolve-DnsName $Using:FSxDnsName | Where Type -eq 'A')[0].Name.Split(".")[0]
        $FSxAdComputer = (Get-AdComputer -Identity $FileSystemHost)
        Set-AdComputer -Identity $FSxAdComputer -Add @{"msDS-AdditionalDnsHostname"="$item"}
        SetSpn /S ("HOST/" + $item.Split('.')[0]) $FSxAdComputer.Name
        SetSpn /S ("HOST/" + $item) $FSxAdComputer.Name
    }
}




