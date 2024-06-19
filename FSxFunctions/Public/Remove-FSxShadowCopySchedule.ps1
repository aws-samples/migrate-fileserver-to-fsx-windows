<#
This script contains a function called Remove-FSxShadowCopySchedule
that disables the volume shadow copy schedule on an Amazon FSx for Windows File Server (FSxW) endpoint.
The function takes a single parameter,$DestRPSEndpoint, which is the endpoint of the FSxW instance.
The script first checks the current shadow copy status to see if it is already disabled.
If the shadow copy is enabled, it then disables the schedule by invoking the 
Remove-FSxShadowCopySchedule cmdlet on the remote FSxW instance.
#>
# Disable VSS for 8 hours
Function Remove-FSxShadowCopySchedule{
    Param(
            [string]$DestRPSEndpoint
        )

    # Get the current shadow copy status
    Write-Host "Getting shadow copy schedule" -ForeGroundColor Green
    $Schedule = (Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
    {
        Get-FsxShadowCopySchedule
    })
    Write-Host "Shadow copy status" $GetVSSStatus.Enabled
    if ( ($GetVSSStatus.Enabled -eq $false) -or ($GetVSSStatus.Enabled -ne "True") )
    { 
    
        # Disable the schedule     
        $DisableSchedule = Invoke-Command -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
            {
                Remove-FSxShadowCopySchedule -Confirm:$false
            }

       Write-Host "Volume shadow copy schedule disabled" $DisableVSSSchedule -ForeGroundColor Green
    } 
}    
