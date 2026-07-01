$env:PSModulePath = "$HOME\Documents\PowerShell;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue

Import-Module Talon -Force
$m = Get-Module Talon

Write-Host "1. Module exported aliases:"
$m.ExportedAliases.Keys | ForEach-Object { Write-Host "   $_ → $($m.ExportedAliases[$_].ReferencedCommand)" }
if ($m.ExportedAliases.Count -eq 0) { Write-Host "   (none)" -ForegroundColor Yellow }

Write-Host "`n2. Checking via Get-Alias in module context:"
$aliases = & $m { Get-Alias | Where-Object { $_.Name -in @('health','spec','disk','dash','reload','admin') } }
if ($aliases) {
    $aliases | ForEach-Object { Write-Host "   $($_.Name) → $($_.ReferencedCommand)" }
} else {
    Write-Host "   (none found in module context)" -ForegroundColor Yellow
}

Write-Host "`n3. Attempting Set-Alias from module scope:"
& $m { Set-Alias -Name testalias123 -Value Get-TalonHealth -Force }
$testa = Get-Alias testalias123 -ErrorAction SilentlyContinue
if ($testa) { Write-Host "   testalias123 → $($testa.ReferencedCommand) (visible globally!)" -ForegroundColor Green }
else {
    Write-Host "   testalias123 NOT visible globally" -ForegroundColor Yellow
    # Check if it exists in module scope
    $testa2 = & $m { Get-Alias testalias123 -ErrorAction SilentlyContinue }
    if ($testa2) { Write-Host "   testalias123 exists in module scope but not globally" -ForegroundColor Cyan }
    else { Write-Host "   testalias123 doesn't exist in module scope either" -ForegroundColor Red }
}

Write-Host "`n4. Module file check - last 15 lines:"
$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
Get-Content $psm1 -Tail 15

Write-Host "`n5. PSD1 AliasesToExport check:"
$psd1 = "$HOME\Documents\PowerShell\Talon\Talon.psd1"
$psd1Content = Get-Content $psd1 -Raw
if ($psd1Content -match 'AliasesToExport\s*=\s*@\((.*?)\)') {
    $aliasesList = $matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'").Trim('"') } | Where-Object { $_ -ne '' }
    Write-Host "   Found $($aliasesList.Count) aliases in AliasesToExport"
    Write-Host "   First 5: $($aliasesList[0..5] -join ', ')"
}
