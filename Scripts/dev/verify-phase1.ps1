# ── Full Phase 1 Verification ────────────────────────────────
$parentDir = "$HOME\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"

Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'
try {
    $importTime = Measure-Command { Import-Module Talon -Force }
    Write-Host "IMPORT: $($importTime.TotalMilliseconds.ToString('F0')) ms" -ForegroundColor Green

    $cmds = Get-Command -Module Talon
    Write-Host "FUNCTIONS: $($cmds.Count) exported" -ForegroundColor Cyan

    Write-Host "`n── ALIASES ──"
    $aliases = @('dash','reload','health','spec','uptime','disk','hog','ports','battery','temp',
        'fwaudit','boot','taskaudit','ghostaudit','susaudit','evntaudit','admin',
        'netcheck','wifi','dnsbench','dnscache','nettriage',
        'envmap','pathaudit','app','patch','driveraudit',
        'remember','recall','memmap','report',
        'shield','certs','sys','audit','net','env')
    $ok = 0; $miss = @()
    foreach ($a in $aliases) {
        if (Get-Alias $a -ErrorAction SilentlyContinue) { $ok++ } else { $miss += $a }
    }
    Write-Host "  Registered: $ok / $($aliases.Count)" -ForegroundColor $(if($ok -eq $aliases.Count){'Green'}else{'Yellow'})
    if ($miss) { Write-Host "  Missing: $($miss -join ', ')" -ForegroundColor Yellow }

    Write-Host "`n── SYSTEM TESTS ──"
    Write-Host "  health:     $(Get-TalonHealth | Out-String).Trim()"
    Write-Host "  uptime:     $((Get-TalonUptime).Uptime)"
    Write-Host "  spec CPU:   $((Get-TalonSpec).Processor)"
    Write-Host "  disk C:     $((Get-TalonDiskPressure | Where Drive -eq 'C:').FreePercent) free"
    Write-Host "  ports:      $( (Get-TalonPortMap).Count ) TCP listeners"
    Write-Host "  battery:    $( (Get-TalonBattery).Status )"

    Write-Host "`n── SECURITY TESTS ──"
    Write-Host "  fwaudit:    $( (Get-TalonFirewallAudit | Where Status -eq 'NO_MATCHING_RULE').Count ) unmatched ports"
    Write-Host "  boot:       $( (Get-TalonBootMap).Count ) Run entries"
    Write-Host "  admin:      $( (Get-TalonAdmin).Count ) members"
    Write-Host "  susaudit:   $( (Get-TalonSuspiciousProcess).Count ) suspicious processes"

    Write-Host "`n── NETWORK TESTS ──"
    Write-Host "  netcheck:   Internet=$( (Get-TalonNetCheck).Internet )"
    Write-Host "  wifi:       $((Get-TalonWifi).SSID)"
    Write-Host "  dnsbench:   $( (Get-TalonDnsBench | Measure-Object).Count ) resolvers"

    Write-Host "`n── ENV TESTS ──"
    Write-Host "  app:        $( (Get-TalonApp).Count ) apps"
    Write-Host "  patch:      $( (Get-TalonPatchHistory).Count ) patches"

    Write-Host "`n── DISPATCHER TESTS ──"
    Write-Host "  sys Health: $( (Get-TalonSystem -Type Health).'CPU Load' )"
    Write-Host "  audit all:  $(Get-TalonAudit -Type all | Out-String)"
    Write-Host "  net:        $((Get-TalonNetwork -Type NetCheck).Internet)"
    Write-Host "  env:        $( (Get-TalonEnv -Type App).Count ) apps"

    Write-Host "`n── DASHBOARD ──"
    Show-TalonDashboard

    Write-Host "`n══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "PHASE 1 VERIFIED: $($cmds.Count) functions, $ok aliases, $($importTime.TotalMilliseconds.ToString('F0'))ms load" -ForegroundColor Green
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green

} catch {
    Write-Host "FAIL: $_" -ForegroundColor Red
    $_.Exception.ToString()
}
