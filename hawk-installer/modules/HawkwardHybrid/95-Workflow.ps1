function Get-HawkNetCheck {
    <#
    .SYNOPSIS
    ICMP reachability probe with latency and loss summary.
    .PARAMETER Target
    Host(s) to ping. Defaults to 1.1.1.1 and 8.8.8.8.
    .PARAMETER Count
    Packets per target (default 4).
    .EXAMPLE
    Get-HawkNetCheck             # default targets
    Get-HawkNetCheck -Target gateway.local
    Function: Get-HawkNetCheck.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Target = @('1.1.1.1', '8.8.8.8'),
        [ValidateRange(1, 10)][int]$Count = 4
    )

    foreach ($t in $Target) {
        $replies = @(Test-Connection -TargetName $t -Count $Count -ErrorAction SilentlyContinue)
        $latencies = @($replies | ForEach-Object { $_.Latency } | Where-Object { $_ -ge 0 })
        $received = $latencies.Count
        $loss = [Math]::Round((($Count - $received) / $Count) * 100, 0)
        $avg = if ($received) { [Math]::Round(($latencies | Measure-Object -Average).Average, 1) } else { $null }
        $status = if ($received -eq $Count) { 'ONLINE' } elseif ($received -gt 0) { 'DEGRADED' } else { 'OFFLINE' }
        [pscustomobject]@{
            Target       = $t
            Sent         = $Count
            Received     = $received
            LossPercent  = $loss
            AvgLatencyMs = $avg
            Status       = $status
        }
    }
}

# ── Workflow engine ────────────────────────────────────────────────

function New-HawkCheckResult {
    <#
    .SYNOPSIS
    Builds one normalized workflow check result.
    .DESCRIPTION
    Scoring: with -ScoreRule the scriptblock receives $Data and returns
    0-100. Without one, data presence scores 80 (or 35/85 inverted via
    -EmptyIsGood). Errors collapse to score 0 / status ERROR.
    .EXAMPLE
    New-HawkCheckResult -Workflow secaudit -Check fw -Data (Get-HawkFirewallAudit)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Workflow,
        [Parameter(Mandatory)][string]$Check,
        [AllowNull()][object]$Data,
        [scriptblock]$ScoreRule,
        [string[]]$Recommendations = @(),
        [switch]$EmptyIsGood,
        [string]$StatusOverride
    )

    $hasData = ($null -ne $Data) -and (@($Data).Count -gt 0)
    $score = 50
    $err = $null

    if ($ScoreRule) {
        try { $score = [int](& $ScoreRule $Data) }
        catch { $err = $_.Exception.Message; $score = 0 }
    }
    elseif ($EmptyIsGood) { $score = if ($hasData) { 35 } else { 85 } }
    else { $score = if ($hasData) { 80 } else { 45 } }

    if ($StatusOverride) { $status = $StatusOverride }
    elseif ($err) { $status = 'ERROR' }
    elseif ($score -ge 80) { $status = 'OK' }
    elseif ($score -ge 50) { $status = 'WARN' }
    else { $status = 'CRIT' }

    if ($err) { $Recommendations = @($Recommendations) + ("Fix collection error on '{0}': {1}" -f $Check, $err) }
    elseif (-not $hasData -and -not $EmptyIsGood -and $score -lt 80) {
        $Recommendations = @($Recommendations) + ("No data returned for '{0}' - investigate." -f $Check)
    }

    [pscustomobject]@{
        Workflow        = $Workflow
        Check           = $Check
        Status          = $status
        Score           = [Math]::Max(0, [Math]::Min(100, $score))
        Details         = $Data
        Recommendations = @($Recommendations | Where-Object { $_ })
    }
}

