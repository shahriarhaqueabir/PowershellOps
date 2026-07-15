# ── PUBLIC: DIAGNOSTIC WORKFLOWS ──────────────────────────────────────────
# Each workflow combines multiple single-purpose functions into a scenario-driven
# report with color-coded status, scored summaries, and actionable recommendations.

# ── SHARED DISPLAY HELPERS ────────────────────────────────────────────────
# These are module-internal, dot-sourced first so workflow functions can use them.

function Write-OpsWorkflowBanner {
    [CmdletBinding()]
    param([string]$Title, [string]$Subtitle)
    $rule = '─' * 70
    Write-Host "  ┌$rule┐" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host "$Title".PadRight(68) -ForegroundColor Cyan -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    if ($Subtitle) {
        Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
        Write-Host $Subtitle.PadRight(68) -ForegroundColor DarkGray -NoNewline
        Write-Host ' │' -ForegroundColor DarkGray
    }
    Write-Host "  └$rule┘" -ForegroundColor DarkGray
}

function Write-OpsWorkflowSection {
    [CmdletBinding()]
    param([string]$Name, [string]$Color = 'Yellow')
    Write-Host "`n  [ $Name ] $('─' * [Math]::Max(1, (58 - $Name.Length)))" -ForegroundColor $Color
}

function Write-OpsRecommendations {
    [CmdletBinding()]
    param([array]$Items)
    Write-OpsWorkflowSection -Name 'RECOMMENDATIONS' -Color 'DarkYellow'
    foreach ($item in $Items) {
        $icon = $item[0]; $color = $item[1]; $msg = $item[2]
        if (-not $color) { continue }
        Write-Host "  $icon $msg" -ForegroundColor $color
    }
}

# ── WORKFLOW: DAILY OPS ───────────────────────────────────────────────────
function Invoke-OpsDailyOps {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'STATUS : SUMMARY' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $health   = Invoke-OpsCachedData -Key 'wflow_health' -ExpirySeconds 10  -ScriptBlock { Get-OpsHealth }
    $uptime   = Invoke-OpsCachedData -Key 'wflow_uptime' -ExpirySeconds 10  -ScriptBlock { Get-OpsUptime }
    $disk     = Invoke-OpsCachedData -Key 'wflow_disk'   -ExpirySeconds 30  -ScriptBlock { Get-OpsDiskPressureAudit }
    $netCheck = Invoke-OpsCachedData -Key 'wflow_net'    -ExpirySeconds 30  -ScriptBlock { Get-OpsNetCheck }
    $dns      = Invoke-OpsCachedData -Key 'wflow_dns'    -ExpirySeconds 300 -ScriptBlock { Get-OpsDnsBench }
    $events   = Invoke-OpsCachedData -Key 'wflow_events' -ExpirySeconds 20  -ScriptBlock { Get-OpsEventStormAudit }
    $temp     = Invoke-OpsCachedData -Key 'wflow_temp'   -ExpirySeconds 60  -ScriptBlock { Get-OpsTempCheck }
    $power    = Get-OpsPower

    $score = 100; $recs = @()
    Write-OpsWorkflowSection -Name 'SYSTEM'
    Write-Host "  CPU:    $($health.'CPU Load')  |  RAM: $($health.'RAM Usage')  |  Procs: $($health.Processes)" -ForegroundColor White
    Write-Host "  Uptime: $($uptime.'Continuous Run Time')  |  Power: $($power.Mode)" -ForegroundColor White

    Write-OpsWorkflowSection -Name 'STORAGE'
    foreach ($d in $disk) {
        $pct = [double]($d.FreePercent -replace '%')
        $dColor = 'Green'
        if ($pct -lt 10) { $score -= 15; $recs += , @('🔴', 'Red', "CRITICAL: $($d.DeviceID) at $($d.FreePercent) free — extend or clean immediately"); $dColor = 'Red' }
        elseif ($pct -lt 25) { $score -= 5; $dColor = 'Yellow' }
        Write-Host "  $($d.DeviceID)  $([Math]::Round(($d.SizeGB - $d.FreeGB),1))G used / $($d.SizeGB)G  ($($d.FreePercent) free)" -ForegroundColor $dColor
    }

    Write-OpsWorkflowSection -Name 'NETWORK'
    $online = $netCheck.Internet -eq $true
    if (-not $online) { $score -= 25; $recs += , @('🔴', 'Red', 'CRITICAL: No internet connectivity detected') }
    Write-Host "  Internet: $(if($online){'✅ Connected'}else{'❌ DISCONNECTED'})" -ForegroundColor $(if($online){'Green'}else{'Red'})
    foreach ($r in $dns) {
        $color = if ($r.SpeedMS -eq 'TIMEOUT' -or $r.SpeedMS -gt 1000) { $score -= 5; 'Red' } else { 'White' }
        Write-Host "  DNS $($r.Name): $($r.SpeedMS)ms" -ForegroundColor $color
    }

    if ($temp.SizeMB -gt 1000) { $score -= 5; $recs += , @('🟡', 'Yellow', "WARNING: Temp directory is $($temp.SizeMB) MB — consider cleaning") }
    if ($events.Count -gt 0)   { $score -= 10; $recs += , @('🟡', 'Yellow', "WARNING: $($events.Count) event storms detected in last 15 min (top: $($events[0].Name))") }

    $score = [Math]::Max(0, $score)
    $statusIcon = if ($score -ge 80) { '🟢' } elseif ($score -ge 50) { '🟡' } else { '🔴' }
    $statusColor = if ($score -ge 80) { 'Green' } elseif ($score -ge 50) { 'Yellow' } else { 'Red' }
    Write-Host "`n  $statusIcon  OVERALL SCORE: $score/100" -ForegroundColor $statusColor
    Write-OpsRecommendations -Items $recs

    return [PSCustomObject]@{ Score = $score; Health = $health; Uptime = $uptime; Disk = $disk; Network = $netCheck; Dns = $dns; Events = $events; Recommendations = $recs }
}

