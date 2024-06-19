#########################################################################
# 2 # COPY DATA TO FSx USING ROBOCOPY
#########################################################################
# If use robocopy variable is set to true, then copy each folder using robocopy
if ($UseRoboCopyForDataTransfer){
    # Mount FSx as a drive letter so we can copy the file server data to FSx 
    net use $FSxDriveLetter \\$FSxDNSName\D$

    foreach ($SourceFolder in $ShareRootFolder){
        # Copy the root folder from the Source File Server to FSx D:
        robocopy $SourceFolder $FSxDriveLetter\ /copy:DATSOU /secfix /e /b /MT:32 /XD '$RECYCLE.BIN' "System Volume Information" /V /TEE /LOG+:$LogLocation
    } 

}