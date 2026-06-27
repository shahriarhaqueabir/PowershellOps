$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"

Write-Host "=== TALON.PSD1 - AliasesToExport ==="
$psd1 = Get-Content (Join-Path $talonDir 'Talon.psd1') -Raw
if ($psd1 -match '(?s)AliasesToExport\s*=\s*@\((.*?)\)') {
    $aliases = $matches[1] -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and $_ -ne "'@'" }
    Write-Host "Count: $($aliases.Count)"
    $aliases | ForEach-Object { Write-Host "  $_" }
}

Write-Host "`n=== TALON.PSM1 - Set-Alias lines ==="
Select-String -Path (Join-Path $talonDir 'Talon.psm1') -Pattern 'Set-Alias' | ForEach-Object {
    Write-Host "  $($_.Line.Trim())"
}
