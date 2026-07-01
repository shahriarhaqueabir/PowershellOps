# Debug: why aren't aliases being set?
$parentDir = "$HOME\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Import-Module Talon -Force

# Check if the function exists
Write-Host "Set-TalonAliases exists: $(Get-Command Set-TalonAliases -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)"

# Try setting ONE alias directly from PS module scope
Write-Host "`nTrying direct Set-Alias with -Scope Global..."
Set-Alias -Scope Global -Name 'testalias123' -Value 'Get-TalonHealth' -Force
Write-Host "  testalias123 exists: $(Test-Path Alias:testalias123)"
if (Test-Path Alias:testalias123) {
    Write-Host "  testalias123 = $(Get-Alias testalias123 | Select-Object -ExpandProperty Definition)"
}

# Now call the module function
Write-Host "`nCalling Set-TalonAliases..."
Set-TalonAliases 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host "  Done."

# Check if ANY aliases were created
Write-Host "`nChecking aliases..."
$expected = @('dash','health','disk')
foreach ($a in $expected) {
    Write-Host "  $a exists: $(Test-Path Alias:$a)"
}

# Maybe the alias already exists from the Storage module?
Write-Host "`nChecking for cmdlet aliases that might conflict..."
Get-Alias disk -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  disk found: $($_.Name) → $($_.Definition)" }
Get-Alias -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @('dash','health','disk') } | ForEach-Object { Write-Host "  Collision: $($_.Name) → $($_.Definition)" }
