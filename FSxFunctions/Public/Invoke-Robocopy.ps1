<#
The function takes several parameters, including the $SourceFolder (an array of source folders), $FSxDriveLetter, $FSxDNSName, $LogLocation, and 
$UseRoboCopyForDataTransfer (a boolean flag to control whether Robocopy should be used).
The function first dot-sources the Write-Log.ps1 module to have access to the Write-Log function.
The main logic of the function is contained within the if statement that checks the value of $UseRoboCopyForDataTransfer. 
If it's $true, the function proceeds to mount the FSx drive and execute the Robocopy command for each source folder. 
If $UseRoboCopyForDataTransfer is $false, the function logs a message and skips the Robocopy data transfer.
Invoke-Robocopy -SourceFolder $SourceFolder -FSxDriveLetter $FSxDriveLetter -FSxDNSName $FSxDNSName -LogLocation $LogLocation -UseRoboCopyForDataTransfer $UseRoboCopyForDataTransfer
#>

function Invoke-Robocopy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$SourceFolder,
        [Parameter(Mandatory = $true)]
        [string]$FSxDriveLetter,
        [Parameter(Mandatory = $true)]
        [string]$FSxDNSName,
        [Parameter(Mandatory = $true)]
        [string]$LogLocation,
        [Parameter(Mandatory = $true)]
        [bool]$UseRoboCopyForDataTransfer
    )

    if ($UseRoboCopyForDataTransfer) {
        # Mount FSx as a PSDrive so we can copy the file server data to FSx
        New-PSDrive -Name $FSxDriveLetter.TrimEnd(':') -PSProvider FileSystem -Root "\\$FSxDNSName\D$" -Persist

        foreach ($sourceFolder in $SourceFolder) {
            # Copy the root folder from the Source File Server to FSx D:
            robocopy $sourceFolder "$($FSxDriveLetter.TrimEnd(':'))\" /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$LogLocation"
        }

        # Disconnect the PSDrive
        Remove-PSDrive -Name $FSxDriveLetter.TrimEnd(':')
    }
    else {
        Write-Log -Level INFO -Message "UseRoboCopyForDataTransfer is set to false, skipping Robocopy data transfer."
    }
}
