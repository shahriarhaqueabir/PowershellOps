$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1
Write-Host "=== Lines 250-275 ==="
$content[249..274] | ForEach-Object { Write-Host "$([array]::IndexOf($content, $_)+1): $_" }
