# ── PUBLIC: REPORT & DASHBOARD ─────────────────────────────────────────────

function ConvertTo-HawkMarkdownTable {
    param([object[]]$InputObject, [string]$Section = '')
    $rows = @($InputObject | Where-Object { $null -ne $_ }); if (-not $rows) { return '_No transactional metrics encountered._' }
    $props = @($rows[0].PSObject.Properties.Name)
    $widths = @{ Endpoint = 32; Model = 64; Modified = 20; ProcessName = 28; Company = 28; Name = 42; Target = 76; Source = 48; TaskPath = 34; TaskName = 52; Path = 72; Args = 72; Status = 56; MatchedRule = 32; LastCommit = 56 }
    if ($Section -eq 'Startup') { $widths.Name = 38; $widths.Target = 72; $widths.Source = 44 }
    $fRows = foreach ($r in $rows) {
        $ordered = [ordered]@{}; foreach ($p in $props) { $ordered[$p] = Format-HawkMarkdownCell -Text ([string]$r.PSObject.Properties[$p].Value) -MaxWidth ($widths.ContainsKey($p) ? [int]$widths[$p] : 0) }
        [PSCustomObject]$ordered
    }
    $colWidths = [ordered]@{}; foreach ($p in $props) { $max = $p.Length; foreach ($fr in $fRows) { $len = ([string]$fr.PSObject.Properties[$p].Value).Length; if($len -gt $max){$max = $len} }; $colWidths[$p] = [Math]::Max(3, $max) }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| ' + (($props | ForEach-Object { $_.PadRight($colWidths[$_]) }) -join ' | ') + ' |')
    $lines.Add('| ' + (($props | ForEach-Object { '-' * $colWidths[$_] }) -join ' | ') + ' |')
    foreach ($fr in $fRows) { $lines.Add('| ' + (($props | ForEach-Object { ([string]$fr.PSObject.Properties[$_].Value).PadRight($colWidths[$_]) }) -join ' | ') + ' |') }
    return ($lines -join [Environment]::NewLine)
}

