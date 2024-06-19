
# Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
# At some stage we cacn add a private credential folder 
#$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )


# Dot source the files
Foreach ($import in @($Public)) {
  Try 
  {
      . $import.FullName
      Write-host "Importing $($import.FullName)" -ForegroundColor Yellow 
      Export-ModuleMember -Function $Public.Basename
  }
  Catch 
  {
      Write-Error -Message "Failed to import function $($import.fullname): $_"
  }
}

