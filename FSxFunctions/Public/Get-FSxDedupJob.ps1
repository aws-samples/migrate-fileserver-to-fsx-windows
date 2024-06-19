Function Get-FSxDedupJob{
    Param(
        [int]$IterationNumber,
        [DateTime]$StartTime,
        [ValidateSet('Optimization','GarbageCollection')]
        [string]$ScheduleType,
        [string]$DestRPSEndpoint,
        [int]$TimeBetweenCheckingJobStatus,
        [int]$Iterations
    )
    Write-Host "Waiting for start time before we check if the job ran" -ForegroundColor Green
  
  # job status check logic
  ###################
  #Get Garbage status
  ###################
  $TimeNow = (get-date)
  Write-Host "TimeNow is:" $TimeNow -ForeGroundColor Green
  Write-Host "StarTime is:" $StartTime -ForeGroundColor Green

  while ($GetDate -lt $StartTime)
  {
      $GetDate = Get-Date
  }
  Write-Host "Retrieving the job every $TimeBetweenCheckingJobStatus seconds to check whether the it has completed."
  # Wait for Garbage collection
  $IterationNumber = 0
  $TotalNumberOfIterations = $Iterations
  # Log additional details during job status checks
 
  While ($IterationNumber -lt $TotalNumberOfIterations) 
  {
      Try 
      {
          $Job = Invoke-Command -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ErrorAction Continue -ScriptBlock{
              Get-FSxDedupJob -Type $Using:ScheduleType 
          }
          if($Job.Progress -lt 50){
                      Write-Host "Job is in early phases"
                      Write-Host "Job progress is:" $Job.Progress -ForegroundColor Green
                      
                    }
                    elseif($Job.Progress -ge 50 -and $Job.Progress -lt 90){
                      Write-Host "Job is over halfway complete" 
                      $JobStarted = $true
                    }
                    else{
                      Write-Host "Job is in late phases"
                    }
                    
          $Job = Invoke-Command -ComputerName ${DestRPSEndpoint} -ConfigurationName FSxRemoteAdmin -ErrorAction Continue -ScriptBlock{
              Get-FSxDedupJob -Type $Using:ScheduleType

          }

          if ($Job.Progress -eq 100)
          {
              Write-Host "Garbage Job progress is:" $Job.Progress -ForegroundColor Green
              break
          }
          
      } 
      Catch 
      {
          If ($_.Exception.ToString().Contains(" No matching MSFT_DedupJob objects found by CIM query for instances of the ROOT/Microsoft/Windows/Deduplication/MSFT_DedupJob")) 
          {
              Write-Host "Job ended before we could get a progress bar" -ForegroundColor Green
              
              If ($JobStarted) 
              {
                  $Error.Clear()
                  break
              }
              break
          }
          Else
          {
              Write-Host "Failure - Failed to retrieve the job with the following error: $($_.Exception)"
          }
      }
      Start-Sleep -Seconds $TimeBetweenCheckingJobStatus
      $IterationNumber++
  }
  
}