function ConvertTo-HawkReportMarkdown {
    param($Report)
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('# PowershellOps Hybrid Structural Triage Report'); $lines.Add("Generated: $($Report.Generated)`n")
    foreach ($section in @('AI', 'Disk', 'Resources', 'Ports', 'FirewallGaps', 'Startup', 'ScheduledTaskRisks', 'EventStorms')) {
        $lines.Add("## $section`n"); $lines.Add((ConvertTo-HawkMarkdownTable -InputObject $Report[$section] -Section $section))
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-HawkReportTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', 'Intentional console table rendering')]
    [CmdletBinding()]
    param([string]$Title, [hashtable[]]$Columns, [object[]]$InputObject = @(), [string]$Icon = '•', [string]$AnsiColor = '153', [int]$MaxRows = 0)
    $rows = @($InputObject | Where-Object { $null -ne $_ }); $vRows = if ($MaxRows -gt 0) { @($rows | Select-Object -First $MaxRows) } else { $rows }
    $w = (($Columns | ForEach-Object { [int]$_.Width } | Measure-Object -Sum).Sum + (($Columns.Count - 1) * 2))
    $esc = [char]27
    $reset = "${esc}[0m"
    Write-Host "`n  ${esc}[48;5;$AnsiColor;38;5;16m $Icon $Title ${reset}"
    Write-Host "  ${esc}[38;5;246m$('─' * [Math]::Max(1, $w))${reset}"
    if (-not $rows) { Write-Host "  ${esc}[38;5;158m✓ Evaluation parameters stable. No actionable telemetry.${reset}"; return }
    Write-Host ('  ' + (($Columns | ForEach-Object { $hdr = if ($_.Label) { $_.Label } else { $_.Name }; Format-HawkReportCell -Text ($hdr) -Width ([int]$_.Width) }) -join '  ')) -ForegroundColor DarkGray
    foreach ($r in $vRows) {
        Write-Host ('  ' + (($Columns | ForEach-Object {
            $val = if ($_.Expression) { & $_.Expression $r } else { $r.PSObject.Properties[$_.Name].Value }
            Format-HawkReportCell -Text ([string]$val) -Width ([int]$_.Width)
        }) -join '  ')) -ForegroundColor White
    }
}

function New-HawkReport {
    [CmdletBinding(SupportsShouldProcess=$true)] param([ValidateSet('Console', 'Markdown', 'Json')][string]$Format = 'Console', [string]$Path)
    $prev = $script:HawkSuppressHeaders; $script:HawkSuppressHeaders = $true
    try {
        $report = [ordered]@{
            Generated          = Get-Date
            AI                 = @(Get-HawkAIStatus)
            Disk               = @(Get-HawkDiskPressureAudit)
            Resources          = @(Get-HawkResourceMap)
            Ports              = @(Get-HawkPortMap)
            FirewallGaps       = @(Get-HawkFirewallAudit)
            Startup            = @(Get-HawkBootMap)
            ScheduledTaskRisks = @(Get-HawkScheduledTaskRiskAudit)
            EventStorms        = @(Get-HawkEventStormAudit)
        }
    } finally { $script:HawkSuppressHeaders = $prev }
    $md = ConvertTo-HawkReportMarkdown -Report $report
    if ($Format -eq 'Console') {
        $outPath = if ($Path) { $Path } else { Get-HawkReportPath -Ext md }
        if ($PSCmdlet.ShouldProcess("Report file: $outPath", 'Save report')) {
            Set-Content -Path $outPath -Value $md -Encoding UTF8
        }

        # Pastel Colors: AI=183(Lavender), Sys=158(Mint), Sec=217(Coral), Net=153(Sky), Run=230(Champagne)
        Write-HawkReportTable -Title 'AI Engine Node Status' -Icon '🤖' -AnsiColor '183' -InputObject $report.AI -Columns @(@{Name='Endpoint';Width=20},@{Name='Status';Width=12},@{Name='Model';Width=20})
        Write-HawkReportTable -Title 'System Volume State' -Icon '▰' -AnsiColor '158' -InputObject $report.Disk -Columns @(@{Name='DeviceID';Width=8},@{Name='SizeGB';Width=9},@{Name='FreeGB';Width=9},@{Name='FreePercent';Width=12})
        Write-HawkReportTable -Title 'Active Engine Consumer Workspace' -Icon '▤' -AnsiColor '217' -InputObject $report.Resources -Columns @(@{Name='ProcessName';Width=18},@{Name='Id';Width=7},@{Name='RAMMB';Width=8},@{Name='CPUSec';Width=8})
        Write-HawkReportTable -Title 'Assigned Interface Socket Network Map' -Icon '◦' -AnsiColor '153' -InputObject $report.Ports -Columns @(@{Name='Port';Width=6},@{Name='PID';Width=6},@{Name='Process';Width=18})
        Write-HawkReportTable -Title 'Threat Vector Firewall Gaps' -Icon '▣' -AnsiColor '217' -InputObject $report.FirewallGaps -Columns @(@{Name='Port';Width=6},@{Name='PID';Width=6},@{Name='Process';Width=18},@{Name='Status';Width=40})
        Write-HawkReportTable -Title 'Platform Persistence Startup Hooks' -Icon '⌂' -AnsiColor '158' -InputObject $report.Startup -Columns @(@{Name='Hive';Width=6},@{Name='Name';Width=15},@{Name='Target';Width=45})
        Write-HawkReportTable -Title 'Automated Execution Risk Vectors' -Icon '⌁' -AnsiColor '217' -InputObject $report.ScheduledTaskRisks -Columns @(@{Name='TaskName';Width=20},@{Name='Path';Width=30})
        Write-HawkReportTable -Title 'System Log Notification Storm Events' -Icon '↯' -AnsiColor '217' -InputObject $report.EventStorms -Columns @(@{Name='Count';Width=6},@{Name='Name';Width=6},@{Name='Source';Width=20})
        return
    }
    $output = if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 8 } else { $md }
    if ($Path) { if ($PSCmdlet.ShouldProcess("Report file: $Path", 'Save report')) { Set-Content -Path $Path -Value $output -Encoding UTF8 } } else { $output }
}

