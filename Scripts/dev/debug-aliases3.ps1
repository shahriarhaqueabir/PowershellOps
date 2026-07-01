# Debug: add verbose output to alias creation
$parentDir = "$HOME\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Import-Module Talon -Force

# Create a test alias directly (this works)
Set-Alias -Scope Global -Name 'testalias123' -Value 'Get-TalonHealth' -Force
Write-Host "Direct Set-Alias works: $(Test-Path Alias:testalias123)" -ForegroundColor Cyan

# The module function doesn't work. Let me check what's in the function
$func = Get-Command Set-TalonAliases -ErrorAction SilentlyContinue
Write-Host "Function source: $($func.Source)"
Write-Host "Module: $($func.ModuleName)"

# Try calling it with verbose
Write-Host "`n--- Calling Set-TalonAliases with Verbose ---"
Set-TalonAliases -Verbose 4>&1 | ForEach-Object { Write-Host "  [VERBOSE] $_" }

Write-Host "`n--- Checking results ---"
Write-Host "  dash exists: $(Test-Path Alias:dash)"
Get-Alias dash -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  dash = $($_.Definition)" }

# Maybe -Scope Global doesn't work from module?
Write-Host "`n--- Testing Scope:Local from module context ---"
& (Get-Module Talon) { Set-Alias -Scope 1 -Name testmodulealias -Value Get-TalonHealth -Force }
Write-Host "  testmodulealias exists: $(Test-Path Alias:testmodulealias)"
