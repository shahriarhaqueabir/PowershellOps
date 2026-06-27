$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
$lines = Get-Content $psm1
Write-Host "=== Lines 1-15 ==="
$lines[0..14] | ForEach-Object { Write-Host "$([array]::IndexOf($lines, $_)+1): $_" }
Write-Host "`n=== Lines 55-75 ==="
$lines[54..74] | ForEach-Object { Write-Host "$([array]::IndexOf($lines, $_)+1): $_" }
Write-Host "`n=== Searching for 'Missing function body' candidates ==="
Select-String -Path $psm1 -Pattern '^function\s' | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