function Show-HawkDashboard {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding()]
    param()
    $esc = [char]27
    $reset = "${esc}[0m"
    $aiStatus = try { $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 -ErrorAction Stop; 'ACTIVE' } catch { 'OFFLINE' }
    $pRoot = $global:HawkProjectRoot ?? $script:HawkDefaultProjectRoot
    $cWidth = [Math]::Max(80, (try { [Console]::WindowWidth } catch { 120 }))

    $isNerd = Test-HawkNerdFont
    $sep = if ($isNerd) { '' } else { '>' }
    $rsep = if ($isNerd) { '' } else { '<' }

    # Soft Pastel Palette (256-color ANSI)
    $c = @{
        Core   = "158" # Mint
        Vers   = "246" # Soft Gray
        AI     = "153" # Sky Blue
        Sys    = "158" # Mint
        Sec    = "217" # Soft Coral
        Net    = "153" # Sky Blue
        Aim    = "183" # Lavender
        Run    = "230" # Champagne
        Env    = "244" # Medium Gray
    }

    # Header Segment
    Write-Host "`n"
    Write-Host " ${esc}[48;5;$($c.Core)m${esc}[38;5;16m HAWK : CORE ${reset}${esc}[38;5;$($c.Core)m${esc}[48;5;$($c.Vers)m$sep${reset}" -NoNewline
    Write-Host "${esc}[38;5;15m v$script:HawkVersion ${reset}${esc}[38;5;$($c.Vers)m${esc}[48;5;$($c.AI)m$sep${reset}" -NoNewline
    Write-Host "${esc}[38;5;16m AI: $aiStatus ${reset}${esc}[38;5;$($c.AI)m$sep${reset}"

    $categories = @(
        @{ Icon = '󰒓'; Name = 'SYSTEM';   Bg = $c.Sys; Cmds = @('corehealth','sysspec','sysuptime','ramstats','battstatus','gpuview','powertriage','vmcheck','liccheck','diskpressure','tempcheck','clipcheck','smartstatus','resourcemap','portmap') }
        @{ Icon = '󰒕'; Name = 'SECURITY'; Bg = $c.Sec; Cmds = @('adminaudit','shieldstatus','fwcheck','bootmap','taskrisk','ghostports','susprocs','eventstorm','certaudit','dumpmap','filecheck','shortcutcheck','lockcheck','sparsecheck','compresscheck','patchhistory','driveraudit','recentfiles','secretmask') }
        @{ Icon = '󰒢'; Name = 'NETWORK';  Bg = $c.Net; Cmds = @('netping','wificheck','peerscheck','dnsbench','netspeed','smbshares','hostscheck','dnsmap','nettriage') }
        @{ Icon = '󰒙'; Name = 'AI/MEM';   Bg = $c.Aim; Cmds = @('askai','websearch','aistatus','aiintent','aiprofile','sourcequality','safetycheck','airemember','airecall','memorymap','memoryread','memoryfile') }
        @{ Icon = '󰒖'; Name = 'RUN';      Bg = $c.Run; Cmds = @('dailycheck','sysreview','secaudit','netdiag','threathunt','changeaudit','compliancecheck','fullreport') }
    )

    $headerWidth = 14
    $colWidth = 16

    foreach ($cat in $categories) {
        $icon = if ($isNerd) { $cat.Icon } else { '' }
        $label = "$icon $($cat.Name)".Trim()

        Write-Host " ${esc}[48;5;$($cat.Bg)m${esc}[38;5;16m $($label.PadRight($headerWidth - 1)) ${reset}" -NoNewline
        Write-Host "${esc}[38;5;$($cat.Bg)m$sep${reset} " -NoNewline

        $lineCmds = 0
        $maxLineCmds = [Math]::Floor(($cWidth - $headerWidth - 4) / $colWidth)

        for ($i = 0; $i -lt $cat.Cmds.Count; $i++) {
            if ($lineCmds -ge $maxLineCmds) {
                Write-Host ""
                Write-Host (" " * $headerWidth) -NoNewline
                Write-Host "  " -NoNewline
                $lineCmds = 0
            }
            Write-Host ($cat.Cmds[$i].PadRight($colWidth)) -NoNewline -ForegroundColor White
            $lineCmds++
        }
        Write-Host ""
    }

    # Environment Footer
    Write-Host "`n " -NoNewline
    Write-Host "${esc}[38;5;$($c.Env)m$rsep${reset}" -NoNewline
    Write-Host "${esc}[48;5;$($c.Env)m${esc}[38;5;15m ENV: ${reset}" -NoNewline
    Write-Host "${esc}[48;5;238m${esc}[38;5;250m  $($pRoot)  ${reset}${esc}[38;5;238m$sep${reset}"
}

function Watch-HawkDashboard {
    [CmdletBinding()]
    param([int]$IntervalSeconds = 2)
    if (-not (Test-HawkInteractiveSession)) { Write-Warning "Dashboard requires an interactive terminal session."; return }
    Write-Information "  [Watch] Dashboard live refresh every ${IntervalSeconds}s. Press Ctrl+C to exit." -InformationAction Continue
    while ($true) { Clear-Host; Show-HawkDashboard; Start-Sleep -Seconds $IntervalSeconds }
}

