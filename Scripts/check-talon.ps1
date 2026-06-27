# Check Talon PSModulePath and import
$paths = $env:PSModulePath -split ';'
Write-Host "Module paths:"
foreach ($p in $paths) { Write-Host "  $p" }

Write-Host "`nLooking for Talon in each path..."
$found = $false
foreach ($p in $paths) {
    $test = Join-Path $p "Talon"
    if (Test-Path $test) {
        Write-Host "  FOUND at: $test" -ForegroundColor Green
        $found = $true
    }
}
if (-not $found) {
    Write-Host "  Talon not found in any PSModulePath entry" -ForegroundColor Yellow
}

$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"
Write-Host "`nTarget directory exists: $(Test-Path $talonDir)"
Write-Host "Files in target:"
Get-ChildItem $talonDir -Recurse | ForEach-Object { Write-Host "  $($_.Name) ($($_.Length) bytes)" }

Write-Host "`nPSMajorVersion: $($PSVersionTable.PSVersion.Major)"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "PowerShell 7 confirmed" -ForegroundColor Green
}
