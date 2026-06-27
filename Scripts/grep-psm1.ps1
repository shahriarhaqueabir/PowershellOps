$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
Select-String -Path $psm1 -Pattern '\$script:TalonAliasMappings|\$mappings|Set-Alias' | ForEach-Object { Write-Host "Line $($_.LineNumber): $($_.Line.Trim())" }