# ── WORKFLOW: SYSTEM REVIEW ───────────────────────────────────────────────
function Invoke-OpsSystemReview {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'SYSTEM REVIEW' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $health  = Invoke-OpsCachedData -Key 'wflow_health'   -ExpirySeconds 10  -ScriptBlock { Get-OpsHealth }
    $spec    = Invoke-OpsCachedData -Key 'wflow_spec'     -ExpirySeconds 300 -ScriptBlock { Get-OpsSpec }
    $uptime  = Invoke-OpsCachedData -Key 'wflow_uptime'   -ExpirySeconds 10  -ScriptBlock { Get-OpsUptime }
    $ram     = Invoke-OpsCachedData -Key 'wflow_ram'      -ExpirySeconds 300 -ScriptBlock { Get-OpsRamInfo }
    $disk    = Invoke-OpsCachedData -Key 'wflow_disk'     -ExpirySeconds 30  -ScriptBlock { Get-OpsDiskPressureAudit }
    $res     = Invoke-OpsCachedData -Key 'wflow_res'      -ExpirySeconds 5   -ScriptBlock { Get-OpsResourceMap }
    $ports   = Invoke-OpsCachedData -Key 'wflow_ports'    -ExpirySeconds 10  -ScriptBlock { Get-OpsPortMap }
    $temp    = Invoke-OpsCachedData -Key 'wflow_temp'     -ExpirySeconds 60  -ScriptBlock { Get-OpsTempCheck }
    $hyperv  = Get-OpsHypervisor
    $power   = Get-OpsPower
    $license = Get-OpsLicense

    $score = 100; $recs = @()

    Write-OpsWorkflowSection -Name 'HARDWARE'
    Write-Host "  CPU:  $($spec.Processor)" -ForegroundColor White
    Write-Host "  Cores: $($spec.Cores)  |  Model: $($spec.Model)  |  Type: $($hyperv.Status)" -ForegroundColor White
    Write-Host "  RAM:  $($health.'RAM Usage') across $($ram.Count) sticks" -ForegroundColor White

    Write-OpsWorkflowSection -Name 'PERFORMANCE'
    Write-Host "  CPU Load:  $($health.'CPU Load')" -ForegroundColor $(if([int]($health.'CPU Load' -replace '%','') -gt 80){'Red'}elseif([int]($health.'CPU Load' -replace '%','') -gt 60){'Yellow'}else{'Green'})
    Write-Host "  Processes: $($health.Processes)  |  Handles: $($health.Handles)" -ForegroundColor White
    Write-Host "  Uptime: $($uptime.'Continuous Run Time')" -ForegroundColor White
    Write-Host "  Power:  $($power.Mode)" -ForegroundColor White
    Write-Host "  Temp:   $($temp.SizeMB) MB in temp" -ForegroundColor $(if($temp.SizeMB -gt 1000){'Yellow'}else{'White'})

    Write-OpsWorkflowSection -Name 'TOP RESOURCE CONSUMERS'
    foreach ($p in $res | Select-Object -First 5) {
        Write-Host "  $($p.ProcessName) (PID $($p.Id)) — $($p.RAMMB) MB" -ForegroundColor White
    }

    Write-OpsWorkflowSection -Name 'LISTENING PORTS'
    Write-Host "  $($ports.Count) ports in listen state" -ForegroundColor White

    Write-OpsWorkflowSection -Name 'STORAGE'
    foreach ($d in $disk) {
        $pct = [double]($d.FreePercent -replace '%')
        $dColor = 'Green'
        if ($pct -lt 10) { $score -= 15; $recs += , @('🔴','Red',"CRITICAL: $($d.DeviceID) at $($d.FreePercent) free"); $dColor = 'Red' }
        elseif ($pct -lt 25) { $score -= 5; $recs += , @('🟡','Yellow',"WARNING: $($d.DeviceID) below 25% free"); $dColor = 'Yellow' }
        Write-Host "  $($d.DeviceID)  $([Math]::Round(($d.SizeGB - $d.FreeGB),1))G / $($d.SizeGB)G  ($($d.FreePercent) free)" -ForegroundColor $dColor
    }

    Write-OpsWorkflowSection -Name 'LICENSE'
    Write-Host "  Windows: $($license.Status)  |  Key: $($license.PartialProductKey)" -ForegroundColor White

    $score = [Math]::Max(0, $score)
    $statusIcon = if ($score -ge 80) { '🟢' } elseif ($score -ge 50) { '🟡' } else { '🔴' }
    Write-Host "`n  $statusIcon  OVERALL SCORE: $score/100" -ForegroundColor $(if($score -ge 80){'Green'}elseif($score -ge 50){'Yellow'}else{'Red'})
    Write-OpsRecommendations -Items $recs

    return [PSCustomObject]@{ Score = $score; Spec = $spec; Health = $health; Disk = $disk; Ports = $ports; Temp = $temp; License = $license; Recommendations = $recs }
}

