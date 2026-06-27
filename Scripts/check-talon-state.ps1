# Check Talon module state
$talonDir = Join-Path $HOME 'Documents\PowerShell\Talon'
Write-Host "Talon directory: $talonDir"
Write-Host "Exists: $(Test-Path $talonDir)"

if (Test-Path $talonDir) {
    Write-Host "`n── FILES ──"
    Get-ChildItem $talonDir -Recurse -File | ForEach-Object {
        Write-Host "  $($_.FullName.Replace($talonDir,'').TrimStart('\'))  [$($_.Length) bytes]"
    }

    Write-Host "`n── DIRECTORIES ──"
    Get-ChildItem $talonDir -Recurse -Directory | ForEach-Object {
        Write-Host "  $($_.FullName.Replace($talonDir,'').TrimStart('\'))"
    }
}

# Also check the config
$configPath = Join-Path $HOME '.talon' 'config.json'
Write-Host "`nConfig file: $configPath"
Write-Host "Exists: $(Test-Path $configPath)"
if (Test-Path $configPath) {
    Write-Host "Content:"
    Get-Content $configPath -Raw
}
