<#
    The script is designed to copy data from the source file server to the FSx (Amazon FSx for Windows File Server) instance using the Robocopy tool.
    It maps the FSx drive letter and then copies the data from the $ShareRootFolder to the FSx drive using the Robocopy command.
    The Robocopy command uses various parameters to ensure a robust and efficient data transfer, such as copy:DATSOU to copy data, timestamps, and security, /secfix to fix security,
    /e to copy subdirectories, /b to copy files in Backup mode, /MT:32 to use 32 multithreaded copies, 
    /XD to exclude specific directories, and /V /TEE /LOG+ to provide verbose output, display progress, and append the log to a file.

    /copy:DATSOU: Copies data, attributes, timestamps, and security.
    /secfix: Fixes file and directory security on all copied files.
    /e: Copies subdirectories, including empty ones.
    /b: Copies files in Backup mode.
    /MT:32: Uses 32 multithreaded copies.
    /XD: Excludes specific directories, in this case, '$RECYCLE.BIN' and 'System Volume Information'.
    /V: Provides verbose output.
    /TEE: Displays the Robocopy output to the console.
    /LOG+: Appends the Robocopy log to the specified file.

#>
#########################################################################
# COPY DATA TO FSx USING ROBOCOPY
#########################################################################
Write-Host "Creating drive letter mapping" -ForegroundColor Green
New-PSDrive -Name $FSxDriveLetter.TrimEnd(':') -PSProvider FileSystem -Root "\\$FSxDNSName\D$" -Persist

# Default log location is C:\RoboCopy.log
$logFilePath = Join-Path -Path $LogLocation -ChildPath "Robocopy.log"

# $ShareRootFolder is an array of strings
foreach ($SourceFolder in $ShareRootFolder) {
    # Check if the $SourceFolder is shared on the network
    $isShared = Get-SmbShare -Path $SourceFolder -ErrorAction SilentlyContinue
    if ($isShared) {
        # Top-level folder is shared on the network, copy the entire folder structure
        # By removing the trailing backslash from the destination path ($FSxDriveLetter), the Robocopy command will copy the entire $SourceFolder directory structure, 
        # including the top-level folder, to the specified destination.
        Write-Host "Copying shared top-level folder: $SourceFolder" -ForegroundColor Green
        robocopy $SourceFolder $FSxDriveLetter /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$logFilePath"
    } else {
        # Top-level folder is not shared on the network, copy the subfolders only
        Write-Host "Copying subfolders of non-shared top-level folder: $SourceFolder" -ForegroundColor Green
        robocopy $SourceFolder $FSxDriveLetter\ /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$logFilePath"
    }
}
