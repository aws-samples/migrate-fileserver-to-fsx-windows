<#
This PowerShell script is designed to optimize and manage the data deduplication (dedup) and volume shadow copy (VSS) settings for an Amazon FSx for Windows File Server instance.

The key components of the script are:
Configuration Variables: The script starts by defining several variables, including the destination RPS (Remote PowerShell) endpoint, the start time for the optimization and garbage collection tasks, 
the days of the week to schedule the tasks, and the path to the custom functions module.

Time Zone Check: The script checks if the server's time zone is set to UTC, as this is a requirement for the scheduled tasks.

Disable Volume Shadow Copy Schedule: The script disables the existing volume shadow copy schedule on the FSx instance.

Dedup Configuration: The script enables the dedup feature on the FSx instance and removes any existing custom dedup schedules.

Optimization Task: The script creates a custom dedup optimization schedule, runs the optimization task, and then removes the custom schedule.

Garbage Collection Task: The script creates a custom dedup garbage collection schedule, runs the garbage collection task, and then removes the custom schedule.

Reenable Background Optimization: The script reenables the default dedup optimization schedule that runs in the background every hour.

Additional Actions: The script provides commented-out sections to disable the dedup configuration and recreate the volume shadow copy schedule, in case those actions are required.

This script is designed to be used in conjunction with the custom functions module defined in the $FunctionsFolderPath variable. 
The functions module should contain the implementation of the cmdlets used in this script, such as Remove-FSxShadowCopySchedule, Get-FSxDedupConfig, New-FSxDedupSchedule, and so on.
#>
################ Edit below ########################################
$DestRPSEndpoint = "amznfsxdg7fl4ex.mytestdomain.local" 

# Start Optimization 20 seconds from now UTC time
$StartTime = (Get-Date).AddSeconds(20)

#$Days = "Mon","Tues","Wed","Thurs","Fri","Sat","Sun"
$Days = "Sat"

$ScheduleName = "CustomOptimize" # As long as its not called Optimize which will overwrite the default

# Place the function files in a folder and list the path here
$FunctionsFolderPath = "$($env:USERPROFILE)\Documents\FSxFunctions"

####################################################################

# Check if server time zone is UTC
$tz = (Get-TimeZone).Id

if($tz -ne "UTC"){
  Write-Host "ERROR please set time zone to UTC" -ForeGroundColor Red
  exit 1
}

# cd to this directory and run the following
cd $FunctionsFolderPath
Import-Module .\FSxFunctions.psm1 -Verbose

# Disable Volume Shadow Schedule while we migrate
<#
This script contains a function called Remove-FSxShadowCopySchedule
that deletes the volume shadow copy schedule on an Amazon FSx for Windows File Server (FSxW) endpoint.

This function should not be necessary during the initial migration to FSx
as there should not be any existing shadow copy schedules on the new FSx instance.
However, it is included here in case you need to manage the shadow copy schedules after the migration is complete.

The function takes a single parameter,$DestRPSEndpoint, which is the endpoint of the FSxW instance.
The script first checks the current shadow copy status to see if it exists.
If the shadow copy exists, it then deletes the schedule by invoking the Remove-FSxShadowCopySchedule cmdlet on the remote FSxW instance.
The schedule can be easily recreated using Set-FSxShadowCopyschedule -DestRPSEndpoint $DestRPSEndpoint -DaysOfWeek Monday,Tuesday,Saturday -Time1 15:00 -Time2 17:00
#>
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
<#
The `Get-FSxDedupJob` command can be broken down as follows:
1. `Get-FSxDedupJob`: This is the name of the function that retrieves information about a deduplication job running on an Amazon FSx for Windows File Server (FSxW) endpoint.
2. `-IterationNumber 1`: This parameter specifies the iteration number of the deduplication job to retrieve. In this case, it's set to 1, which means the function will retrieve information about the first iteration of the job.
3. `-StartTime $StartTime`: This parameter specifies the start time of the deduplication job. The `$StartTime` all variables are set at the top of this script and passed to this function.
4. `-ScheduleType $ScheduleType`: This parameter specifies the type of deduplication schedule the job is running under. It can be either "Optimization" or "GarbageCollection". The `$ScheduleType`.
5. `-DestRPSEndpoint $DestRPSEndpoint`: This parameter specifies the endpoint of the FSxW instance where the deduplication job is running. The `$DestRPSEndpoint` 
6. `-TimeBetweenCheckingJobStatus 5`: This parameter specifies the number of seconds to wait between checking the status of the deduplication job. In this case, it's set to 5 seconds.
7. `-Iterations 4`: This parameter specifies the number of iterations the function should monitor the deduplication job. In this case, it's set to 4, meaning the function will check the job status 4 times before returning the final status.
#>
Get-FSxDedupJob -IterationNumber 1 -StartTime $StartTime -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint -TimeBetweenCheckingJobStatus 5 -Iterations 4

# Get Status
Get-FSxDedupStatus -ScheduleType $ScheduleType -DestRPSEndpoint $DestRPSEndpoint 

# Remove custom schedule now that we done using it. Does not change the default schedules and disables BackgroundOptimization schedule
# So, when you run this command, it will Connect to the FSxW endpoint specified by the $DestRPSEndpoint variable.
# Locate the deduplication schedule with the name specified by the $ScheduleName variable.
# Disable and remove the specified deduplication schedule from the FSxW instance.

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

# Uncomment and run Disable-DedupConfig if you want to Disable Dedup Config on FSx
#Disable-DedupConfig -DestRPSEndpoint $DestRPSEndpoint

# Uncomment to recreate a Volume Shadow Copy Schedule
#Set-FSxShadowCopyschedule -DestRPSEndpoint $DestRPSEndpoint -DaysOfWeek Monday,Tuesday,Saturday -Time1 15:00 -Time2 17:00
