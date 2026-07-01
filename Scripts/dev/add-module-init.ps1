$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw

# Check if Set-TalonAliases is already called at module load
if ($content -match '(?m)^Set-TalonAliases$') {
    Write-Host "Set-TalonAliases already called at module load."
} else {
    # Append a call at the end of the file (runs at module import time)
    $content += "`n# ── CREATE ALIASES AT MODULE LOAD ──────────────────────`nSet-TalonAliases`n"
    Set-Content -Path $psm1 -Value $content -Encoding UTF8 -Force
    Write-Host "Appended Set-TalonAliases call at module load."
}
