<#
The script is designed to copy data from the source file server to the FSx (Amazon FSx for Windows File Server) instance using the Robocopy tool.
It maps the FSx drive letter and then copies the data from the $ShareRootFolder to the FSx drive using the Robocopy command.
The Robocopy command uses various parameters to ensure a robust and efficient data transfer, such as copy:DATSOU to copy data, timestamps, and security, /secfix to fix security,
/e to copy subdirectories, /b to copy files in Backup mode, /MT:32 to use 32 multithreaded copies, 
/XD to exclude specific directories, and /V /TEE /LOG+ to provide verbose output, display progress, and append the log to a file.
#>
#########################################################################
# COPY DATA TO FSx USING ROBOCOPY
#########################################################################
# Mount FSx as a drive letter so we can copy the file server data to FSx 
Write-Host "Creating drive letter mapping" -ForegroundColor Green
New-PSDrive -Name $FSxDriveLetter.TrimEnd(':') -PSProvider FileSystem -Root "\\$FSxDNSName\D$" -Persist
    # If $ShareRootFolder = "C:\share1","D:\" The script will loop through each top level folder "C:\share1","D:\" and use robocopy to copy all subfolders located inside share1 and D:\
    # Default log location is C:\RoboCopy.log
    $logFilePath = Join-Path -Path $LogLocation -ChildPath "Robocopy.log"
    foreach ($SourceFolder in $ShareRootFolder){
        robocopy $SourceFolder $FSxDriveLetter\ /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:"$logFilePath"
    }  

