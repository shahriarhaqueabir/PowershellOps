$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
Select-String -Path $psm1 -Pattern 'Set-Alias' | ForEach-Object { Write-Host "Line $($_.LineNumber): $($_.Line.Trim())" }
Write-Host "`n--- Checking AliasesToExport in PSD1 ---"
$psd1 = "$HOME\Documents\PowerShell\Talon\Talon.psd1"
Select-String -Path $psd1 -Pattern "AliasesToExport|'health'|'dash'|'reload'" | ForEach-Object { Write-Host "PSD1 Line $($_.LineNumber): $($_.Line.Trim())" }
