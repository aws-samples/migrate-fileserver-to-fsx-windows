<#
This file contains the configuration parameters used by the other scripts in the migration process.
It includes variables for the FSx instance's DNS name, drive letter, FSx RemotePS endpoint, aliases, log location, domain admin group, share root folders, and the flag to use Robocopy for data transfer.
The script also retrieves the FQDN of the source file server using the Resolve-DnsName cmdlet.
This centralized parameter file makes it easier to manage the migration settings and ensures consistency across the various scripts.
#>

###############################
# EDIT THE FOLLOWING VARIABLES:
###############################
# This will prompt for Credentials that have permission to create new shares on FSx, and access all folders on source files server, usually a user that is part of Domain Admins, File server admins or 
# AWS FSx delegated administrators if using AWS managed AD
if (-not $FSxAdminUserCredential -or $FSxAdminUserCredential.Password.Length -eq 0) {
    $FSxAdminUserCredential = Get-Credential -Message "Enter the credentials for the FSx administrator user"
}

# The DNS name of your destination FSx for Windows file system. amznfsxhkxyen.corp.example.com
$FSxDNSName = "amznfsxhkxahsen.mytestdomain.local"

# Drive letter will be used to mount FSx on this file server
$FSxDriveLetter = "Z:" 

# The FQDN of the endpoint “amznfsxzzzzzzzz.corp.example.com“ Amazon FSx CLI for remote management on PowerShell enables file system administration for users in the file system administrators group
$FSxDestRPSEndpoint = "amznfsx5gxfqmhi.mytestdomain.local"

# Alias uses a CNAME record to make things easiier for clients to remember i.e. \\fs1.mytestdomain.local instead of \\EC2AMAZ43567.mytestdomain.local
# Can be comma separated list enclosed in "fs1.dom.local","fs2.dom.local"
$Alias = "fs1.mytestdomain.local" # must be in FQDN format and not the hostname of source file server

$LogLocation = "C:" # Log file and share config export location, do not include the \ if C:\ just put C:

# In the context of the file server migration, the script 1-CheckPermissions.ps1 checks if the built in local Administrators group "BUILTIN\Administrators" has been granted permissions on the shared folders. 
# This is important because local groups, such as the Administrators group, will not have the same level of access on the Amazon FSx for Windows, which is managed by domain-level groups.
# You can change the $LocalAdminGroup value here and run 1-CheckPermissions.ps1 again if your local admin group is not using the default name "BUILTIN\Administrators".
$LocalAdminGroup = "BUILTIN\Administrators"

# Replace with the Name of your domain administrators group AWS Managed AD is "AWS Delegated Administrators" and Self Managed is "Domain Admins" 
$DomainAdminGroup = "MYTESTDOMAIN\AWS Delegated Administrators" 

# $ShareRootFolder can be one or more locations, each location must be enclosed in double quotes "", for example if you have two locations use this format: "C:\share1","D:\" 
$ShareRootFolder = "C:\share1","D:\" 

# If $ShareRootFolder = "C:\share1","D:\" The script will loop through each top level folder "C:\share1","D:\" and use robocopy to copy all subfolders located inside share1 and D:\
# https://andys-tech.blog/2020/07/robocopy-is-mt-with-more-threads-faster/ 

# Getting Hostname of file server - no need to edit this
$FQDN = (Resolve-DnsName $(hostname) -Type A).Name

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
