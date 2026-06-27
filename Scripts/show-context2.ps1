$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1
Write-Host "=== Lines 220-262 ==="
$content[219..261] | ForEach-Object { Write-Host "$([array]::IndexOf($content, $_)+1): $_" }
