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
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('# Hawkward Hybrid Structural Triage Report'); $lines.Add("Generated: $($Report.Generated)`n")
    foreach ($section in @('AI', 'Disk', 'Resources', 'Ports', 'FirewallGaps', 'Startup', 'ScheduledTaskRisks', 'EventStorms')) {
        $lines.Add("## $section`n"); $lines.Add((ConvertTo-HawkMarkdownTable -InputObject $Report[$section] -Section $section))
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-HawkReportTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', 'Intentional console table rendering')]
    [CmdletBinding()]
    param([string]$Title, [hashtable[]]$Columns, [object[]]$InputObject = @(), [string]$Icon = '•', [ConsoleColor]$Color = 'Cyan', [int]$MaxRows = 0)
    $rows = @($InputObject | Where-Object { $null -ne $_ }); $vRows = if ($MaxRows -gt 0) { @($rows | Select-Object -First $MaxRows) } else { $rows }
    $w = (($Columns | ForEach-Object { [int]$_.Width } | Measure-Object -Sum).Sum + (($Columns.Count - 1) * 2))
    Write-Host "`n  $Icon $Title" -ForegroundColor $Color; Write-Host "  $('─' * [Math]::Max(1, $w))" -ForegroundColor DarkGray
    if (-not $rows) { Write-Host '  ✓ Evaluation parameters stable. No actionable telemetry.' -ForegroundColor Green; return }
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

        Write-HawkReportTable -Title 'AI Engine Node Status' -Icon '🤖' -Color Magenta -InputObject $report.AI -Columns @(@{Name='Endpoint';Width=20},@{Name='Status';Width=12},@{Name='Model';Width=20})
        Write-HawkReportTable -Title 'System Volume State' -Icon '▰' -Color Yellow -InputObject $report.Disk -Columns @(@{Name='DeviceID';Width=8},@{Name='SizeGB';Width=9},@{Name='FreeGB';Width=9},@{Name='FreePercent';Width=12})
        Write-HawkReportTable -Title 'Active Engine Consumer Workspace' -Icon '▤' -Color Red -InputObject $report.Resources -Columns @(@{Name='ProcessName';Width=18},@{Name='Id';Width=7},@{Name='RAMMB';Width=8},@{Name='CPUSec';Width=8})
        Write-HawkReportTable -Title 'Assigned Interface Socket Network Map' -Icon '◦' -Color Cyan -InputObject $report.Ports -Columns @(@{Name='Port';Width=6},@{Name='PID';Width=6},@{Name='Process';Width=18})
        Write-HawkReportTable -Title 'Threat Vector Firewall Gaps' -Icon '▣' -Color DarkYellow -InputObject $report.FirewallGaps -Columns @(@{Name='Port';Width=6},@{Name='PID';Width=6},@{Name='Process';Width=18},@{Name='Status';Width=40})
        Write-HawkReportTable -Title 'Platform Persistence Startup Hooks' -Icon '⌂' -Color Blue -InputObject $report.Startup -Columns @(@{Name='Hive';Width=6},@{Name='Name';Width=15},@{Name='Target';Width=45})
        Write-HawkReportTable -Title 'Automated Execution Risk Vectors' -Icon '⌁' -Color DarkYellow -InputObject $report.ScheduledTaskRisks -Columns @(@{Name='TaskName';Width=20},@{Name='Path';Width=30})
        Write-HawkReportTable -Title 'System Log Notification Storm Events' -Icon '↯' -Color DarkRed -InputObject $report.EventStorms -Columns @(@{Name='Count';Width=6},@{Name='Name';Width=6},@{Name='Source';Width=20})
        return
    }
    $output = if ($Format -eq 'Json') { $report | ConvertTo-Json -Depth 8 } else { $md }
    if ($Path) { if ($PSCmdlet.ShouldProcess("Report file: $Path", 'Save report')) { Set-Content -Path $Path -Value $output -Encoding UTF8 } } else { $output }
}

