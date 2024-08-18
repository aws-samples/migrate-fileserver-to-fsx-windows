## Migrate Windows File Servers to Amazon FSx for Windows File Server


This repository contains a set of PowerShell scripts to assist in the migration of a Windows file server to Amazon FSx for Windows File Server.
Overview

## The migration process involves the following steps:

    Enabling CredSSP (Credential Security Support Provider) on both the source file server and the FSx instance.
    Checking the NTFS and SMB share permissions on the source file server and addressing any issues.
    Copying the data from the source file server to the FSx instance using Robocopy.
    Recreating the file shares on the FSx instance using PowerShell remoting.
    (Optional) Removing the existing Service Principal Names (SPNs) from the source file server's Active Directory computer object and adding the new SPNs to the FSx instance's computer object.
    (Optional) Recreating the DNS CNAME records for the file server aliases and linking them to the FSx instance's DNS name.
    Disabling the CredSSP configuration after the migration is complete.

## Prerequisites

PowerShell 5.1 or later
Active Directory module for PowerShell
Appropriate permissions to manage file shares, Active Directory objects, and DNS records

## Note

The FSx for Windows file system by default creates a demo share named "Share", if your source file server has a share folder called "Share" you would need to either manually delete the one that exists on FSx Windows first before migrating or rename the on premise share to something else.

## Usage

Clone the repository to your local machine. Alternatively download as a zip file.
Review and update the configuration parameters in the MigrationParameters.ps1 file.

## Robocopy Folder Structure Considerations 

```

+--ShareRootFolder (Not shared on network)
   |
   +--Shared Subfolder 1 (Shared over SMB)
   |
   +--Shared Subfolder 2 (Shared over SMB)
   |
   +--Shared Subfolder 3 (Shared over SMB)
   |
   +--Unshared Subfolder (Not shared on network)

+--Shared Top-Level Folder (Shared over the network)
   |
   +--Unshared Subfolder 1
   |
   +--Unshared Subfolder 2
   |
   +--Unshared Subfolder 3
   |
   +--Shared Subfolder (Shared over the network)
       |
       +--Unshared Sub-subfolder 1
       |
       +--Unshared Sub-subfolder 2

```
### Step 1:
Dot Source the MigrationParameters.ps1 file to load all the values into memory:

` . .\MigrationParameters.ps1 `

### Step 2:

Run the scripts in the following order:
1. ` .\0-Enable-CredSSP.ps1 `
1. ` .\1-CheckPermissions.ps1 `
1. ` .\2-Robocopy.ps1 `
1. ` .\3-RecreateShares.ps1 `
1. ` .\4-Remove-Add-SPN.ps1 `
1. ` .\5-Alias-CNAME.ps1 `
1. ` .\6-Disable-CredSSP.ps1 `

## Logging and Troubleshooting

The scripts use a central log file located at the path specified in the $LogLocation variable. This log file can be used for troubleshooting and reviewing the actions taken during the migration process.
If any issues arise during the migration, refer to the log file and the error messages displayed in the console for more information.

## Disclaimer

These scripts are provided as-is, without warranty of any kind. It is the responsibility of the user to thoroughly test the scripts in a non-production environment before deploying them in a production setting.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
