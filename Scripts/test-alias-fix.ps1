$env:PSModulePath = "C:\Users\shahr\Documents\PowerShell;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue

Write-Host "Importing Talon..." -NoNewline
$t = Measure-Command { Import-Module Talon -Force }
Write-Host " $($t.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Green

$cmds = Get-Command -Module Talon
Write-Host "Functions exported: $($cmds.Count)" -ForegroundColor Cyan

$expectedAliases = @(
    'health','spec','uptime','disk','hog','ports','battery','temp',
    'fwaudit','boot','taskaudit','ghostaudit','susaudit','evntaudit','admin',
    'netcheck','wifi','dnsbench','dnscache','nettriage',
    'envmap','pathaudit','app','patch','driveraudit',
    'ai','ggl','secretredact','aistatus','injecttest','quality',
    'remember','recall','memmap',
    'report','dash','reload','shield','certs',
    'sys','audit','net','env'
)

$ok = 0; $miss = @()
foreach ($a in $expectedAliases) {
    $alias = Get-Alias $a -ErrorAction SilentlyContinue
    if ($alias) { $ok++ } else { $miss += $a }
}

Write-Host "Aliases registered: $ok / $($expectedAliases.Count)" -ForegroundColor $(if($ok -eq $expectedAliases.Count){'Green'}else{'Yellow'})
if ($miss) { Write-Host "Missing: $($miss -join ', ')" -ForegroundColor Yellow }

$allOk = $true
foreach ($a in $expectedAliases) {
    $alias = Get-Alias $a -ErrorAction SilentlyContinue
    if (-not $alias) { $allOk = $false; break }
}
if ($allOk) {
    Write-Host "`n✅ ALL 43 ALIASES REGISTERED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "Cold import: $($t.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Green

    Write-Host "`nSample alias tests:" -ForegroundColor Cyan
    $samples = @('health','spec','disk','admin','dash','reload','sys','audit','net','env')
    foreach ($s in $samples) {
        $a = Get-Alias $s -ErrorAction SilentlyContinue
        if ($a) {
            Write-Host "  $s → $($a.ReferencedCommand)" -ForegroundColor Green
        } else {
            Write-Host "  $s → MISSING" -ForegroundColor Red
        }
    }
}
