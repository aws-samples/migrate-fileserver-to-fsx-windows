# Migrate Windows File Server to FSx for Windows
###############################
# EDIT THE FOLLOWING VARIABLES:
###############################
# Credentials that have permission to create new shares on FSx, and access all folders on source files server, usually Domain Admins, File server admins or AWS FSx delegated admins if using AWS managed AD
# comment out the below if not using AWS Secrets Manager 
$FSxAdminUserCredential = Get-Credential 
$FSxDNSName = "amznfsxhkxahsen.mytestdomain.local"
$FSxDriveLetter = "Z:" # Drive letter will be used to mount FSx on this file server
$FSxDestRPSEndpoint = "amznfsx5gxfqmhi.mytestdomain.local"
# Alias uses a CNAME record to make things easiier for clients to remember i.e. \\fs1.mytestdomain.local instead of \\EC2AMAZ43567.mytestdomain.local
# Can be comma separated list enclosed in "fs1.dom.local","fs2.dom.local"
$Alias = "fs1.mytestdomain.local" # must be in FQDN format and not the hostname of source file server
$LogLocation = "C:" # Log file and share config export location, do not include the \ if C:\ just put C:
$LocalAdminGroup = "BUILTIN\Administrators"
# Replace with the Name of your domain administrators group AWS Managed AD is "AWS Delegated Administrators" and Self Managed is "Domain Admins" 
$DomainAdminGroup = "MYTESTDOMAIN\AWS Delegated Administrators" # 
$ShareRootFolder = "C:\share1","D:\"  # $ShareRootFolder = "C:\share1","D:\" 
# If $UseRoboCopyForDataTransfer is set to true, the script will use robocopy to loop through each top level folder and copy all subfolders.
# https://andys-tech.blog/2020/07/robocopy-is-mt-with-more-threads-faster/ 
$UseRoboCopyForDataTransfer = $true
# Getting Hostname of file server - no need to edit this
$FQDN = (Resolve-DnsName $(hostname) -Type A).Name

