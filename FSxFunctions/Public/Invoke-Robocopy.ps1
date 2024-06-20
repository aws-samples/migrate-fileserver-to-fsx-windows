<#
    Non-Deduplication Scenario:
    If $DedupEnabled is $false, the function simply copies the folder using Robocopy, without any deduplication-related logic.
    It does not perform any calculations or updates to the available free space on the FSx instance, as the deduplication factor is not relevant in this scenario.
    Deduplication Scenario:
    If $DedupEnabled is $true, the function performs the following steps:
    Calculates the folder size using the Get-FolderSize function.
    Calculates the raw data size by multiplying the folder size by the $DedupFactor.
    Checks if the raw data size is less than or equal to the available free space on the FSx instance.
    If true, it copies the folder using Robocopy and then calls the DedupFunctionRunner.ps1 script to handle the deduplication tasks.
    If false, it splits the folder into smaller chunks (up to the $MaxTransferSize limit) and copies each chunk, running the deduplication tasks after each chunk.
    After each copy and deduplication operation, it subtracts the raw data size from the available free space on the FSx instance.
    
    The function starts by mounting the FSx instance as a PSDrive using the New-PSDrive cmdlet.
    Iterate Through Source Folders:
    The function then loops through each source folder specified in the $SourceFolders parameter.
    Disconnect the PSDrive:
    After processing all the source folders, the function disconnects the PSDrive using the Remove-PSDrive cmdlet.
    
    The script leverages the DedupFunctionRunner.ps1 script to handle the deduplication-related tasks, keeping the Invoke-Robocopy function focused on the data transfer process.

#>
function Get-FolderSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $folderSize = (Get-ChildItem -Path $Path -Recurse | Measure-Object -Property Length -Sum).Sum
    return $folderSize
}

function Invoke-Robocopy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$SourceFolders,
        [Parameter(Mandatory = $true)]
        [string]$FSxDriveLetter,
        [Parameter(Mandatory = $true)]
        [string]$FSxDNSName,
        [Parameter(Mandatory = $true)]
        [string]$LogLocation,
        [Parameter(Mandatory = $true)]
        [int]$FSxTotalSpaceGB,
        [Parameter(Mandatory = $true)]
        [int]$DedupFactor,
        [Parameter(Mandatory = $true)]
        [int]$MaxTransferSizeGB,
        [Parameter(Mandatory = $true)]
        [bool]$DedupEnabled
    )

    . $PSScriptRoot\Write-Log.ps1

    # Mount FSx as a PSDrive
    New-PSDrive -Name $FSxDriveLetter.TrimEnd(':') -PSProvider FileSystem -Root "\\$FSxDNSName\D$" -Persist

    $freeSpaceOnFSx = $FSxTotalSpaceGB
    foreach ($sourceFolder in $SourceFolders) {
        if ($DedupEnabled)
        {
            $folderSizeGB = [math]::Round((Get-FolderSize -Path $sourceFolder) / 1GB, 2)
            $rawDataSizeGB = $folderSizeGB * $DedupFactor

            if ($rawDataSizeGB -le $freeSpaceOnFSx) {
                # Copy the folder using Robocopy
                robocopy $sourceFolder "$($FSxDriveLetter.TrimEnd(':'))\" /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$LogLocation"

                # Run deduplication
                . $PSScriptRoot\DedupFunctionRunner.ps1

                $freeSpaceOnFSx -= $rawDataSizeGB
                Write-Host "Copied $sourceFolder. Free space on FSx: $freeSpaceOnFSx GB" -ForegroundColor Green
            }
            else 
            {
                # If the folder size exceeds the available free space, split it into smaller chunks
                $chunkSizeGB = [math]::Floor($freeSpaceOnFSx / $DedupFactor)
                $chunkSizeGB = [math]::Min($chunkSizeGB, $MaxTransferSizeGB)

                if ($chunkSizeGB -gt 0) 
                {
                    $numChunks = [math]::Ceiling($folderSizeGB / $chunkSizeGB)
                    for ($i = 0; $i -lt $numChunks; $i++)
                    {
                        $chunkStartIndex = $i * ($chunkSizeGB * 1GB)
                        $chunkEndIndex = [math]::Min(($i + 1) * ($chunkSizeGB * 1GB), $folderSizeGB * 1GB)
                        $chunkPath = "$sourceFolder\Chunk$i"
                        New-Item -ItemType Directory -Path $chunkPath | Out-Null
                        robocopy $sourceFolder $chunkPath /MOVE /MAXSIZE:$($chunkSizeGB * 1GB) /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$LogLocation"

                        # Run deduplication
                        . $PSScriptRoot\DedupFunctionRunner.ps1
                        
                        $freeSpaceOnFSx -= $chunkSizeGB
                        Write-Host "Copied chunk $($i+1) of $sourceFolder. Free space on FSx: $freeSpaceOnFSx GB" -ForegroundColor Green
                    }
                }
                else 
                {
                    Write-Host "Not enough free space on FSx to copy $sourceFolder" -ForegroundColor Red
                }
            }
        }
        else 
        {
            # If deduplication is not enabled, copy the folder without any dedup logic
            robocopy $sourceFolder "$($FSxDriveLetter.TrimEnd(':'))\" /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$LogLocation"
        }
    }

    # Disconnect the PSDrive
    Remove-PSDrive -Name $FSxDriveLetter.TrimEnd(':')
}
