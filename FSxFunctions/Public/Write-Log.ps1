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
        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
        [String]
        $Level = "INFO",
        [Parameter(Mandatory=$True)]
        [string]
        $Message,
        [Parameter(Mandatory=$False)]
        [string]
        $Logfile,
        [Parameter(Mandatory=$False)]
        [string]
        $LogLocation = "$($env:USERPROFILE)\Documents\FsxMigrate"
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    $Logfilepath = "$LogLocation\FsxMigrate.log"

    if (!(Test-Path $LogLocation)) {
        New-Item -ItemType Directory -Force -Path $LogLocation | Out-Null
    }

    if (Test-Path $Logfilepath) {
        Add-Content $Logfilepath -Value $Line
    }
    else {
        Write-Output $Line
    }
}