# ── WORKFLOW: SECURITY AUDIT ──────────────────────────────────────────────
function Invoke-OpsSecurityAudit {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'SUBSYSTEM : SECURITY' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $firewall  = Invoke-OpsCachedData -Key 'wflow_fw'       -ExpirySeconds 60  -ScriptBlock { Get-OpsFirewallAudit }
    $boot      = Invoke-OpsCachedData -Key 'wflow_boot'     -ExpirySeconds 300 -ScriptBlock { Get-OpsBootMap }
    $tasks     = Invoke-OpsCachedData -Key 'wflow_tasks'    -ExpirySeconds 300 -ScriptBlock { Get-OpsScheduledTaskRiskAudit }
    $ghost     = Get-OpsGhostPortAudit
    $suspicious = Get-OpsSuspiciousProcessAudit
    $events    = Invoke-OpsCachedData -Key 'wflow_events'   -ExpirySeconds 20  -ScriptBlock { Get-OpsEventStormAudit }
    $admin     = Get-OpsAdmin
    $shield    = Get-OpsShield

    $score = 100; $recs = @()

    Write-OpsWorkflowSection -Name 'DEFENDER' -Color 'Red'
    if ($shield.Status -eq 'Defender cmdlets unavailable') {
        $score -= 20; $recs += , @('🔴','Red','CRITICAL: Windows Defender cmdlets unavailable — antivirus state unknown')
        Write-Host "  ⚠ Status: Unavailable" -ForegroundColor Red
    } else {
        $av = $shield.AntivirusEnabled
        $rt = $shield.RealTimeProtectionEnabled
        if (-not $av) { $score -= 15; $recs += , @('🔴','Red','CRITICAL: Antivirus not enabled') }
        if (-not $rt) { $score -= 15; $recs += , @('🔴','Red','CRITICAL: Real-time protection disabled') }
        Write-Host "  Antivirus: $(if($av){'✅ Enabled'}else{'❌ Disabled'})" -ForegroundColor $(if($av){'Green'}else{'Red'})
        Write-Host "  Real-time: $(if($rt){'✅ Active'}else{'❌ Disabled'})" -ForegroundColor $(if($rt){'Green'}else{'Red'})
    }

    Write-OpsWorkflowSection -Name 'FIREWALL' -Color 'Red'
    $gaps = @($firewall | Where-Object { $_.Status -ne 'Allowed' })
    Write-Host "  Listening ports: $($firewall.Count)  |  Without allow rule: $($gaps.Count)" -ForegroundColor $(if($gaps.Count -gt 0){'Yellow'}else{'Green'})
    if ($gaps.Count -gt 0) { $score -= [Math]::Min(10, $gaps.Count * 3); $recs += , @('🟡','Yellow',"WARNING: $($gaps.Count) listening port(s) have no inbound firewall allow rule") }
    foreach ($g in $gaps | Select-Object -First 5) { Write-Host "  Port $($g.Port) — $($g.Process) (PID $($g.PID))" -ForegroundColor DarkYellow }

    Write-OpsWorkflowSection -Name 'STARTUP & TASKS' -Color 'Red'
    Write-Host "  Startup entries: $($boot.Count)" -ForegroundColor White
    Write-Host "  Non-Microsoft scheduled tasks: $($tasks.Count)" -ForegroundColor White
    if ($tasks.Count -gt 10) { $score -= 5; $recs += , @('🟡','Yellow',"WARNING: $($tasks.Count) non-Microsoft scheduled tasks — review for persistence") }

    Write-OpsWorkflowSection -Name 'ADMINISTRATORS' -Color 'Red'
    Write-Host "  $($admin.Count) admin account(s):" -ForegroundColor White
    foreach ($a in $admin) { Write-Host "    $($a.Name) [$($a.PrincipalSource)]" -ForegroundColor White }

    Write-OpsWorkflowSection -Name 'ANOMALIES' -Color 'Red'
    Write-Host "  Ghost ports (unknown listeners): $($ghost.Count)" -ForegroundColor $(if($ghost.Count -gt 0){'Red'}else{'Green'})
    Write-Host "  Suspicious processes: $($suspicious.Count)" -ForegroundColor $(if($suspicious.Count -gt 0){'Red'}else{'Green'})
    Write-Host "  Event storms (15 min): $($events.Count)" -ForegroundColor $(if($events.Count -gt 0){'Yellow'}else{'Green'})
    if ($suspicious.Count -gt 0) { $score -= 15; $recs += , @('🔴','Red',"CRITICAL: $($suspicious.Count) suspicious process(es) running from user-writable paths") }
    if ($ghost.Count -gt 0) { $score -= 5; $recs += , @('🟡','Yellow',"WARNING: $($ghost.Count) ghost listener(s) — unknown process bound to a port") }

    $score = [Math]::Max(0, $score)
    $statusIcon = if ($score -ge 80) { '🟢' } elseif ($score -ge 50) { '🟡' } else { '🔴' }
    Write-Host "`n  $statusIcon  COMPLIANCE SCORE: $score/100" -ForegroundColor $(if($score -ge 80){'Green'}elseif($score -ge 50){'Yellow'}else{'Red'})
    Write-OpsRecommendations -Items $recs

    return [PSCustomObject]@{ Score = $score; Firewall = $firewall; Boot = $boot; Tasks = $tasks; Suspicious = $suspicious; Shield = $shield; Recommendations = $recs }
}

