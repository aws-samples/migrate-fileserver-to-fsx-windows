Function Remove-FSxDedupSchedule{
    Param(
        [string]$ScheduleName,
        [string]$DestRPSEndpoint
    )
    # Remove exising schedules
    Write-Host "Removing $ScheduleName and setting BackgroundOptimization top disabled" -ForegroundColor Green
    Try
    {
        Write-Host "Disabling BackgroundOptimization" -ForegroundColor Green
        Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Set-FSxDedupSchedule -Name "BackgroundOptimization" -Enabled $false
        }
        Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Remove-FSxDedupSchedule -Name $Using:ScheduleName
        }
    }
    Catch
    {
       If ($_.Exception.ToString().Contains(" MSFT_DedupSchedule.Name='BackgroundOptimization")) 
        {
            Write-Host "Deleted $ScheduleName" -ForegroundColor Green
            $Error.Clear()
        }
    }
}
