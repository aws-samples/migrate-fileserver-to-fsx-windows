Function New-FSxDedupSchedule{
  Param(
    [string]$ScheduleName,
    [ValidateSet('Optimization','GarbageCollection')]
    [string]$ScheduleType,
    [string]$DestRPSEndpoint,
    [DateTime]$StartTime,
    [string]$DurationHours,
    [validateSet('Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun')]
    [string[]]$Days
  )
  
  # check if schedule exists
    
    $TestScheduleExists = $true
    Try 
    {
        Invoke-Command -Authentication Kerberos -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Get-FSxDedupSchedule -Name $Using:ScheduleName -Type $Using:ScheduleType
        }
    }
    Catch 
    {
        If ($_.Exception.ToString().Contains("No matching MSFT_DedupJobSchedule objects found by CIM query for instances of the ROOT/Microsoft/Windows/Deduplication/MSFT_DedupJobSchedule")) {
            $TestScheduleExists = $false
            $Error.Clear()
        }
        Else
        {
            Write-Host "Failure - Failed to retrieve the schedule with the following error: $($_.Exception)" -ForegroundColor Red
        }
    }

  If ($TestScheduleExists) {
    # update logic 
    Try 
    {
        
        Write-Host $ScheduleType "schedule exists, setting it to" $StartTime -ForegroundColor Green
        Invoke-Command -Authentication Kerberos -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Set-FSxDedupSchedule -Name $Using:ScheduleName -Type $Using:ScheduleType -Start $Using:StartTime -Days $Using:Days -Cores 80 -DurationHours $Using:DurationHours -Memory 80 -Priority High -Enabled $True
        }
        # Get RAM CORES and START time
        $GetSchedule = Invoke-Command -Authentication Kerberos -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Get-FSxDedupSchedule -Name $Using:ScheduleName -Type $Using:ScheduleType
        }
        Write-Output $GetSchedule
    }Catch {
        Write-Host "Failure - Failed to update or create a schedule to manually trigger the $ScheduleType schedule with the following error: $($_.Exception)"
    }
  }
  Else {
   # create logic
   Write-Host $ScheduleType "does not exist, creating new one to start at" $StartTime -ForegroundColor Green
   Invoke-Command -Authentication Kerberos -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ScriptBlock `
   {
       New-FSxDedupSchedule -Name $Using:ScheduleName -Type $Using:ScheduleType -Start $Using:StartTime -Days $Using:Days -Cores 80 -DurationHours $Using:DurationHours -Memory 80 -Priority High
   }
  }
  
}

