## Edit below ##
$DestRPSEndpoint = "amznfsxdg7fl4ex.mytestdomain.local" 
# Start Optimization 20 seconds from now UTC time
$StartTime = (Get-Date).AddSeconds(20)
#$Days = "Mon","Tues","Wed","Thurs","Fri","Sat","Sun"
$Days = "Sat"
$ScheduleName = "CustomOptimize"
# Place the function files in a folder and list the path here
$FunctionsFolderPath = "$($env:USERPROFILE)\Documents\FSxFunctions"
############################################################

# Check if server time zone is UTC
$tz = (Get-TimeZone).Id

if($tz -ne "UTC"){
  Write-Host "ERROR please set time zone to UTC" -ForeGroundColor Red
  exit 1
}
# cd to this directory and run the following
cd $FunctionsFolderPath
Import-Module .\FSxFunctions.psm1 -Verbose

# Disable Volume Shadow Schedule
Remove-FSxShadowCopySchedule -DestRPSEndpoint $DestRPSEndpoint

# Enabled Dedup with the correct settings to catch all files 
# By design enables the default BackgroundOptimization schedule which we disable in next step
Get-FSxDedupConfig -DestRPSEndpoint $DestRPSEndpoint

# Remove all custom schedules except for the default and disables BackgroundOptimization schedule
Remove-FSxDedupSchedule -DestRPSEndpoint $DestRPSEndpoint -ScheduleName $ScheduleName

######################
#   Optimization     #
######################
# Create the Optimization Schedule by specifying schedule type 
$ScheduleType = "Optimization" # Valid values are GarbageCollection or Optimization
New-FSxDedupSchedule -ScheduleName $ScheduleName -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint -StartTime $StartTime -Days $Days -DurationHours 8
# Wait for optimize to complete and show progress bar
Get-FSxDedupJob -IterationNumber 1 -StartTime $StartTime -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint -TimeBetweenCheckingJobStatus 5 -Iterations 4
# Get Status
Get-FSxDedupStatus -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint 

# Remove custom schedule now that we done using it. Does not change the default schedules and disables BackgroundOptimization schedule
Remove-FSxDedupSchedule -DestRPSEndpoint $DestRPSEndpoint -ScheduleName $ScheduleName

######################
# Garbage Collection #
######################
Write-Host "Now setting up Garbage collection" -ForegroundColor Green
# Setting name and type to garbage
$ScheduleType = "GarbageCollection"
$ScheduleName = "CustomGarbage"
# Start the garbage collection 20 seconds from now
$StartTime = (Get-Date).AddSeconds(20)
Write-Output $ScheduleType

# Remove custom schedule in case it exists. Does not change the default schedules and disables BackgroundOptimization schedule
Remove-FSxDedupSchedule -DestRPSEndpoint $DestRPSEndpoint -ScheduleName $ScheduleName

# Create the custom Schedule by specifying schedule type 
New-FSxDedupSchedule -ScheduleName $ScheduleName -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint -StartTime $StartTime -Days $Days -DurationHours 8

# Wait for job to complete and show progress bar
Get-FSxDedupJob -IterationNumber 1 -StartTime $StartTime -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint -TimeBetweenCheckingJobStatus 5 -Iterations 4

# Get Status
Get-FSxDedupStatus -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint 

# Remove custom schedule now that we done using it. Does not change the default schedules and disables BackgroundOptimization schedule
Remove-FSxDedupSchedule -DestRPSEndpoint $DestRPSEndpoint -ScheduleName $ScheduleName

# Enable the default optimization schedule that runs every 1 hour in background 
Write-Host "Re-Enabling BackgroundOptimization" -ForegroundColor Green
Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
{
    Set-FSxDedupSchedule -Name "BackgroundOptimization" -Enabled $true
}

# Uncomment and run if you want to Disable Dedup Config
#Disable-DedupConfig -DestRPSEndpoint $DestRPSEndpoint

#Set-FSxShadowCopyschedule -DestRPSEndpoint $DestRPSEndpoint -DaysOfWeek Monday,Tuesday,Saturday -Time1 15:00 -Time2 17:00