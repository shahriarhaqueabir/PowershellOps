$env:PSModulePath = "C:\Users\shahr\Documents\PowerShell;$env:PSModulePath"
Remove-Module Talon -Force -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -Force -ErrorAction SilentlyContinue

Import-Module Talon -Force

$allAliases = @(
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
foreach ($a in $allAliases) {
    $alias = Get-Alias $a -ErrorAction SilentlyContinue
    if ($alias) { $ok++ } else { $miss += $a }
}

Write-Host "Import: $(Get-Date -Format 'HH:mm:ss')"
Write-Host "Functions: $( (Get-Command -Module Talon).Count )"
Write-Host "Aliases: $ok / $($allAliases.Count)"
if ($miss) { Write-Host "Missing: $($miss -join ', ')" -ForegroundColor Yellow }

$expMod = Get-Module Talon
Write-Host "ExportedAliases (module metadata): $($expMod.ExportedAliases.Count)"