function Show-HawkDashboard {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding()]
    param()
    $aiStatus = try { $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 -ErrorAction Stop; 'ACTIVE' } catch { 'STANDBY' }
    $pRoot = if ($global:HawkProjectRoot) { $global:HawkProjectRoot } else { $script:HawkDefaultProjectRoot }
    $fit = { param([string]$Text, [int]$Width) if ($Width -le 0) { '' }; if ($null -eq $Text) { '' }; if ($Text.Length -gt $Width) { return $Text.Substring(0, $Width - 1) + '…' }; $Text.PadRight($Width) }

    $cWidth = try { [Console]::WindowWidth } catch { 120 }; if ($cWidth -lt 1) { $cWidth = 120 }
    $dbWidth = [Math]::Max(78, [Math]::Min(($cWidth - 4), 150)); $boxTextWidth = $dbWidth - 2; $gap = '  '
    $colCount = if ($dbWidth -ge 116) { 4 } elseif ($dbWidth -ge 76) { 2 } else { 1 }
    $colWidth = [int][Math]::Floor(($dbWidth - (($colCount - 1) * $gap.Length)) / $colCount); $rule = '─' * $dbWidth

    Write-Host "`n  ╭$rule╮" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fit "🦅 HAWKWARD HYBRID $script:HawkVersion · ALL COMMANDS" $boxTextWidth) -ForegroundColor Cyan -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ├$rule┤" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fit "AI: $aiStatus    |    Workspace: $pRoot" $boxTextWidth) -ForegroundColor DarkGray -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ╰$rule╯`n" -ForegroundColor DarkGray

    $aliases = @{}
    Get-Alias | Where-Object { $_.Definition -match '^(Get|Invoke|Add|Search|Read|Test|Set|New|Update|Build|Format|Convert|Protect|Resolve|Show|Watch|Write)-Hawk' } | ForEach-Object { $aliases[$_.Definition] = $_.Name }

    $categories = @(
        @{ Name = '🖥️ SYSTEM'; Color = 'Cyan'; Sub = @(
            @{ Name = 'Health'; Cmd = @('Get-HawkHealth','Get-HawkSpec','Get-HawkUptime') }
            @{ Name = 'Hardware'; Cmd = @('Get-HawkRamInfo','Get-HawkBattery','Get-HawkDisplay','Get-HawkHypervisor','Get-HawkPower','Get-HawkLicense') }
            @{ Name = 'Storage'; Cmd = @('Get-HawkDiskPressureAudit','Get-HawkTempCheck','Get-HawkClipCheck','Get-HawkDriveHealth') }
            @{ Name = 'Perf'; Cmd = @('Get-HawkResourceMap','Get-HawkPortMap') }
        )}
        @{ Name = '🛡️ SECURITY'; Color = 'Red'; Sub = @(
            @{ Name = 'Access'; Cmd = @('Get-HawkAdmin','Get-HawkShield') }
            @{ Name = 'Firewall'; Cmd = @('Get-HawkFirewallAudit') }
            @{ Name = 'Persistence'; Cmd = @('Get-HawkBootMap','Get-HawkScheduledTaskRiskAudit') }
            @{ Name = 'Anomalies'; Cmd = @('Get-HawkGhostPortAudit','Get-HawkSuspiciousProcessAudit','Get-HawkEventStormAudit') }
            @{ Name = 'Inventory'; Cmd = @('Get-HawkCert','Get-HawkDump','Get-HawkBadFile','Get-HawkLink','Get-HawkLock','Get-HawkSparseFile','Get-HawkCompressedDir','Get-HawkPatchHistory','Get-HawkDriverAudit','Get-HawkRecent') }
            @{ Name = 'Redact'; Cmd = @('Protect-HawkSensitiveText') }
        )}
        @{ Name = '🌐 NETWORK'; Color = 'Blue'; Sub = @(
            @{ Name = 'Connectivity'; Cmd = @('Get-HawkNetCheck','Get-HawkWifi','Get-HawkEstablished','Get-HawkDnsBench','Get-HawkDnsCache') }
            @{ Name = 'Services'; Cmd = @('Get-HawkLinkSpeed','Get-HawkShare','Get-HawkHostsCheck','Get-HawkNetworkTriage') }
        )}
        @{ Name = '⚙️ ENV'; Color = 'Yellow'; Sub = @(
            @{ Name = 'Config'; Cmd = @('Get-HawkEnvMap','Get-HawkPathAudit','Get-HawkApp','Get-HawkAppLocation','Get-HawkProject') }
        )}
        @{ Name = '🧠 AI'; Color = 'Magenta'; Sub = @(
            @{ Name = 'Query'; Cmd = @('Invoke-HawkAI','Invoke-HawkSearch','Test-HawkPromptInjection','Get-HawkAIIntent','Get-HawkAIDataProfile','Get-HawkAIStatus','Get-HawkSourceQualityScore') }
            @{ Name = 'Memory'; Cmd = @('Add-HawkMemory','Search-HawkMemory','Get-HawkMemoryMap','Read-HawkMemory','Get-HawkMemoryFile','Build-HawkAIMemoryContext','Build-HawkAIContextPacket') }
        )}
        @{ Name = '📊 REPORTS'; Color = 'DarkYellow'; Sub = @(
            @{ Name = 'Generate'; Cmd = @('New-HawkReport','Get-HawkReportPath') }
        )}
        @{ Name = '🔧 MODULE'; Color = 'Green'; Sub = @(
            @{ Name = 'Shell'; Cmd = @('Show-HawkDashboard','Watch-HawkDashboard','Show-HawkManual','Update-HawkProfile') }
            @{ Name = 'Config'; Cmd = @('Initialize-HawkProfile','Get-HawkProject','Invoke-HawkProject','Invoke-ExplorerHere','Invoke-HawkCachedData') }
        )}
    )

    $sCount = $categories.Count
    for ($sIdx = 0; $sIdx -lt $sCount; $sIdx += $colCount) {
        $lIdx = [Math]::Min($sIdx + $colCount - 1, $sCount - 1); $sGrp = @($categories[$sIdx..$lIdx])

        $subCount = @($sGrp | ForEach-Object { $_.Sub.Count } | Measure-Object -Maximum).Maximum

        Write-Host ("  " + (($sGrp | ForEach-Object { & $fit "$($_.Name) ($($_.Sub.Count))" $colWidth }) -join $gap)) -ForegroundColor Cyan
        Write-Host ("  " + (($sGrp | ForEach-Object { '─' * $colWidth }) -join $gap)) -ForegroundColor DarkGray

        for ($subIdx = 0; $subIdx -lt $subCount; $subIdx++) {
            Write-Host ("  " + (($sGrp | ForEach-Object {
                if ($subIdx -lt $_.Sub.Count) {
                    $sub = $_.Sub[$subIdx]
                    $display = "  $($sub.Name):"
                    & $fit ($display.PadRight(1)) $colWidth
                } else { ' ' * $colWidth }
            }) -join $gap)) -ForegroundColor DarkGray

            $maxCmds = @($sGrp | ForEach-Object {
                if ($subIdx -lt $_.Sub.Count) { $_.Sub[$subIdx].Cmd.Count } else { 0 }
            } | Measure-Object -Maximum).Maximum

            for ($cIdx = 0; $cIdx -lt $maxCmds; $cIdx++) {
                Write-Host ("  " + (($sGrp | ForEach-Object {
                    if ($subIdx -lt $_.Sub.Count -and $cIdx -lt $_.Sub[$subIdx].Cmd.Count) {
                        $fn = $_.Sub[$subIdx].Cmd[$cIdx]; $a = $aliases[$fn]
                        $display = if ($a) { $a.PadRight($colWidth) } else { $fn.PadRight($colWidth) }
                        & $fit $display $colWidth
                    } else { ' ' * $colWidth }
                }) -join $gap)) -ForegroundColor White
            }
        }
        Write-Host ''
    }
}

function Watch-HawkDashboard {
    [CmdletBinding()]
    param([int]$IntervalSeconds = 2)
    if (-not (Test-HawkInteractiveSession)) { Write-Warning "Dashboard requires an interactive terminal session."; return }
    Write-Information "  [Watch] Dashboard live refresh every ${IntervalSeconds}s. Press Ctrl+C to exit." -InformationAction Continue
    while ($true) { Clear-Host; Show-HawkDashboard; Start-Sleep -Seconds $IntervalSeconds }
}
