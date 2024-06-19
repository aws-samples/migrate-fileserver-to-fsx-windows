<#
The script is designed to copy data from the source file server to the FSx (Amazon FSx for Windows File Server) instance using the Robocopy tool.
It first checks if the $UseRoboCopyForDataTransfer variable is set to $true. If so, it proceeds with the data transfer.
It maps the FSx drive letter and then copies the data from the $ShareRootFolder to the FSx drive using the Robocopy command.
The Robocopy command uses various parameters to ensure a robust and efficient data transfer, such as copy:DATSOU to copy data, timestamps, and security, /secfix to fix security,
/e to copy subdirectories, /b to copy files in Backup mode, /MT:32 to use 32 multithreaded copies, 
/XD to exclude specific directories, and /V /TEE /LOG+ to provide verbose output, display progress, and append the log to a file.
#>
#########################################################################
# COPY DATA TO FSx USING ROBOCOPY
#########################################################################
# If use robocopy variable is set to true, then copy each folder using robocopy. This variable is $true by default
if ($UseRoboCopyForDataTransfer){
    # Mount FSx as a drive letter so we can copy the file server data to FSx 
    net use $FSxDriveLetter \\$FSxDNSName\D$

    foreach ($SourceFolder in $ShareRootFolder){
        # Copy the root folder from the Source File Server to FSx D:
        robocopy $SourceFolder $FSxDriveLetter\ /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:$LogLocation
    } 

}
