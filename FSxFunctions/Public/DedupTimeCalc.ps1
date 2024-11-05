# General Purpose File Server (GPFS) workload volume size estimation
# TotalVolumeSizeGB = total size in GB of all volumes that host data to be deduplicated
# DailyChurnPercentage = percentage of data churned (new data or modified data) daily
# OptimizationThroughputMB = measured/estimated optimization throughput in MB/s
# DailyOptimizationWindowHours = 24 hours for background mode deduplication, or daily schedule length for throughput optimization
# DeduplicationSavingsPercentage = measured/estimated deduplication savings percentage (0.00 – 1.00)
# FreeSpacePercentage = it is recommended to always leave some amount of free space on the volumes, such as 10% or twice the expected churn

Write-Host "General File Server workload volume size estimation"
[int] $TotalVolumeSizeGB = Read-Host 'Total Volume Size (in GB)'
$DailyChurnPercentage = Read-Host 'Percentage data churn (example 5 for 5%)'
$OptimizationThroughputMB = Read-Host 'Optimization Throughput (in MB/s)'
$DailyOptimizationWindowHours = Read-Host 'Daily Optimization Window (in hours)'
$DeduplicationSavingsPercentage = Read-Host 'Deduplication Savings percentage (example 70 for 70%)'
$FreeSpacePercentage = Read-Host 'Percentage allocated free space on volume (example 10 for 10%)'

# Convert to percentage values
$DailyChurnPercentage = $DailyChurnPercentage/100
$DeduplicationSavingsPercentage = $DeduplicationSavingsPercentage/100
$FreeSpacePercentage = $FreeSpacePercentage/100

# Total logical data size
$DataLogicalSizeGB = $TotalVolumeSizeGB * (1 - $FreeSpacePercentage) / (1 - $DeduplicationSavingsPercentage)

# Data to optimize daily
$DataToOptimizeGB = $DailyChurnPercentage * $DataLogicalSizeGB

# Time required to optimize data
$OptimizationTimeHours = ($DataToOptimizeGB / $OptimizationThroughputMB) * 1024 / 3600

# Number of volumes required
$VolumeCount = [System.Math]::Ceiling($OptimizationTimeHours / $DailyOptimizationWindowHours)

# Volume size
$VolumeSize = $TotalVolumeSizeGB / $VolumeCount

Write-Host "Data to optimize daily: $DataToOptimizeGB GB"
$OptimizationTimeHours = "{0:N2}" -f $OptimizationTimeHours
Write-Host "Hours required to optimize data: $OptimizationTimeHours"
Write-Host "$VolumeCount volume(s) of size $VolumeSize GB is recommended to process"
