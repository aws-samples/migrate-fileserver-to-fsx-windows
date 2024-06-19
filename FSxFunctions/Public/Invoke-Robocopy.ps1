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
        [int]$FSxTotalSpace,
        [Parameter(Mandatory = $true)]
        [int]$DedupFactor,
        [Parameter(Mandatory = $true)]
        [int]$MaxTransferSize,
        [Parameter(Mandatory = $true)]
        [bool]$DedupEnabled
    )

    . $PSScriptRoot\Write-Log.ps1

    # Mount FSx as a PSDrive
    New-PSDrive -Name $FSxDriveLetter.TrimEnd(':') -PSProvider FileSystem -Root "\\$FSxDNSName\D$" -Persist

    $freeSpaceOnFSx = $FSxTotalSpace
    foreach ($sourceFolder in $SourceFolders) {
        if ($DedupEnabled)
        {
            $folderSize = Get-FolderSize -Path $sourceFolder
            $rawDataSize = $folderSize * $DedupFactor

            if ($rawDataSize -le $freeSpaceOnFSx) {
                # Copy the folder using Robocopy
                robocopy $sourceFolder "$($FSxDriveLetter.TrimEnd(':'))\" /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$LogLocation"

                # Run deduplication
                . $PSScriptRoot\DedupFunctionRunner.ps1

                $freeSpaceOnFSx -= $rawDataSize
                Write-Host "Copied $sourceFolder. Free space on FSx: $freeSpaceOnFSx GB" -ForegroundColor Green
            }
            else 
            {
                # If the folder size exceeds the available free space, split it into smaller chunks
                $chunkSize = [math]::Floor($freeSpaceOnFSx / $DedupFactor)
                $chunkSize = [math]::Min($chunkSize, $MaxTransferSize)

                if ($chunkSize -gt 0) 
                {
                    $numChunks = [math]::Ceiling($folderSize / $chunkSize)
                    for ($i = 0; $i -lt $numChunks; $i++)
                    {
                        $chunkStartIndex = $i * $chunkSize
                        $chunkEndIndex = [math]::Min(($i + 1) * $chunkSize, $folderSize)
                        $chunkPath = "$sourceFolder\Chunk$i"
                        New-Item -ItemType Directory -Path $chunkPath | Out-Null
                        robocopy $sourceFolder $chunkPath /MOVE /MAXSIZE:$chunkSize /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$LogLocation"

                        # Run deduplication
                        . $PSScriptRoot\DedupFunctionRunner.ps1

                        $freeSpaceOnFSx -= $chunkSize * $DedupFactor
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
            Write-Host "Copied $sourceFolder. Free space on FSx: $freeSpaceOnFSx GB" -ForegroundColor Green
        }
    }

    # Disconnect the PSDrive
    Remove-PSDrive -Name $FSxDriveLetter.TrimEnd(':')
}
