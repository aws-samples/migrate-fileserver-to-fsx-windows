## PowerShell Module: FSxFunctions

These PowerShell scripts are part of a module called "FSxFunctions" that provides a set of utilities for managing various aspects of an Amazon FSx for Windows File Server (FSxW) environment, such as shadow copy schedules, deduplication configurations, and deduplication job monitoring.

The "FSxFunctions" PowerShell module contains the following files in the "Public" folder:

### 1. `Remove-FSxShadowCopySchedule.ps1`
- This script contains a function called `Remove-FSxShadowCopySchedule` that deletes the volume shadow copy schedule on an Amazon FSx for Windows File Server (FSxW) endpoint.
- The function takes a single parameter, `$DestRPSEndpoint`, which is the endpoint of the FSxW instance.
- The script first checks the current shadow copy status to see if it is exists. If the shadow copy is enabled, it then deletes the schedule by invoking the `Remove-FSxShadowCopySchedule` cmdlet on the remote FSxW instance.
- This function should not be necessary during the initial migration to FSx as there should not be any existing shadow copy schedules on the new FSx instance. However, it is included here in case you need to manage the shadow copy schedules after the migration is complete.
- The schedule can be easily recreated using `Set-FSxShadowCopyschedule -DestRPSEndpoint $DestRPSEndpoint -DaysOfWeek Monday,Tuesday,Saturday -Time1 15:00 -Time2 17:00`

### 2. `Get-FSxDedupConfig.ps1`
- This script contains a function called `Get-FSxDedupConfig` that retrieves the deduplication configuration settings for an FSxW endpoint.
- The function takes a single parameter, `$DestRPSEndpoint`, which is the endpoint of the FSxW instance.
- The script retrieves the deduplication configuration settings, including the status, schedule, and other relevant details, and returns the information as an object.

### 3. `Remove-FSxDedupSchedule.ps1`
- This script contains a function called `Remove-FSxDedupSchedule` that removes a custom deduplication schedule from an FSxW endpoint.
- The function takes two parameters: `$DestRPSEndpoint` (the FSxW endpoint) and `$ScheduleName` (the name of the schedule to be removed).
- The script first checks if the specified schedule exists, and if so, it disables and removes the schedule.

### 4. `New-FSxDedupSchedule.ps1`
- This script contains a function called `New-FSxDedupSchedule` that creates a new custom deduplication schedule on an FSxW endpoint.
- The function takes several parameters, including `$ScheduleName`, `$ScheduleType` (either "Optimization" or "GarbageCollection"), `$DestRPSEndpoint`, `$StartTime`, `$Days`, and `$DurationHours`.
- The script creates the new schedule with the specified parameters and enables it on the remote FSxW instance.

### 5. `Get-FSxDedupJob.ps1`
- This script contains a function called `Get-FSxDedupJob` that retrieves information about a deduplication job running on an FSxW endpoint.
- The function takes several parameters, including `$IterationNumber`, `$StartTime`, `$ScheduleType`, `$DestRPSEndpoint`, `$TimeBetweenCheckingJobStatus`, and `$Iterations`.
- The script monitors the deduplication job, displaying a progress bar, and returns the job status when the job is complete.

### 6. `Get-FSxDedupStatus.ps1`
- This script contains a function called `Get-FSxDedupStatus` that retrieves the current deduplication status for an FSxW endpoint.
- The function takes two parameters: `$ScheduleType` (either "Optimization" or "GarbageCollection") and `$DestRPSEndpoint`.
- The script retrieves the deduplication status, including the overall status, progress, and other relevant details, and returns the information as an object.

### 7. `Disable-DedupConfig.ps1`
- This script contains a function called `Disable-DedupConfig` that disables the deduplication configuration on an FSxW endpoint.
- The function takes a single parameter, `$DestRPSEndpoint`, which is the endpoint of the FSxW instance.
- The script disables the deduplication configuration on the remote FSxW instance.

### 8. `Set-FSxShadowCopyschedule.ps1`
- This script contains a function called `Set-FSxShadowCopyschedule` that sets the volume shadow copy schedule on an FSxW endpoint.
- The function takes several parameters, including `$DaysOfWeek`, `$Time1`, `$Time2`, and `$DestRPSEndpoint`.
- The script enables the volume shadow copy feature if it's not already enabled, and then sets the new schedule with the specified parameters.
