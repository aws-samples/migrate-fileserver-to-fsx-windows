Function Disable-DedupConfig {
     Param(
            [string]$DestRPSEndpoint
          )
        # Check deduplication status
        Write-Host "Checking if dedupe is enabled and if not enable it" -foregroundcolor Green
        $GetDedupeStatus = (Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock {Get-FSxDedupConfiguration})
        Write-Host "Dedup status is" $GetDedupeStatus -foregroundcolor Green 

        if ($GetDedupeStatus.Enabled -eq $true) 
        {
            Write-Host "Disabling data deduplication..." -ForeGroundColor Green   
            Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
            {
                Set-FSxDedupSchedule -Name "BackgroundOptimization" -Enabled $false
                Disable-FsxDedup
            }
        }else 
            {
                Write-Host "Data deduplication already Disabled!" -ForeGroundColor Green
            }
        Write-Host "Check if Dedup schedules exists" -ForegroundColor Green     
        
                          
            Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
            {
                Get-FSxDedupSchedule
            }
            
}
