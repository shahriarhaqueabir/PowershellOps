$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw

# Fix the broken function definition - restore "function Set-TalonAliases"
$content = $content -replace [regex]::Escape('function # Aliases created at module load {'), 'function Set-TalonAliases {'
# Also fix any leftover
$content = $content -replace [regex]::Escape('    # Aliases created at module load'), '    # Aliases created at module load (already done at module load)'

Set-Content -Path $psm1 -Value $content -Encoding UTF8 -Force
Write-Host "Fixed broken function definition."
