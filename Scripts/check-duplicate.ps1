$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1
Write-Host "=== Lines 320-342 ==="
$content[319..341] | ForEach-Object { Write-Host "$([array]::IndexOf($content, $_)+1): $_" }