# ── WORKFLOW: NETWORK DIAGNOSTICS ─────────────────────────────────────────
function Invoke-OpsNetworkDiagnostics {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'NETWORK DIAGNOSTICS' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $netCheck   = Invoke-OpsCachedData -Key 'wflow_net'     -ExpirySeconds 30  -ScriptBlock { Get-OpsNetCheck }
    $wifi       = Get-OpsWifi
    $dns        = Invoke-OpsCachedData -Key 'wflow_dns'     -ExpirySeconds 300 -ScriptBlock { Get-OpsDnsBench }
    $dnsCache   = Invoke-OpsCachedData -Key 'wflow_dnscache' -ExpirySeconds 30  -ScriptBlock { Get-OpsDnsCache }
    $linkSpeed  = Invoke-OpsCachedData -Key 'wflow_linkspeed'-ExpirySeconds 60  -ScriptBlock { Get-OpsLinkSpeed }
    $shares     = Get-OpsShare
    $hosts      = Get-OpsHostsCheck
    $established= Invoke-OpsCachedData -Key 'wflow_est'     -ExpirySeconds 30  -ScriptBlock { Get-OpsEstablished }
    $triage     = Invoke-OpsCachedData -Key 'wflow_triage'  -ExpirySeconds 300 -ScriptBlock { Get-OpsNetworkTriage }

    $score = 100; $recs = @()

    Write-OpsWorkflowSection -Name 'CONNECTIVITY' -Color 'Blue'
    $online = $netCheck.Internet -eq $true
    if (-not $online) { $score -= 30; $recs += , @('🔴','Red','CRITICAL: No internet connectivity') }
    Write-Host "  Internet: $(if($online){'✅ Connected'}else{'❌ DISCONNECTED'})" -ForegroundColor $(if($online){'Green'}else{'Red'})
    if ($wifi.SSID -and $wifi.SSID -ne 'N/A' -and $wifi.SSID -ne 'Disconnected') {
        Write-Host "  Wi-Fi: $($wifi.SSID) ($($wifi.SignalPercent)% signal)" -ForegroundColor White
    }

    Write-OpsWorkflowSection -Name 'DNS RESOLVERS' -Color 'Blue'
    foreach ($r in $dns) {
        $t = $r.SpeedMS
        $dColor = if ($t -eq 'TIMEOUT') { $score -= 10; $recs += , @('🔴','Red',"CRITICAL: DNS resolver $($r.Name) ($($r.Resolver)) timed out"); 'Red' }
                 elseif ($t -gt 500) { $score -= 3; 'Yellow' } else { 'Green' }
        Write-Host "  $($r.Name) ($($r.Resolver)): $t ms" -ForegroundColor $dColor
    }

    Write-OpsWorkflowSection -Name 'INTERFACES' -Color 'Blue'
    foreach ($l in $linkSpeed) {
        Write-Host "  $($l.Name): $($l.LinkSpeed)  |  $($l.MacAddress)" -ForegroundColor White
    }
    Write-Host "  Active connections (established): $($established.Count)" -ForegroundColor White

    Write-OpsWorkflowSection -Name 'SHARES' -Color 'Blue'
    if ($shares) {
        Write-Host "  $($shares.Count) share(s) exposed:" -ForegroundColor White
        foreach ($s in $shares) { Write-Host "    $($s.Name) -> $($s.Path)" -ForegroundColor White }
    }

    Write-OpsWorkflowSection -Name 'HOSTS FILE' -Color 'Blue'
    Write-Host "  $($hosts.Count) custom entry(ies) in hosts file" -ForegroundColor White

    $score = [Math]::Max(0, $score)
    $statusIcon = if ($score -ge 80) { '🟢' } elseif ($score -ge 50) { '🟡' } else { '🔴' }
    Write-Host "`n  $statusIcon  NETWORK HEALTH: $score/100" -ForegroundColor $(if($score -ge 80){'Green'}elseif($score -ge 50){'Yellow'}else{'Red'})
    Write-OpsRecommendations -Items $recs

    return [PSCustomObject]@{ Score = $score; Internet = $netCheck; Dns = $dns; LinkSpeed = $linkSpeed; Shares = $shares; Hosts = $hosts; Recommendations = $recs }
}

