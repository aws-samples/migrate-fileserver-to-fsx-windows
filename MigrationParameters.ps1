###############################
# EDIT THE FOLLOWING VARIABLES:
###############################
$DomainName = (Get-CimInstance -Class Win32_ComputerSystem -ComputerName $env:computername).Domain
# The DNS name of your destination FSx for Windows file system. amznfsxhkxyen.corp.example.com
$FSxDNSName = ""

# Drive letter will be used to mount FSx on this file server
$FSxDriveLetter = "Z:" 

# The FQDN of the endpoint “amznfsxzzzzzzzz.corp.example.com“ Amazon FSx CLI for remote management on PowerShell enables file system administration for users in the file system administrators group
$FSxDestRPSEndpoint = ""

# Alias uses a CNAME record to make things easiier for clients to remember i.e. \\fs1.mytestdomain.local instead of \\EC2AMAZ43567.mytestdomain.local
# Can be comma separated list enclosed in "fs1.dom.local","fs2.dom.local"
$Alias = "fs1.$DomainName" # must be in FQDN format and not the hostname of source file server

$LogLocation = "C:" # Log file and share config export location, do not include the \ if C:\ just put C:

# In the context of the file server migration, the script 1-CheckPermissions.ps1 checks if the built in local Administrators group "BUILTIN\Administrators" has been granted permissions on the shared folders. 
# This is important because local groups, such as the Administrators group, will not have the same level of access on the Amazon FSx for Windows, which is managed by domain-level groups.
# You can change the $LocalAdminGroup value here and run 1-CheckPermissions.ps1 again if your local admin group is not using the default name "BUILTIN\Administrators".
$LocalAdminGroup = "BUILTIN\Administrators"

# Replace with the Name of your domain administrators group AWS Managed AD is "AWS Delegated Administrators" and Self Managed is "Domain Admins" 
$DomainAdminGroup = "AWS Delegated Administrators" 

# $ShareRootFolder can be one or more locations, each location must be enclosed in double quotes "", for example if you have two locations use this format: "C:\share1","D:\" 
$ShareRootFolder = "C:\share1","D:\" 

# If $ShareRootFolder = "C:\share1","D:\" The script will robocopy top level folder "C:\share1","D:\" and all subfolders located inside share1 and D:\
# https://andys-tech.blog/2020/07/robocopy-is-mt-with-more-threads-faster/ 

# Getting Hostname of file server - no need to edit this
$FQDN = (Resolve-DnsName $(hostname) -Type A).Name

#####################################################
# DO NOT EDIT AFTER THIS LINE
#####################################################

# This will prompt for Credentials that have permission to create new shares on FSx, and access all folders on source files server, usually a user that is part of Domain Admins, File server admins or 
# AWS FSx delegated administrators if using AWS managed AD
if (-not $FSxAdminUserCredential -or $FSxAdminUserCredential.Password.Length -eq 0) {
    $FSxAdminUserCredential = Get-Credential -Message "Enter the credentials for the FSx administrator user"
}

# Generic Log function
<#

    Import-Module -Name $PSScriptRoot\Write-Log.ps1 -Verbose
    And then you can call the function like this:
    
    # Using the default log location
    Write-Log -Level INFO -Message "This is an informational message"
    
    # Specifying a custom log location
    Write-Log -Level ERROR -Message "This is an error message" -LogLocation "C:\Logs"
        
#>
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",
        [Parameter(Mandatory = $True)]
        [string]
        $Message,
        [Parameter(Mandatory = $False)]
        [string]
        $LogLocation = "$LogLocation"
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    $Logfilepath = "$LogLocation\FsxMigrate.log"

    # Create the log directory if it doesn't exist
    if (!(Test-Path $LogLocation)) {
        New-Item -ItemType Directory -Force -Path $LogLocation | Out-Null
    }

    # Create the log file if it doesn't exist
    if (!(Test-Path $Logfilepath)) {
        New-Item -ItemType File -Force -Path $Logfilepath | Out-Null
    }

    # Write the log message to the file
    Add-Content $Logfilepath -Value $Line
}

# Define the required variables
$requiredVars = @(
    "FSxDNSName",
    "FSxDriveLetter",
    "FSxDestRPSEndpoint",
    "LogLocation",
    "LocalAdminGroup",
    "DomainAdminGroup",
    "ShareRootFolder"
)

# Function to verify the variables
function Verify-Variables {
    $allVariablesSet = $true

    # Check each required variable
    foreach ($var in $requiredVars) {
        if (-not (Get-Variable -Name $var -ErrorAction SilentlyContinue)) {
            Write-Host "Variable '$var' is not set." -ForegroundColor Red
            $allVariablesSet = $false
        }
    }

    if ($allVariablesSet) {
        Write-Host "All required variables are set." -ForegroundColor Green
    } else {
        Write-Host "One or more required variables are not set." -ForegroundColor Red
    }

    return $allVariablesSet
}

# Call the Verify-Variables function
$allVariablesSet = Verify-Variables

# Validate the $DomainAdminGroup variable
try {
    $DomainAdminGroupObject = Get-ADGroup -Identity $DomainAdminGroup -ErrorAction Stop
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Log -Level ERROR -Message "The specified domain group '$DomainAdminGroup' was not found in Active Directory."
    Write-Host "The specified domain group '$DomainAdminGroup' was not found in Active Directory." -ForegroundColor Red
    exit 1
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log -Level ERROR -Message "An error occurred while validating the domain group: $ErrorMessage"
    Write-Host "An error occurred while validating the domain group: $ErrorMessage" -ForegroundColor Red
    exit 1
}
# Check if any folders might be listed as shares but are left behind or not included in the 
 $smbShares = Get-SMBShare

# Create a HashSet to store the unique top-level folders
$topLevelFolders = New-Object System.Collections.Generic.HashSet[string]

foreach ($share in $smbShares) {
    # Ignore shares ending with a $ sign
    if ($share.Name -notlike "*$") {
        $path = $share.Path
        
        # Split the path into its components
        $pathParts = $path.Split('\')
        
        # Check if the path has more than one part (i.e., it's not just a drive letter)
        if ($pathParts.Count -gt 1) {
            # Construct the top-level folder path
            $topLevelFolder = "$($pathParts[0])\$($pathParts[1])"
            $topLevelFolders.Add($topLevelFolder) | Out-Null
        }
        else {
            # If the path is just a drive letter, add it to the HashSet
            $topLevelFolders.Add($pathParts[0]) | Out-Null
        }
    }
}

# Convert the HashSet to an array
$topLevelFoldersArray = @($topLevelFolders)

# Display the list of top-level folders
Write-Host "ShareRootFolder variable is: $ShareRootFolder" -ForegroundColor Green
Write-Host "The Get-SMBShare list shows: $topLevelFoldersArray " -ForegroundColor Green

# Get the total number of top-level folders
$topLevelFolderCount = $topLevelFoldersArray.Count
$CountShareRoot = $ShareRootFolder.Count

if ($topLevelFolderCount -eq $CountShareRoot) {
    Write-Host "The number of top-level folders matches the total number of ShareRootFolders." -ForegroundColor Green
}
else {
    Write-Host "The number of top-level folders is $topLevelFolderCount and does not match the total number of ShareRootFolders which is $CountShareRoot."
}
