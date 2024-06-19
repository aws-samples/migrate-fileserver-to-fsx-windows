<#
The Get-DedupStatus function is retrieving deduplication status details from an Amazon FSx for Windows file system.

It takes the schedule type (Optimization or GarbageCollection) and remote powershell destination endpoint as parameters.

The status is retrieved via Invoke-Command to run Get-FSxDedupStatus remotely.

It then checks if the last schedule time set is less than the start time passed, meaing the date is behind  start time. 
(When query status, you get the old date from last successful run and it takes minutes to update)

The script loops/waits until "Last"+$ScheduleType+"Time" is Greater than or equal to start time 

The status details like optimized file counts, sizes and savings are returned.
#>
 Function Get-FSxDedupStatus{
    Param(
        [ValidateSet('Optimization','GarbageCollection')]
        [string]$ScheduleType,
        [string]$DestRPSEndpoint
    )
    # status retrieval logic
        <# Get-FSxDedupStatus
            OptimizedFilesCount OptimizedFilesSize SavedSpace OptimizedFilesSavingsRate
            ------------------- ------------------ ---------- -------------------------
                        12587           31163594   25944826                        83
        #>
    $Status = Invoke-Command -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
    {
        Get-FSxDedupStatus
    }
    $Type = "Last"+$ScheduleType+"Time"
    if ($Status.$Type -le $StartTime)
    {
        while ($Status.$Type -ge $StartTime)
        {
        
            Write-Host "Waiting for" $Status.$Type "to be greater than start time" $StartTime -ForeGroundColor Green
            Start-Sleep -Seconds 5
            Write-Host "Running Get-FSxDedupStatus to see if" + $Type + "status updated"
            $Status = Invoke-Command -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
            {
                Get-FSxDedupStatus
            }
            Write-Host $Status.$Type

        }
    }
    $Status | Select LastOptimizationTime,OptimizedFilesCount,OptimizedFilesSize,InPolicyFilesCount,InPolicyFilesSize,SavedSpace,OptimizedFilesSavingsRate 

}
