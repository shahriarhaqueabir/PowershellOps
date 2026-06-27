# Diagnose Tier 1 loading issue
$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"

Write-Host "=== Check files exist ==="
$files = @("Talon.psd1", "Talon.psm1", "Talon.Commands.psd1", "Talon.Commands.psm1")
foreach ($f in $files) {
    $path = Join-Path $talonDir $f
    $exists = Test-Path $path
    Write-Host "  $f : $exists $(if($exists){ '- ' + (Get-Item $path).Length + ' bytes'})"
}

Write-Host "`n=== Talon.psd1 content ==="
Get-Content (Join-Path $talonDir 'Talon.psd1') -Raw

Write-Host "`n=== Talon.Commands.psd1 content ==="
Get-Content (Join-Path $talonDir 'Talon.Commands.psd1') -Raw

Write-Host "`n=== Test: import root module with verbose ==="
$parentDir = "C:\Users\shahr\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"

Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue

Import-Module Talon -Force -Verbose -ErrorAction SilentlyContinue 4>&1 | ForEach-Object { Write-Host "  $($_.Message)" }

Write-Host "`n=== Available commands ==="
Get-Command -Module Talon | ForEach-Object { Write-Host "  $($_.Name)" }

Write-Host "`n=== Try direct nested module import ==="
try {
    Import-Module (Join-Path $talonDir 'Talon.Commands.psd1') -Force -ErrorAction Stop
    Write-Host "  Direct import SUCCESS" -ForegroundColor Green
    Get-Command -Module Talon.Commands | ForEach-Object { Write-Host "  $($_.Name)" }
} catch {
    Write-Host "  Direct import FAIL: $_" -ForegroundColor Red
}
