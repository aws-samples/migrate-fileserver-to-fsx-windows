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