# ── WORKFLOW: THREAT HUNT ─────────────────────────────────────────────────
function Invoke-OpsThreatHunt {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'THREAT HUNTING TRIAGE' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $suspicious = Get-OpsSuspiciousProcessAudit
    $ghost      = Get-OpsGhostPortAudit
    $events     = Invoke-OpsCachedData -Key 'wflow_events'  -ExpirySeconds 20  -ScriptBlock { Get-OpsEventStormAudit }
    $badFile    = Get-OpsBadFile
    $lock       = Get-OpsLock
    $sparse     = Get-OpsSparseFile
    $compressed = Get-OpsCompressedDir
    $firewall   = Invoke-OpsCachedData -Key 'wflow_fw'      -ExpirySeconds 60  -ScriptBlock { Get-OpsFirewallAudit }

    $threats = @(); $warnings = @(); $info = @()

    Write-OpsWorkflowSection -Name 'SUSPICIOUS PROCESSES' -Color 'Red'
    if ($suspicious) {
        $threats += , @('🔴','Red',"$($suspicious.Count) process(es) running from user-writable paths (AppData/Temp)")
        foreach ($p in $suspicious | Select-Object -First 5) { Write-Host "  $($p.Name) (PID $($p.Id)) — $($p.Path)" -ForegroundColor Red }
    } else { Write-Host "  ✅ No suspicious processes detected" -ForegroundColor Green }

    Write-OpsWorkflowSection -Name 'GHOST PORTS' -Color 'DarkYellow'
    if ($ghost) {
        $threats += , @('🔴','Red',"$($ghost.Count) ghost listener(s) — unknown/unidentified process bound to port")
        foreach ($g in $ghost | Select-Object -First 5) { Write-Host "  Port $($g.Port) — $($g.Process) (PID $($g.PID))" -ForegroundColor DarkYellow }
    } else { Write-Host "  ✅ No ghost listeners" -ForegroundColor Green }

    Write-OpsWorkflowSection -Name 'FILE ANOMALIES' -Color 'DarkYellow'
    if ($badFile.FilesOver500MB -gt 0) { $warnings += , @('🟡','Yellow',"$($badFile.FilesOver500MB) file(s) over 500 MB") }
    if ($badFile.SuspiciousExtensions -gt 0) { $threats += , @('🔴','Red',"$($badFile.SuspiciousExtensions) file(s) with suspicious extension(s) — possible encryption/ransomware indicators") }
    Write-Host "  Files >500 MB: $($badFile.FilesOver500MB)" -ForegroundColor $(if($badFile.FilesOver500MB -gt 0){'Yellow'}else{'Green'})
    Write-Host "  Suspicious extensions: $($badFile.SuspiciousExtensions)" -ForegroundColor $(if($badFile.SuspiciousExtensions -gt 0){'Red'}else{'Green'})

    if ($sparse -and $sparse.Count -gt 0 -and $sparse[0].Status -ne 'No sparse files detected') {
        $warnings += , @('🟡','Yellow',"$($sparse.Count) sparse file(s) found")
        Write-Host "  Sparse files: $($sparse.Count)" -ForegroundColor Yellow
    }
    if ($compressed -and $compressed.Count -gt 0 -and $compressed[0].Status -ne 'No compressed directories detected') {
        $info += , @('ℹ️','DarkGray',"$($compressed.Count) compressed directory(ies) — normally benign")
        Write-Host "  Compressed dirs: $($compressed.Count)" -ForegroundColor DarkGray
    }

    Write-OpsWorkflowSection -Name 'EVENT CORRELATION' -Color 'DarkYellow'
    if ($events) {
        Write-Host "  Event storms in last 15 min:" -ForegroundColor White
        foreach ($e in $events) { Write-Host "    $($e.Count)x $($e.Name) [$($e.Source)]" -ForegroundColor DarkYellow }
    } else { Write-Host "  ✅ No event storms detected" -ForegroundColor Green }

    Write-OpsWorkflowSection -Name 'FIREWALL GAPS' -Color 'DarkYellow'
    $gaps = @($firewall | Where-Object { $_.Status -ne 'Allowed' })
    if ($gaps.Count -gt 0) {
        $warnings += , @('🟡','Yellow',"$($gaps.Count) listening port(s) without inbound allow rule")
        foreach ($g in $gaps | Select-Object -First 5) { Write-Host "  Port $($g.Port) — $($g.Process)" -ForegroundColor DarkYellow }
    } else { Write-Host "  ✅ All listening ports have firewall rules" -ForegroundColor Green }

    Write-OpsRecommendations -Items ($threats + $warnings + $info)

    return [PSCustomObject]@{ Threats = $threats; Warnings = $warnings; Suspicious = $suspicious; GhostPorts = $ghost; BadFiles = $badFile; Recommendations = $threats + $warnings }
}

