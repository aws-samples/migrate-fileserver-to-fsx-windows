<#
  This script does the following:
    Retrieves the path to the current directory ($PSScriptRoot), which is assumed to be the location of the PowerShell modules.
    Finds all .psm1 files with the word "dedup" in the filename using Get-ChildItem.
    Loops through the found modules and checks if they are already imported. If not, it imports the module using Import-Module.
    Finds all .ps1 files with the word "dedup" in the filename using Get-ChildItem.
    Loops through the found scripts and dot-sources them using the dot operator (.).

    To use this script, save it as ImportDedupModules.ps1 in the same directory as your other dedup-related PowerShell modules and scripts. 
    Then, you can run the script to import or dot-source all the dedup-related modules and scripts:
    
    .\ImportDedupModules.ps1
#>
$modulePath = $PSScriptRoot

# Find all .psm1 files with "dedup" in the name
$dedupModules = Get-ChildItem -Path $modulePath -Filter "*dedup*.psm1" -File

# Import or dot-source the dedup modules
foreach ($module in $dedupModules) {
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($module.Name)
    $modulePath = Join-Path -Path $modulePath -ChildPath $module.Name

    # Check if the module is already imported
    if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
        Write-Host "Module '$moduleName' is already imported. Skipping import." -ForegroundColor Yellow
    }
    else {
        # Import the module
        Write-Host "Importing module: $moduleName" -ForegroundColor Green
        Import-Module -Name $modulePath -Verbose
    }
}

# Dot-source the dedup modules
$dedupModules = Get-ChildItem -Path $modulePath -Filter "*dedup*.ps1" -File
foreach ($module in $dedupModules) {
    $modulePath = Join-Path -Path $modulePath -ChildPath $module.Name
    Write-Host "Dot-sourcing script: $($module.Name)" -ForegroundColor Green
    . $modulePath
}
