# Read Talon files
$talonDir = Join-Path $HOME 'Documents\PowerShell\Talon'
$psd1 = Join-Path $talonDir 'Talon.psd1'
$psm1 = Join-Path $talonDir 'Talon.psm1'

Write-Host "=== TALON.PSD1 ==="
Get-Content $psd1 -Raw

Write-Host "`n=== SET-TALONALIASES FUNCTION ==="
$inFunction = $false
$braceCount = 0
Get-Content $psm1 | ForEach-Object {
    if ($_ -match 'function Set-TalonAliases') { $inFunction = $true; $braceCount = 0 }
    if ($inFunction) {
        Write-Host $_
        if ($_ -match '{') { $braceCount += ([regex]::Matches($_, '{').Count) }
        if ($_ -match '}') { $braceCount -= ([regex]::Matches($_, '}').Count) }
        if ($braceCount -le 0 -and $inFunction -and $_ -match '^\s*\}') { $inFunction = $false }
    }
}
