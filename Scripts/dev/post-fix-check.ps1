$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
Write-Host "=== All function definitions ==="
Select-String -Path $psm1 -Pattern '^function\s' | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
Write-Host "`n=== Aliases at module level (first & last few) ==="
$aliases = Select-String -Path $psm1 -Pattern 'Set-Alias.*health|Set-Alias.*env\b'
$aliases | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
