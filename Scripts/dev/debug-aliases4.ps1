# Deep debug: test scope resolution
$parentDir = "$HOME\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Import-Module Talon -Force

Write-Host "=== Scope Analysis ===" -ForegroundColor Yellow

# Check context
Write-Host "SessionState: $($ExecutionContext.SessionState)"

# Try creating alias from module's scope via script block
& (Get-Module Talon) {
    Write-Host "Inside module: about to Set-Alias"
    $result = Set-Alias -Name 'testfrommodule' -Value 'Get-TalonHealth' -Force -ErrorAction Stop
    Write-Host "  Set-Alias returned with no error"
}

Write-Host "  testfrommodule exists: $(Test-Path Alias:testfrommodule)"
Get-Alias testfrommodule -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  = $($_.Definition)" }

# Try with explicit scope
& (Get-Module Talon) {
    Set-Alias -Scope Global -Name 'testglobal' -Value 'Get-TalonHealth' -Force -ErrorAction SilentlyContinue
}
Write-Host "  testglobal exists: $(Test-Path Alias:testglobal)"

# What about Set-Item?
& (Get-Module Talon) {
    Set-Item -Path Alias:testitem -Value 'Get-TalonHealth' -Force -ErrorAction SilentlyContinue
}
Write-Host "  testitem exists: $(Test-Path Alias:testitem)"

# Try from outside the module
Set-Alias -Name testoutside -Value 'Get-TalonHealth' -Force
Write-Host "  testoutside exists: $(Test-Path Alias:testoutside)"

Write-Host "`n=== The Talon approach ==="
# Let me just create aliases directly
foreach ($m in @(@('health','Get-TalonHealth'), @('disk','Get-TalonDiskPressure'))) {
    Set-Alias -Scope Global -Name $m[0] -Value $m[1] -Force -ErrorAction SilentlyContinue
}
Write-Host "  health exists: $(Test-Path Alias:health)"
Write-Host "  disk exists: $(Test-Path Alias:disk)"