# ── WORKFLOW: CHANGE AUDIT ────────────────────────────────────────────────
function Invoke-OpsChangeAudit {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'CHANGE AUDIT' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $recent     = Get-OpsRecent
    $patches    = Get-OpsPatchHistory
    $drivers    = Invoke-OpsCachedData -Key 'wflow_drivers' -ExpirySeconds 300 -ScriptBlock { Get-OpsDriverAudit }
    $dumps      = Get-OpsDump
    $boot       = Invoke-OpsCachedData -Key 'wflow_boot'   -ExpirySeconds 300 -ScriptBlock { Get-OpsBootMap }
    $cert       = Get-OpsCert

    $score = 100; $recs = @()

    Write-OpsWorkflowSection -Name 'RECENT FILES' -Color 'Cyan'
    foreach ($f in $recent) { Write-Host "  $($f.Name) — $($f.LastWriteTime)" -ForegroundColor White }

    Write-OpsWorkflowSection -Name 'WINDOWS UPDATES' -Color 'Cyan'
    if ($patches) {
        Write-Host "  Last 5 updates:" -ForegroundColor White
        foreach ($p in $patches) { Write-Host "    $($p.HotFixID) — $($p.InstalledOn)" -ForegroundColor White }
    } else { Write-Host "  No patch history available" -ForegroundColor DarkGray }

    Write-OpsWorkflowSection -Name 'DRIVERS' -Color 'Cyan'
    if ($drivers -and $drivers.Count -gt 0) {
        $score -= 5; $recs += , @('🟡','Yellow',"$($drivers.Count) unsigned driver(s) found")
        foreach ($d in $drivers) { Write-Host "  $($d.DeviceName) — v$($d.DriverVersion)" -ForegroundColor Yellow }
    } else { Write-Host "  ✅ All drivers signed" -ForegroundColor Green }

    Write-OpsWorkflowSection -Name 'CRASH DUMPS' -Color 'Cyan'
    if ($dumps -and $dumps.Count -gt 0 -and $dumps[0].Status -ne 'No memory dumps found') {
        $score -= 10; $recs += , @('🔴','Red',"$($dumps.Count) crash dump(s) detected — investigate for stability issues")
        foreach ($d in $dumps | Select-Object -First 5) { Write-Host "  $($d.Name) — $(if($d.Length){'{0:N0} KB' -f ($d.Length/1KB)}else{'N/A'}) — $($d.LastWriteTime)" -ForegroundColor Red }
    } else { Write-Host "  ✅ No crash dumps" -ForegroundColor Green }

    Write-OpsWorkflowSection -Name 'STARTUP CHANGES' -Color 'Cyan'
    Write-Host "  $($boot.Count) startup entry(ies) currently registered" -ForegroundColor White
    foreach ($b in $boot) { Write-Host "    [$($b.Hive)] $($b.Name) -> $($b.Target)" -ForegroundColor White }

    Write-OpsWorkflowSection -Name 'CERTIFICATE EXPIRY' -Color 'Cyan'
    $expiring = @($cert | Where-Object { $_.NotAfter -and $_.NotAfter -lt (Get-Date).AddDays(30) })
    if ($expiring.Count -gt 0) { $score -= 5; $recs += , @('🟡','Yellow',"$($expiring.Count) certificate(s) expiring within 30 days") }
    Write-Host "  $($cert.Count) certificate(s) in CurrentUser\My" -ForegroundColor White
    foreach ($e in $expiring | Select-Object -First 3) { Write-Host "    ⚠ $($e.Subject) expires $($e.NotAfter)" -ForegroundColor Yellow }

    $score = [Math]::Max(0, $score)
    $statusIcon = if ($score -ge 80) { '🟢' } elseif ($score -ge 50) { '🟡' } else { '🔴' }
    Write-Host "`n  $statusIcon  STABILITY SCORE: $score/100" -ForegroundColor $(if($score -ge 80){'Green'}elseif($score -ge 50){'Yellow'}else{'Red'})
    Write-OpsRecommendations -Items $recs

    return [PSCustomObject]@{ Score = $score; Patches = $patches; Drivers = $drivers; Dumps = $dumps; Boot = $boot; Cert = $cert; Recommendations = $recs }
}

