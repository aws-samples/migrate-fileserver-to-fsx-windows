<#
    Mapping the FSx drive letter:
        The script uses the New-PSDrive cmdlet to map the FSx drive letter, making it accessible from the PowerShell session.
        The drive letter is specified by the $FSxDriveLetter variable, and the root of the drive is set to "\$FSxDNSName\D$".
        The -Persist parameter is used to make the drive letter mapping persistent across PowerShell sessions.

    Setting the log file path:
        The script sets the log file path for the Robocopy operation, which will be used to record the progress and details of the data transfer.
        The log file path is constructed by joining the $LogLocation variable and the filename "Robocopy.log".

    Iterating through the share root folders:
        The script loops through the $ShareRootFolder array, which contains the root folders to be copied.

    Checking for valid root locations:
        For each $Location in the $ShareRootFolder array that is an entire drive letter, the script checks if it is a valid root location (D:, E:, ..., Z:).
        It does this by checking if the $Location is in the $validLocations array.
        If the $Location is a valid root location, the script proceeds to copy the data using the Robocopy command.
        robocopy D:\ Z:\(FSxDriveLetter)

    Copying data for valid root locations:
        If the $Location is a valid root location, the script runs the Robocopy command with the following parameters:
            /copy:DATSOU: Copies data, attributes, timestamps, and security.
            /secfix: Fixes file and directory security on all copied files.
            /e: Copies subdirectories, including empty ones.
            /b: Copies files in Backup mode.
            /MT:32: Uses 32 multithreaded copies.
            /XD: Excludes the '$RECYCLE.BIN' and 'System Volume Information' directories.
            /V: Provides verbose output.
            /TEE: Displays the Robocopy output to the console.
            /LOG+: Appends the Robocopy log to the specified file.

    Handling subfolders:
        If the $Location is not a valid root location, the script assumes it is a subfolder and follows a different workflow.
        It sets the $SourcePath and $FolderName variables based on the $Location.
        It then checks if the $Location is a valid directory using the Test-Path cmdlet.
        If the $Location is a valid directory, the script runs the Robocopy command with the same parameters as in the valid root location workflow, but using the $SourcePath and $DestPath variables.
        If the $Location is not a valid directory, the script prints a warning message.


#>
 
# Map drive letter
Write-Host "Creating drive letter mapping" -ForegroundColor Green
New-PSDrive -Name $FSxDriveLetter.TrimEnd(':') -PSProvider FileSystem -Root "\\$FSxDNSName\D$" -Persist

# Default log location is C:\RoboCopy.log
$logFilePath = Join-Path -Path $LogLocation -ChildPath "Robocopy.log"

foreach ($Location in $ShareRootFolder){
    $validLocations = @("D:\", "E:\", "F:\", "G:\", "H:\", "I:\", "J:\", "K:\", "L:\", "M:\", "N:\", "O:\", "P:\", "Q:\", "R:\", "S:\", "T:\", "U:\", "V:\", "W:\", "X:\", "Y:\", "Z:\")
    Write-Output "testing if Location $Location is a valid root location"
    if ($Location -in $validLocations)
    {
        Write-Output "Location $Location is a valid root 2 root" 
        robocopy $Location $FSxDriveLetter /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$logFilePath"
    }else
    {
        Write-Host "Subfolder workflow" -ForegroundColor Red
        $SourcePath = $null
        $FolderName = Split-Path -Path $Location -Leaf
        $DestPath = Join-Path -Path $FSxDriveLetter -ChildPath $FolderName
    
        # Check if the $Location is a valid directory
        if (Test-Path -Path $Location -PathType Container)
        {
            $SourcePath = $Location
            # Copy top level folder and sub folders to FSx
            robocopy $SourcePath $DestPath /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$logFilePath"
        }
        else
        {
            Write-Host "Could not determine source path for $Location" -ForegroundColor Red
        }
    }

}
