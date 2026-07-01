$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1
Write-Host "=== Last 5 lines of Talon.psm1 ==="
$content[-5..-1] | ForEach-Object { Write-Host $_ }
Write-Host "`n=== Lines containing Set-TalonAliases ==="
Select-String -Path $psm1 -Pattern 'Set-TalonAliases' | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