function Complete-HawkWorkflow {
    <#
    .SYNOPSIS
    Aggregates check results into a scored workflow outcome object.
    .DESCRIPTION
    Overall Score is the rounded mean of check scores. Rating thresholds:
    >=80 GOOD, >=50 FAIR, otherwise RISK. Exposes .Score and
    .Recommendations so workflows pipeline cleanly.
    .EXAMPLE
    Complete-HawkWorkflow -Name sysreview -Checks $checks
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Checks
    )

    $avg = 0
    if ($Checks.Count) { $avg = [int][Math]::Round(($Checks | Measure-Object -Property Score -Average).Average) }
    $rating = if ($avg -ge 80) { 'GOOD' } elseif ($avg -ge 50) { 'FAIR' } else { 'RISK' }
    $recs = @($Checks | ForEach-Object { $_.Recommendations } | Where-Object { $_ } | Select-Object -Unique)

    [pscustomobject]@{
        Workflow        = $Name
        Score           = $avg
        Rating          = $rating
        CheckCount      = $Checks.Count
        Results         = @($Checks)
        Recommendations = $recs
    }
}

function Show-HawkWorkflowResult {
    <#
    .SYNOPSIS
    Renders a workflow outcome to the console.
    .EXAMPLE
    Show-HawkWorkflowResult (Invoke-HawkSecurityAudit)
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Result)

    Write-Host ("`n  {0} - SCORE {1}/100 [{2}] ({3} checks)" -f $Result.Workflow.ToUpperInvariant(), $Result.Score, $Result.Rating, $Result.CheckCount) -ForegroundColor Cyan

    foreach ($r in $Result.Results) {
        $color = switch ($r.Status) {
            'OK' { 'Green' }
            'CLEAN' { 'Green' }
            'WARN' { 'Yellow' }
            'INFO' { 'DarkGray' }
            default { 'Red' }
        }
        $marker = switch ($r.Status) { 'OK' { '[OK]' } 'CLEAN' { '[--]' } 'WARN' { '[!!]' } 'INFO' { '[--]' } default { '[XX]' } }
        Write-Host ('  {0} {1,-12} {2}/100' -f $marker, $r.Check, $r.Score) -NoNewline -ForegroundColor $color
        $summary = ''
        if ($null -ne $r.Details) {
            $count = @($r.Details).Count
            if ($count -gt 1) { $summary = " ($count items)" }
            elseif ($count -eq 1 -and $r.Details -is [string]) { $summary = ' (' + ([string]$r.Details).Substring(0, [Math]::Min(48, ([string]$r.Details).Length)) + ')' }
            elseif ($count -eq 1) { $summary = ' (1 item)' }
        }
        Write-Host $summary -ForegroundColor DarkGray
    }

    if ($Result.Recommendations.Count) {
        Write-Host '  RECOMMENDATIONS:' -ForegroundColor Magenta
        foreach ($rec in $Result.Recommendations) {
            Write-Host ('   - {0}' -f $rec) -ForegroundColor Yellow
        }
    }
}

# ── Aggregator workflows ───────────────────────────────────────────

