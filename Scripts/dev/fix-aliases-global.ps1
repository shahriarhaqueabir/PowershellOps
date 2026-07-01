$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw

# Find the module-level alias loop and add -Scope Global to it
$oldLoop = 'foreach ($m in $script:TalonAliasMappings) {
    Set-Alias -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force
}'

$newLoop = 'foreach ($m in $script:TalonAliasMappings) {
    Set-Alias -Scope Global -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force
}'

if ($content.Contains($oldLoop)) {
    $content = $content.Replace($oldLoop, $newLoop)
    Set-Content -Path $psm1 -Value $content -Encoding UTF8 -Force
    Write-Host "Added -Scope Global to module-level alias creation loop."
} else {
    Write-Host "Could not find the old loop pattern."
    # Show the area around Set-Alias in the current file
    Select-String -Path $psm1 -Pattern 'Set-Alias' | ForEach-Object { Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" }
}
