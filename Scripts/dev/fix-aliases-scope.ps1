$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw
$new = $content -replace '(?m)^(\s{8})Set-Alias -Scope Global -Name', '${1}Set-Alias -Name'
Set-Content -Path $psm1 -Value $new -Encoding UTF8 -Force
Write-Host "Talon.psm1 updated. Removed -Scope Global from Set-Alias calls."
