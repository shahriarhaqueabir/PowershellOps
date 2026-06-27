# Debug alias registration
$parentDir = "C:\Users\shahr\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Import-Module Talon -Force

Set-TalonAliases

Write-Host "Aliases check:"
# Don't use ForEach-Object, just check individual
if (Test-Path Alias:dash) { Write-Host "  dash: $(Get-Alias dash | Select-Object -ExpandProperty Definition)" }
if (Test-Path Alias:health) { Write-Host "  health: $(Get-Alias health | Select-Object -ExpandProperty Definition)" }

# Test actual function execution via alias
Write-Host "`nCalling health via alias..."
health

Write-Host "`nCalling disk via alias..."
disk | Select-Object -First 2

Write-Host "`nAll good."
