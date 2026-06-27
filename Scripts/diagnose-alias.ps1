$env:PSModulePath = "C:\Users\shahr\Documents\PowerShell;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue

Import-Module Talon -Force

Write-Host "=== Checking aliases in module scope ==="
$module = Get-Module Talon
Write-Host "Module: $($module.Name) v$($module.Version)"
Write-Host "ExportedAliases: $($module.ExportedAliases.Count)"
$module.ExportedAliases.Keys | Sort-Object | ForEach-Object { Write-Host "  $_ → $($module.ExportedAliases[$_])" }

Write-Host "`n=== Checking @talon: aliases ==="
$aliases = Get-Alias | Where-Object { $_.Name -in @('health','spec','disk','dash','reload','sys','audit','net','env','ai','ggl') }
if ($aliases) {
    $aliases | ForEach-Object { Write-Host "  $($_.Name) → $($_.ReferencedCommand)" }
} else {
    Write-Host "  None of the expected aliases found in global scope" -ForegroundColor Yellow
}

Write-Host "`n=== Manual Set-Alias test ==="
Set-Alias -Name testhealth -Value Get-TalonHealth -Force
$ta = Get-Alias testhealth -ErrorAction SilentlyContinue
if ($ta) { Write-Host "  testhealth → $($ta.ReferencedCommand) ✅" -ForegroundColor Green }
else { Write-Host "  testhealth FAILED ❌" -ForegroundColor Red }

Write-Host "`n=== Calling Set-TalonAliases explicitly ==="
Set-TalonAliases
$healthAlias = Get-Alias health -ErrorAction SilentlyContinue
if ($healthAlias) { Write-Host "  health → $($healthAlias.ReferencedCommand) ✅ (after explicit call)" -ForegroundColor Green }
else { Write-Host "  health still missing after explicit call ❌" -ForegroundColor Red }
