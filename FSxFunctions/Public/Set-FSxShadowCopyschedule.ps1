 # New FSx shadow copy schedule
 Function Set-FSxShadowCopyschedule{
    Param(
            [ValidateSet("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")]
            [string[]]$DaysOfWeek,
            [DateTime]$Time1, 
            [DateTime]$Time2, 
            [string]$DestRPSEndpoint
    )
    
        # Check if VSS is enabled if not enable 
        Write-Host "Checking if VSS is enabled and if not enable it" -foregroundcolor Green
        $GetVSSStatus = (Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock {Get-FsxShadowStorage})
         
        if ( ($GetVSSStatus.Enabled -eq $false) -or ($GetVSSStatus.Enabled -ne "True") )
        {
            Write-Host "Enabling Volume Shadow Copy Storage..." -ForeGroundColor Green   
            Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock {Set-FsxShadowStorage -Default}
        }else{
                Write-Host "Volume Shadow Copies already enabled!" -ForeGroundColor Green
             } 

         # New VSS schedule for FSx 
         Write-Host "Setting trigger 1 time to $Time1" -ForegroundColor Green
         Write-Host "Setting DaysOfWeek to $DaysOfWeek" -ForegroundColor Green
         $trigger1 = new-scheduledTaskTrigger -weekly -DaysOfWeek $DaysOfWeek -At $Time1
         Write-Host "Setting trigger 2 time to $Time2" -ForegroundColor Green
         $trigger2 = new-scheduledTaskTrigger -weekly -DaysOfWeek $DaysOfWeek -At $Time2
         

         $NewVSSSchedule =  Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
         { 
            Set-FSxShadowCopyschedule -scheduledtasktriggers $Using:trigger1,$Using:trigger2 -Confirm:$false
         } 
                 
         # View schedule
         Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
         { 
            Get-FsxShadowCopySchedule
         }
        
} 






