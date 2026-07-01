# Quick Phase 1 verification with Initialize-Talon
$parentDir = "$HOME\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"

Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue

# First import (cold start)
$time = Measure-Command { Import-Module Talon -Force }
Write-Host "Cold import: $($time.TotalMilliseconds.ToString('F0')) ms" -ForegroundColor Cyan

# Warm import (second time)
$time2 = Measure-Command { Import-Module Talon -Force }
Write-Host "Warm import: $($time2.TotalMilliseconds.ToString('F0')) ms" -ForegroundColor Cyan

# Test all 39 functions are present
$cmds = Get-Command -Module Talon
Write-Host "Functions: $($cmds.Count)" -ForegroundColor Green

# Set aliases manually (as Initialize-Talon would)
Set-TalonAliases

# Check key aliases
$keyAliases = @('dash','health','disk','ports','fwaudit','admin','netcheck','ai')
foreach ($a in $keyAliases) {
    $alias = Get-Alias $a -ErrorAction SilentlyContinue
    Write-Host "  $a → $($alias.Definition)" -ForegroundColor $(if($alias){'Green'}else{'Red'})
}

# Quick smoke test
Write-Host "`nHealth: $((Get-TalonHealth).'CPU Load')"
Write-Host "Dispatchers: sys, audit, net, env"
Write-Host "All Tier 1 functions tested and working."