function Invoke-HawkSystemReview {
    <#
    .SYNOPSIS
    Full system review across 11 diagnostic checks.
    .DESCRIPTION
    Runs spec, health, uptime, ram, disk, res, port, temp, hyperv, power
    and license checks; prints a scored summary and returns the aggregate
    object (exposes .Score and .Recommendations).
    .EXAMPLE
    sysreview | ForEach-Object { $_.Score }
    Alias: sysreview.
    #>
    [CmdletBinding()]
    param()

    $wf = 'sysreview'
    $checks = @(
        (New-HawkCheckResult -Workflow $wf -Check 'spec'    -Data (Get-HawkSpecs)),
        (New-HawkCheckResult -Workflow $wf -Check 'health'  -Data (Get-HawkDoctor)),
        (New-HawkCheckResult -Workflow $wf -Check 'uptime'  -Data (Get-HawkUptime) -ScoreRule {
                param($d)
                $days = $null
                foreach ($p in 'TotalDays', 'Days', 'UptimeDays') {
                    if ($d -and $d.PSObject.Properties[$p]) { $days = [double]$d.$p; break }
                }
                if ($null -eq $days -and $d -and $d.PSObject.Properties['Uptime'] -and $d.Uptime) { $days = ((Get-Date) - $d.Uptime).TotalDays }
                if ($null -eq $days) { return 75 }
                if ($days -le 14) { return 90 } elseif ($days -le 30) { return 70 } else { return 50 }
            }),
        (New-HawkCheckResult -Workflow $wf -Check 'ram'     -Data (Get-HawkRamInfo)),
        (New-HawkCheckResult -Workflow $wf -Check 'disk'    -Data (Get-HawkDiskPressureAudit) -ScoreRule {
                param($d)
                foreach ($row in @($d)) {
                    foreach ($p in 'FreePercent', 'FreeSpacePercent', 'FreePct') {
                        if ($row -and $row.PSObject.Properties[$p]) {
                            $free = [double]$row.$p
                            if ($free -gt 25) { return 90 } elseif ($free -gt 15) { return 70 } else { return 40 }
                        }
                    }
                }
                return 75
            }),
        (New-HawkCheckResult -Workflow $wf -Check 'res'     -Data (Get-HawkResourceMap)),
        (New-HawkCheckResult -Workflow $wf -Check 'port'    -Data (Get-HawkPortMap)),
        (New-HawkCheckResult -Workflow $wf -Check 'temp'    -Data (Get-HawkThermals)),
        (New-HawkCheckResult -Workflow $wf -Check 'hyperv'  -Data (Get-HawkHypervisor)),
        (New-HawkCheckResult -Workflow $wf -Check 'power'   -Data (Get-HawkPower)),
        (New-HawkCheckResult -Workflow $wf -Check 'license' -Data (Get-HawkLicense))
    )

    $result = Complete-HawkWorkflow -Name $wf -Checks $checks
    Show-HawkWorkflowResult -Result $result
    return $result
}

function Invoke-HawkSecurityAudit {
    <#
    .SYNOPSIS
    Security posture audit across 8 checks.
    .DESCRIPTION
    Firewall, boot persistence, scheduled-task risk, ghost ports, suspicious
    processes, event storms, admin group and Defender shield state.
    .EXAMPLE
    secaudit | ForEach-Object { $_.Recommendations }
    Alias: secaudit.
    #>
    [CmdletBinding()]
    param()

    $wf = 'secaudit'
    $checks = @(
        (New-HawkCheckResult -Workflow $wf -Check 'fw'        -Data (Get-HawkFirewallAudit)),
        (New-HawkCheckResult -Workflow $wf -Check 'boot'      -Data (Get-HawkBootMap)),
        (New-HawkCheckResult -Workflow $wf -Check 'schedtask' -Data (Get-HawkScheduledTaskRiskAudit)),
        (New-HawkCheckResult -Workflow $wf -Check 'ghost'     -Data (Get-HawkGhostPortAudit)),
        (New-HawkCheckResult -Workflow $wf -Check 'sus'       -Data (Get-HawkSuspiciousProcessAudit)),
        (New-HawkCheckResult -Workflow $wf -Check 'storm'     -Data (Get-HawkEventStormAudit)),
        (New-HawkCheckResult -Workflow $wf -Check 'admin'     -Data (Get-HawkAdmins)),
        (New-HawkCheckResult -Workflow $wf -Check 'shield'    -Data (Get-HawkShield))
    )

    $result = Complete-HawkWorkflow -Name $wf -Checks $checks
    Show-HawkWorkflowResult -Result $result
    return $result
}

