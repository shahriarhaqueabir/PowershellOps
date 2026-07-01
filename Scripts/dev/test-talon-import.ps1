# Verify Talon loads correctly
# Talon is at $HOME\Documents\PowerShell\Talon\Talon.psd1
# So we need the PARENT in PSModulePath
$parentDir = "$HOME\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"

Write-Host "PSModulePath starts with: $($env:PSModulePath -split ';' | Select-Object -First 1)"
Write-Host "Looking for Talon module..."

try {
    # Force re-import
    Remove-Module Talon -ErrorAction SilentlyContinue
    Import-Module Talon -Force -ErrorAction Stop
    Write-Host "IMPORT OK" -ForegroundColor Green

    $cmds = Get-Command -Module Talon
    Write-Host "Exported functions ($($cmds.Count)):"
    foreach ($c in $cmds) { Write-Host "  $($c.Name)" }

    Write-Host "`nTesting dash..."
    Show-TalonDashboard

} catch {
    Write-Host "FAIL: $_" -ForegroundColor Red

    # Try direct import
    Write-Host "`nTrying direct path import..."
    try {
        Import-Module -Name "$HOME\Documents\PowerShell\Talon\Talon.psd1" -Force -ErrorAction Stop
        Write-Host "DIRECT IMPORT OK" -ForegroundColor Green
        Get-Command -Module Talon | ForEach-Object { Write-Host "  $($_.Name)" }
    } catch {
        Write-Host "Direct import also failed: $_" -ForegroundColor Red
    }
}
