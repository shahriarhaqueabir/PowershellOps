$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw

# Update the Set-TalonAliases function to also use -Scope Global for backward compat
$oldAliasLine = '        Set-Alias -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force'
$newAliasLine = '        Set-Alias -Scope Global -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force'

if ($content.Contains($oldAliasLine)) {
    $content = $content.Replace($oldAliasLine, $newAliasLine)
    Set-Content -Path $psm1 -Value $content -Encoding UTF8 -Force
    Write-Host "Set-TalonAliases function updated with -Scope Global."
} else {
    Write-Host "Old pattern not found."
    Select-String -Path $psm1 -Pattern 'Set-Alias' | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
}