function Invoke-HawkNetworkDiagnostics {
    <#
    .SYNOPSIS
    Network diagnostics across 9 checks.
    .DESCRIPTION
    ICMP reachability, wifi, DNS bench, DNS cache, link speed, shares,
    hosts file, established connections and full network triage.
    .EXAMPLE
    netdiag | Select-Object Score, Rating
    Alias: netdiag.
    #>
    [CmdletBinding()]
    param()

    $wf = 'netdiag'
    $checks = @(
        (New-HawkCheckResult -Workflow $wf -Check 'ping'        -Data (Get-HawkNetCheck) -ScoreRule {
                param($d)
                $online = @(@($d) | Where-Object { $_.Status -eq 'ONLINE' }).Count
                $total = @(@($d)).Count
                if ($online -eq $total) { return 95 } elseif ($online -gt 0) { return 60 } else { return 10 }
            }),
        (New-HawkCheckResult -Workflow $wf -Check 'wifi'        -Data (Get-HawkWifi)),
        (New-HawkCheckResult -Workflow $wf -Check 'dns'         -Data (Get-HawkDnsBench)),
        (New-HawkCheckResult -Workflow $wf -Check 'dnscache'    -Data (Get-HawkDnsCache)),
        (New-HawkCheckResult -Workflow $wf -Check 'linkspeed'   -Data (Get-HawkLinkSpeed)),
        (New-HawkCheckResult -Workflow $wf -Check 'shares'      -Data (Get-HawkShares)),
        (New-HawkCheckResult -Workflow $wf -Check 'hosts'       -Data (Get-HawkHostsCheck)),
        (New-HawkCheckResult -Workflow $wf -Check 'established' -Data (Get-HawkTcpListeners)),
        (New-HawkCheckResult -Workflow $wf -Check 'nettriage'   -Data (Get-HawkNetworkTriage))
    )

    $result = Complete-HawkWorkflow -Name $wf -Checks $checks
    Show-HawkWorkflowResult -Result $result
    return $result
}

function Invoke-HawkThreatHunt {
    <#
    .SYNOPSIS
    Threat hunt across 8 hunt surfaces with severity classification.
    .DESCRIPTION
    Classifies each surface as THREAT (suspicious processes, bad files,
    ghost ports), WARN (event storms, firewall findings) or INFO (locked
    files, sparse/compress candidates). Overall score drops 15 per THREAT
    and 7 per WARN from a base of 100.
    .EXAMPLE
    threathunt | Select-Object Score, Rating
    Alias: threathunt.
    #>
    [CmdletBinding()]
    param()

    $wf = 'threathunt'
    $defs = @(
        @{ Check = 'sus';      Cmd = { Get-HawkSuspiciousProcessAudit }; Severity = 'THREAT' },
        @{ Check = 'ghost';    Cmd = { Get-HawkGhostPortAudit };         Severity = 'THREAT' },
        @{ Check = 'badfiles'; Cmd = { Get-HawkBadFiles };               Severity = 'THREAT' },
        @{ Check = 'storm';    Cmd = { Get-HawkEventStormAudit };        Severity = 'WARN' },
        @{ Check = 'fw';       Cmd = { Get-HawkFirewallAudit };          Severity = 'WARN' },
        @{ Check = 'locked';   Cmd = { Get-HawkLocked };                 Severity = 'INFO' },
        @{ Check = 'sparse';   Cmd = { Get-HawkSparse };                 Severity = 'INFO' },
        @{ Check = 'compress'; Cmd = { Get-HawkCompress };               Severity = 'INFO' }
    )

    $checks = @()
    foreach ($def in $defs) {
        $data = $null
        $err = $null
        try { $data = & $def.Cmd } catch { $err = $_.Exception.Message }
        $hasData = ($null -ne $data) -and (@($data).Count -gt 0)

        $status = if ($err) { 'ERROR' } elseif (-not $hasData) { 'CLEAN' } else { $def.Severity }
        $score = switch ($status) {
            'CLEAN' { 95 }
            'THREAT' { 20 }
            'WARN' { 45 }
            'INFO' { 60 }
            default { 0 }
        }
        $recs = @()
        if ($err) { $recs += ("Fix collection error on '{0}': {1}" -f $def.Check, $err) }
        elseif ($status -eq 'THREAT') { $recs += ("THREAT: review {0} findings immediately (run the underlying audit for detail)." -f $def.Check) }
        elseif ($status -eq 'WARN') { $recs += ("Review {0} warnings." -f $def.Check) }

        $checks += [pscustomobject]@{
            Workflow        = $wf
            Check           = $def.Check
            Status          = $status
            Score           = $score
            Details         = $data
            Recommendations = $recs
        }
    }

    $nThreat = @($checks | Where-Object Status -eq 'THREAT').Count
    $nWarn = @($checks | Where-Object Status -eq 'WARN').Count
    $score = [Math]::Max(5, 100 - (15 * $nThreat) - (7 * $nWarn))
    $rating = if ($nThreat -gt 0) { 'RISK' } elseif ($score -ge 80) { 'GOOD' } elseif ($score -ge 50) { 'FAIR' } else { 'RISK' }
    $result = [pscustomobject]@{
        Workflow        = $wf
        Score           = $score
        Rating          = $rating
        CheckCount      = $checks.Count
        Results         = @($checks)
        Recommendations = @($checks | ForEach-Object { $_.Recommendations } | Where-Object { $_ } | Select-Object -Unique)
    }

    Show-HawkWorkflowResult -Result $result
    return $result
}

