<#
Remove-FSxShadowCopySchedule deletes the volume shadow copy schedule on an Amazon FSx for Windows File Server (FSxW) endpoint.
This function should not be necessary during the initial migration to FSx as there should not be any existing shadow copy schedules on the new FSx instance.
However, it is included here in case you need to manage the shadow copy schedules after the migration is complete.
The function takes a single parameter,$DestRPSEndpoint, which is the endpoint of the FSxW instance.
The script first checks the current shadow copy status to see if it exists.
If the shadow copy exists, it then deletes the schedule by invoking the Remove-FSxShadowCopySchedule cmdlet on the remote FSxW instance.
The schedule can be easily recreated using Set-FSxShadowCopyschedule -DestRPSEndpoint $DestRPSEndpoint -DaysOfWeek Monday,Tuesday,Saturday -Time1 15:00 -Time2 17:00
#>

Function Remove-FSxShadowCopySchedule{
    Param(
            [string]$DestRPSEndpoint
        )

    # Get the current shadow copy status
    Write-Host "Getting shadow copy schedule" -ForeGroundColor Green
    $GetVSSStatus = (Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
    {
        Get-FsxShadowCopySchedule
    })
    Write-Host "Shadow copy status" $GetVSSStatus.Enabled
    if ( ($GetVSSStatus.Enabled -eq $false) -or ($GetVSSStatus.Enabled -ne "True") )
    { 
        # Write schedule to log file
        Write-Log -Level INFO -Message $GetVSSStatus
        # Delete the VSS schedule     
        $DeleteVSSSchedule = Invoke-Command -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Remove-FSxShadowCopySchedule -Confirm:$false
        }
        Write-Host "Volume shadow copy schedule deleted" $DeleteVSSSchedule -ForeGroundColor Green
    } 
    else {
        Write-Host "No existing shadow copy schedule found on the FSx instance." -ForeGroundColor Green
    }
}    
