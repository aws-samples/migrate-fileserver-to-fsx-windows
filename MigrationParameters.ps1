# This script will prompt for inputs, however you can edit the default values below:
$LogLocation = (Read-Host -Prompt "Enter the log file location (Default: C:\Migration)").Trim()
if ([string]::IsNullOrEmpty($LogLocation)) {
    $LogLocation = "C:\Migration"
}

$FSxDriveLetter = (Read-Host -Prompt "Enter the drive letter to use for the Amazon FSx file system (Default: Z:)").Trim()
if ([string]::IsNullOrEmpty($FSxDriveLetter)) {
    $FSxDriveLetter = "Z:"
}

# If $LogLocation is set to "C:\Migration", then $logFilePath will be set to "C:\Migration\Robocopy.log".
$RoboLogFilePath = "$LogLocation\Robocopy.log"

$LocalAdminGroup = (Read-Host -Prompt "Enter the local admin group (Default: BUILTIN\Administrators)").Trim()
if ([string]::IsNullOrEmpty($LocalAdminGroup)) {
    $LocalAdminGroup = "BUILTIN\Administrators"
}

$DomainAdminGroup = (Read-Host -Prompt "Enter the domain admin group (Default: AWS Delegated Administrators)").Trim()
if ([string]::IsNullOrEmpty($DomainAdminGroup)) {
    $DomainAdminGroup = "AWS Delegated Administrators"
}

Write-Host 'Default source share root is: "C:\share1","D:\"'
$ShareRootFolder = (Read-Host -Prompt "Enter the source share root folder(s) comma seperated, including double quotes").Trim()
if ([string]::IsNullOrEmpty($ShareRootFolder)) {
    $ShareRootFolder = "C:\share1","D:\"
}
else {
    $ShareRootFolder = $ShareRootFolder -split ','
}

# If $ShareRootFolder = "C:\share1","D:\" The script will robocopy top level folder "C:\share1","D:\" and all subfolders located inside share1 and D:\ from the source file server to FSx
# https://andys-tech.blog/2020/07/robocopy-is-mt-with-more-threads-faster/ 

# Get the current AD domain
$Domain = Get-ADDomain
$NetBIOS = $Domain.NetBIOSName
$NetBIOS = (Read-Host -Prompt "Enter the NETBIOS name, (Default: $NetBIOS )").Trim()
if ([string]::IsNullOrEmpty($NetBIOS)) {
    $NetBIOS = $Domain.NetBIOSName
}
###############################
# RETRIEVE VALUES AUTOMATICALLY
###############################
$DomainName = (Get-CimInstance -Class Win32_ComputerSystem -ComputerName $env:computername).Domain

# Getting Hostname of file server - no need to edit this
$FQDN = (Resolve-DnsName $(hostname) -Type A).Name

# List all available AWS regions
 Write-Host "Available FSxW Regions:"
$RegionGroups = @{
    "US East (Northern Virginia)" = "us-east-1"
    "US East (Ohio)" = "us-east-2"
    "US West (Northern California)" = "us-west-1"
    "US West (Oregon)" = "us-west-2"
    "Asia Pacific (Mumbai)" = "ap-south-1"
    "Asia Pacific (Tokyo)" = "ap-northeast-1"
    "Asia Pacific (Seoul)" = "ap-northeast-2"
    "Asia Pacific (Singapore)" = "ap-southeast-1"
    "Asia Pacific (Sydney)" = "ap-southeast-2"
    "Europe (Frankfurt)" = "eu-central-1"
    "Europe (Dublin)" = "eu-west-1"
    "Europe (London)" = "eu-west-2"
    "Europe (Paris)" = "eu-west-3"
    "Europe (Stockholm)" = "eu-north-1"
}

# Print Regions to help user input correct one
foreach ($GroupName in $RegionGroups.Keys) {
    $Region = $RegionGroups[$GroupName]
    Write-Host "$GroupName : $Region" -ForeGroundColor Green
}

# Ask user for the region of their FSx so we can grab the FSx Id and info 
$Region = Read-Host -Prompt "Please enter the region (e.g., eu-west-1) of your FSx Windows system: "

# Get all filesystems in that region
$FsxFileSystems = Get-FsxFileSystem -Region $Region
if ($FsxFileSystems.Count -gt 1) {
    for ($i = 0; $i -lt $FsxFileSystems.Count; $i++) {
        Write-Host "$i. $($FsxFileSystems[$i].StorageCapacity) GB - $($FsxFileSystems[$i].StorageType) - $($FsxFileSystems[$i].FsxAdministratorsGroupName)"
    }
    $Selection = Read-Host -Prompt "Multiple FSx File Systems found, pick one to use (enter the number): "
    $SelectedFsxFileSystem = $FsxFileSystems[$Selection]
} else {
    $SelectedFsxFileSystem = $FsxFileSystems
}

# Store FSx ID
$FSxId = $SelectedFsxFileSystem.FileSystemId

# Retrieve the Amazon FSx file system details
try {  
        $FileSystemId = (Read-Host -Prompt "Enter the Amazon FSx file system Id (Default:$FSxId").Trim()
        if ([string]::IsNullOrEmpty($FSxDriveLetter)) {
            $FileSystemId = "$FSxId"
        }
        Write-Host "Getting values for FSx automatically. Please wait" -ForegroundColor Yellow
        $FSxFileSystem = Get-FsxFileSystem -FileSystemId $FileSystemId -ErrorAction Stop
        
    # Get the DNS name of the Amazon FSx file system
    $FSxDNSName = $FSxFileSystem.DNSName
    
    # Get the Remote PowerShell endpoint for the Amazon FSx file system
    $FSxDestRPSEndpoint = $FSxFileSystem.WindowsConfiguration.RemoteAdministrationEndpoint

    # Get Alias
    $Alias = $FSxFileSystem.WindowsConfiguration.Aliases.Name
    
    Write-Host "Values retrieved automatically:" -ForegroundColor Green
    Write-Host "FSxDNSName: $FSxDNSName"
    Write-Host "FSxDestRPSEndpoint: $FSxDestRPSEndpoint"
    Write-Host "Alias: $Alias"
    
}
catch {
    Write-Host "Unable to retrieve values automatically. Please provide the following information manually:" -ForegroundColor Yellow

    # Prompt the user to enter the values with default options
    $FSxDNSName = (Read-Host -Prompt "Enter the DNS name of the Amazon FSx file system (Default: $($FSxFileSystem.DNSName))").Trim()
    if ([string]::IsNullOrEmpty($FSxDNSName)) {
        $FSxDNSName = $FSxFileSystem.DNSName
    }

    $FSxDestRPSEndpoint = (Read-Host -Prompt "Enter the Remote PowerShell endpoint for the Amazon FSx file system (Default: $($FSxFileSystem.WindowsConfiguration.RemoteAdministrationEndpoint))").Trim()
    if ([string]::IsNullOrEmpty($FSxDestRPSEndpoint)) {
        $FSxDestRPSEndpoint = $FSxFileSystem.WindowsConfiguration.RemoteAdministrationEndpoint
    }

    
    $Alias = (Read-Host -Prompt "Enter the alias for the file server (Press enter to skip)").Trim()
    if ([string]::IsNullOrEmpty($Alias)) {
        $Alias = $null
    }
    
}
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