function Invoke-HawkChangeAudit {
    <#
    .SYNOPSIS
    Change-tracking audit across 6 surfaces.
    .DESCRIPTION
    Recent activity, patch history, driver changes, crash dumps, boot
    persistence and certificate stores - answers "what changed lately?".
    .EXAMPLE
    change | Select-Object Score
    Alias: change.
    #>
    [CmdletBinding()]
    param()

    $wf = 'change'
    $checks = @(
        (New-HawkCheckResult -Workflow $wf -Check 'recent'  -Data (Get-HawkRecent)),
        (New-HawkCheckResult -Workflow $wf -Check 'patches' -Data (Get-HawkPatchHistory)),
        (New-HawkCheckResult -Workflow $wf -Check 'drivers' -Data (Get-HawkDriverAudit)),
        (New-HawkCheckResult -Workflow $wf -Check 'dumps'   -Data (Get-HawkDumps)),
        (New-HawkCheckResult -Workflow $wf -Check 'boot'    -Data (Get-HawkBootMap)),
        (New-HawkCheckResult -Workflow $wf -Check 'certs'   -Data (Get-HawkCerts))
    )

    $result = Complete-HawkWorkflow -Name $wf -Checks $checks
    Show-HawkWorkflowResult -Result $result
    return $result
}

function Invoke-HawkComplianceCheck {
    <#
    .SYNOPSIS
    CIS-inspired compliance posture across 9 controls.
    .DESCRIPTION
    Admin group hygiene, Defender shield, firewall gaps, risky scheduled
    tasks, boot persistence, patch currency, licensing, hypervisor state
    and listener exposure. Empty result sets score as PASS where absence
    of findings is the desired state.
    .EXAMPLE
    compliance | Select-Object Score, Rating
    Alias: compliance.
    #>
    [CmdletBinding()]
    param()

    $wf = 'compliance'
    $checks = @(
        (New-HawkCheckResult -Workflow $wf -Check 'admin'     -Data (Get-HawkAdmins) -ScoreRule {
                param($d)
                $n = @($d).Count
                if ($n -le 2) { return 90 } elseif ($n -le 4) { return 65 } else { return 35 }
            }),
        (New-HawkCheckResult -Workflow $wf -Check 'shield'    -Data (Get-HawkShield)),
        (New-HawkCheckResult -Workflow $wf -Check 'fw'        -Data (Get-HawkFirewallAudit) -EmptyIsGood),
        (New-HawkCheckResult -Workflow $wf -Check 'schedtask' -Data (Get-HawkScheduledTaskRiskAudit) -EmptyIsGood),
        (New-HawkCheckResult -Workflow $wf -Check 'boot'      -Data (Get-HawkBootMap)),
        (New-HawkCheckResult -Workflow $wf -Check 'patches'   -Data (Get-HawkPatchHistory)),
        (New-HawkCheckResult -Workflow $wf -Check 'license'   -Data (Get-HawkLicense)),
        (New-HawkCheckResult -Workflow $wf -Check 'hyperv'    -Data (Get-HawkHypervisor)),
        (New-HawkCheckResult -Workflow $wf -Check 'ports'     -Data (Get-HawkTcpListeners) -ScoreRule {
                param($d)
                $n = @($d).Count
                if ($n -lt 30) { return 85 } elseif ($n -lt 80) { return 65 } else { return 35 }
            })
    )

    $result = Complete-HawkWorkflow -Name $wf -Checks $checks
    Show-HawkWorkflowResult -Result $result
    return $result
}