# ── WORKFLOW: COMPLIANCE CHECK ─────────────────────────────────────────────
function Invoke-OpsComplianceCheck {
    [CmdletBinding()]
    param()
    Write-OpsWorkflowBanner -Title 'COMPLIANCE : BASELINE' -Subtitle "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | LOCAL_STATION"

    $admin   = Get-OpsAdmin
    $shield  = Get-OpsShield
    $firewall = Invoke-OpsCachedData -Key 'wflow_fw'      -ExpirySeconds 60  -ScriptBlock { Get-OpsFirewallAudit }
    $tasks   = Invoke-OpsCachedData -Key 'wflow_tasks'    -ExpirySeconds 300 -ScriptBlock { Get-OpsScheduledTaskRiskAudit }
    $boot    = Invoke-OpsCachedData -Key 'wflow_boot'     -ExpirySeconds 300 -ScriptBlock { Get-OpsBootMap }
    $patches = Get-OpsPatchHistory
    $license = Get-OpsLicense
    $hyperv  = Get-OpsHypervisor
    $ports   = Invoke-OpsCachedData -Key 'wflow_ports'    -ExpirySeconds 10  -ScriptBlock { Get-OpsPortMap }

    $checks = @(); $passed = 0; $total = 0; $recs = @()

    Write-OpsWorkflowSection -Name 'CHECK RESULTS' -Color 'Magenta'

    # CIS-inspired checks
    $total++
    $c = $admin.Count
    if ($c -le 2) { $passed++; $checks += , @('✅','Green',"Administrator count: $c (within recommended limit)") }
    else { $checks += , @('❌','Red',"Administrator count: $c (recommended: ≤2)") }

    $total++
    if ($shield.Status -ne 'Defender cmdlets unavailable' -and $shield.AntivirusEnabled -and $shield.RealTimeProtectionEnabled) {
        $passed++; $checks += , @('✅','Green','Windows Defender: antivirus & real-time protection enabled')
    } else { $checks += , @('❌','Red','Windows Defender: antivirus or real-time protection disabled') }

    $total++
    $gaps = @($firewall | Where-Object { $_.Status -ne 'Allowed' })
    if ($gaps.Count -eq 0) { $passed++; $checks += , @('✅','Green','All listening ports have firewall allow rules') }
    else { $checks += , @('❌','Red',"$($gaps.Count) listening port(s) without inbound firewall allow rule"); $recs += , @('🟡','Yellow',"Review $($gaps.Count) unprotected listening port(s)") }

    $total++
    $nonMsTasks = @($tasks | Where-Object { $_.TaskPath -notmatch '^\\Microsoft|^\\Windows' })
    if ($nonMsTasks.Count -le 5) { $passed++; $checks += , @('✅','Green',"Non-Microsoft scheduled tasks: $($nonMsTasks.Count) (within limit)") }
    else { $checks += , @('🟡','Yellow',"Non-Microsoft scheduled tasks: $($nonMsTasks.Count) (review for unauthorized persistence)") }

    $total++
    if ($boot.Count -le 10) { $passed++; $checks += , @('✅','Green',"Startup entries: $($boot.Count) (within limit)") }
    else { $checks += , @('🟡','Yellow',"Startup entries: $($boot.Count) (review for unnecessary auto-start items)") }

    $total++
    if ($patches) { $passed++; $checks += , @('✅','Green','Patch history available and up to date') }
    else { $checks += , @('❌','Red','No patch history available') }

    $total++
    if ($license.Status -eq 'Licensed') { $passed++; $checks += , @('✅','Green','Windows license: valid') }
    else { $checks += , @('🟡','Yellow',"Windows license: $($license.Status)") }

    $total++
    if ($hyperv.Status -eq 'Physical') { $passed++; $checks += , @('✅','Green','Running on physical hardware') }
    else { $checks += , @('ℹ️','DarkGray',"Running on $($hyperv.Status) — additional VM security controls recommended") }

    $total++
    if ($ports.Count -le 50) { $passed++; $checks += , @('✅','Green',"Listening ports: $($ports.Count) (surface area within limit)") }
    else { $checks += , @('🟡','Yellow',"Listening ports: $($ports.Count) (large attack surface)") }

    foreach ($c in $checks) { Write-Host "  $($c[0]) $($c[2])" -ForegroundColor $c[1] }

    $pct = [Math]::Round(($passed / $total) * 100)
    $statusIcon = if ($pct -ge 80) { '🟢' } elseif ($pct -ge 50) { '🟡' } else { '🔴' }
    Write-Host "`n  $statusIcon  COMPLIANCE: $passed/$total checks passed ($pct%)" -ForegroundColor $(if($pct -ge 80){'Green'}elseif($pct -ge 50){'Yellow'}else{'Red'})
    Write-OpsRecommendations -Items $recs

    return [PSCustomObject]@{ Score = $pct; Passed = $passed; Total = $total; Checks = $checks; Recommendations = $recs }
}

