<#
This script contains a function called Get-FSxDedupConfig that retrieves the deduplication configuration,
settings for an FSxW endpoint. The function takes a single parameter,$DestRPSEndpoint, which is the endpoint of the FSxW instance.
The script retrieves the deduplication configuration settings, including the status, schedule, and 
other relevant details, and returns the information as an object.
#>
Function Get-FSxDedupConfig{
    Param(
        [string]$DestRPSEndpoint
    )
    # Check deduplication status
    Write-Host "Checking if dedupe is enabled and if not enable it" -foregroundcolor Green
    $GetDedupeStatus = (Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock {Get-FSxDedupConfiguration})
    
    if ( ($GetDedupeStatus.Enabled -eq $false) -or ($GetDedupeStatus.Enabled -ne "True") )
    {
        Write-Host "Enabling data deduplication..." -ForeGroundColor Green   
        Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock {Enable-FsxDedup}
    }else 
        {
            Write-Host "Data deduplication already enabled!" -ForeGroundColor Green
        }
    Write-Host "Check if min file age days is greater than 0 days and set it to 0 to catch all files" -ForegroundColor Green 
    Write-Host "Min file age days is" $GetDedupeStatus.MinimumFileAgeDays -ForegroundColor Green     
    if ($GetDedupeStatus.MinimumFileAgeDays -gt 0)
    {
        Write-Host "Setting min file age days to 0" -foregroundcolor Green
                          
        Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Set-FSxDedupConfiguration -MinimumFileAgeDays 0
        }

        Invoke-Command -ComputerName $DestRPSEndpoint -ConfigurationName FSxRemoteAdmin -ScriptBlock `
        {
            Get-FSxDedupSchedule
        }
            
    }
}
