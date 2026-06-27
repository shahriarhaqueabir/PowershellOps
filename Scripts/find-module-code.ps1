$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
Write-Host "=== Searching for script:TalonAliasMappings ==="
Select-String -Path $psm1 -Pattern 'TalonAliasMappings|talonAliasMappings|AliasMappings' | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
Write-Host "=== Looking at lines 196-215 ==="
Get-Content $psm1 | Select-Object -Index (195..214) | ForEach-Object { Write-Host "$([array]::IndexOf((Get-Content $psm1), $_)+1): $_" }
