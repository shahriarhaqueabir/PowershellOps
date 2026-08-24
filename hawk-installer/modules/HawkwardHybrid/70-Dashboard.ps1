# Colorful emoji glyphs for dashboard tiles, keyed by command alias.
# Emoji-first policy: preferred over Nerd Font PUA glyphs and raw symbols so
# every tile renders in color on any terminal without font prerequisites.
$script:HawkEmojiGlyphs = @{
    'ghostaudit'    = '👻'
    'susaudit'      = '🐛'
    'fwaudit'       = '🧱'
    'taskaudit'     = '⏰'
    'secretredact'  = '🙈'
    'defendermap'   = '🛡️'
    'regaudit'      = '📌'
    'ifeoaudit'     = '🚩'
    'regsnap'       = '📸'
    'sysview'       = '🩺'
    'hawkdoctor'    = '💊'
    'hawkcheck'     = '✅'
    'evntmap'       = '🗺️'
    'evntaudit'     = '🌪️'
    'diskaudit'     = '💽'
    'resmap'        = '📊'
    'fwmap'         = '🧾'
    'envmap'        = '🌍'
    'pathaudit'     = '🧭'
    'portmap'       = '🔌'
    'nettriage'     = '🔀'
    'bootmap'       = '⏫'
    'ggl'           = '🔍'
    'ai'            = '🤖'
    'llamastart'    = '▶️'
    'llamastop'     = '⏹️'
    'aidoctor'      = '📡'
    'llamadoctor'   = '🔧'
    'hawkchat'      = '💬'
    'hawkmodel'     = '🦙'
    'hawkdaily'     = '☀️'
    'hawkwatch'     = '👁️'
    'projaudit'     = '🗂️'
    'hawkreport'    = '📄'
    'proj'          = '📂'
    'dash'          = '📟'
    'reload'        = '🔄'
    'hawkman'       = '📖'
    'locate'        = '🎯'
    'open'          = '📁'
    'specs'         = '🧮'
    'uptime'        = '⏱️'
    'raminfo'       = '🧠'
    'battery'       = '🔋'
    'temps'         = '🌡️'
    'fans'          = '🌀'
    'displays'      = '🖥️'
    'hypervisor'    = '♟️'
    'power'         = '🔛'
    'license'       = '🔑'
    'wifi'          = '📶'
    'dnsbench'      = '⏳'
    'linkspeed'     = '🚅'
    'shares'        = '🤝'
    'hostscheck'    = '🏠'
    'dnscache'      = '🧹'
    'shield'        = '🪖'
    'admins'        = '👑'
    'apps'          = '📦'
    'patchhistory'  = '🩹'
    'driveraudit'   = '🔩'
    'certs'         = '🏅'
    'clipcheck'     = '📎'
    'recent'        = '🕘'
    'drivehealth'   = '❤️'
    'dumps'         = '💥'
    'badfiles'      = '⚠️'
    'links'         = '🔗'
    'locked'        = '🔒'
    'sparse'        = '🕳️'
    'compress'      = '🗜️'
    'sysdiag'       = '🧭'
    'auditdiag'     = '🔎'
    'netview'       = '🛰️'
    'envdiag'       = '🧪'
    'sysreview'     = '📋'
    'secaudit'      = '🕵️'
    'netdiag'       = '🌐'
    'threathunt'    = '🎯'
    'hub'           = '🧠'
    'fix'           = '🛠️'
    'stat'          = '📈'
    'ask'           = '❓'
    'mem'           = '🗃️'
    'remember'      = '🔖'
    'recall'        = '🔭'
    'memmap'        = '🕸️'
    'readmem'       = '📜'
    'hawkhelp'      = '💡'
    'onboard'       = '🚀'
}

function Show-HawkDashboard {
    $aiStatus = try {
        $null = Invoke-RestMethod -Uri "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
        'ACTIVE'
    }
    catch {
        'STANDBY'
    }

    $projectRoot = if ($global:HawkProjectRoot) { $global:HawkProjectRoot } else { $script:HawkDefaultProjectRoot }

    $fitText = {
        param(
            [AllowNull()][string]$Text,
            [int]$Width
        )

        if ($Width -le 0) { return '' }
        if ($null -eq $Text) { $Text = '' }
        if ($Text.Length -gt $Width) {
            if ($Width -eq 1) { return $Text.Substring(0, 1) }
            return $Text.Substring(0, $Width - 1) + '…'
        }

        return $Text.PadRight($Width)
    }

    $consoleWidth = try { [Console]::WindowWidth } catch { 120 }
    if ($consoleWidth -lt 1) { $consoleWidth = 120 }

    $dashboardWidth = [Math]::Max(78, [Math]::Min(($consoleWidth - 4), 150))
    $boxTextWidth = $dashboardWidth - 2
    $gap = '  '
    $columnCount = if ($dashboardWidth -ge 116) { 4 } elseif ($dashboardWidth -ge 76) { 2 } else { 1 }
    $columnWidth = [int][Math]::Floor(($dashboardWidth - (($columnCount - 1) * $gap.Length)) / $columnCount)
    $rule = '─' * $dashboardWidth
    $useNf = Test-HawkNerdFont

    Write-Host "`n  ╭$rule╮" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fitText "POWERSHELLOPS $script:HawkVersion · HAWK PROFILE" $boxTextWidth) -ForegroundColor Cyan -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ├$rule┤" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fitText "AI Engine : $aiStatus    Workspace : $projectRoot" $boxTextWidth) -ForegroundColor DarkGray -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ╰$rule╯`n" -ForegroundColor DarkGray

    $suites = @(
        @{
            Title = '🛡️ SENTINEL'
            Desc  = 'Security & Audits'
            Items = @(
                @{ Icon = '◌'; Alias = 'ghostaudit'; Desc = 'Ports' }
                @{ Icon = '▲'; Alias = 'susaudit'; Desc = 'AppData' }
                @{ Icon = '▣'; Alias = 'fwaudit'; Desc = 'Firewall' }
                @{ Icon = '⌁'; Alias = 'taskaudit'; Desc = 'Tasks' }
                @{ Icon = '◆'; Alias = 'secretredact'; Desc = 'Secrets' }
                @{ Icon = '⛨'; Alias = 'defendermap'; Desc = 'Defender' }
                @{ Icon = '⌸'; Alias = 'regaudit'; Desc = 'Reg persist' }
                @{ Icon = '⚑'; Alias = 'ifeoaudit'; Desc = 'IFEO hijack' }
                @{ Icon = '◫'; Alias = 'regsnap';   Desc = 'Reg snapshot' }
            )
        }
        @{
            Title = '🩺 DIAGNOSTICS'
            Desc  = 'System & Health'
            Items = @(
                @{ Icon = '◎'; Alias = 'sysview'; Desc = 'Overview' }
                @{ Icon = '✚'; Alias = 'hawkdoctor'; Desc = 'Health' }
                @{ Icon = '✓'; Alias = 'hawkcheck'; Desc = 'Setup check' }
                @{ Icon = '◷'; Alias = 'evntmap'; Desc = 'Events' }
                @{ Icon = '↯'; Alias = 'evntaudit'; Desc = 'Storms' }
                @{ Icon = '▰'; Alias = 'diskaudit'; Desc = 'Disk' }
                @{ Icon = '▤'; Alias = 'resmap'; Desc = 'CPU/RAM' }
            )
        }
        @{
            Title = '⚙️ ENVIRONMENT'
            Desc  = 'State & Config'
            Items = @(
                @{ Icon = '□'; Alias = 'fwmap'; Desc = 'Rules' }
                @{ Icon = '≡'; Alias = 'envmap'; Desc = 'Env vars' }
                @{ Icon = '⌘'; Alias = 'pathaudit'; Desc = 'PATH audit' }
                @{ Icon = '◦'; Alias = 'portmap'; Desc = 'Listeners' }
                @{ Icon = '⇄'; Alias = 'nettriage'; Desc = 'Network' }
                @{ Icon = '⌂'; Alias = 'bootmap'; Desc = 'Startup' }
            )
        }
        @{
            Title = '🤖 AI ENGINE'
            Desc  = 'Local LLM Stack'
            Items = @(
                @{ Icon = '⌕'; Alias = 'ggl'; Desc = 'Search + AI' }
                @{ Icon = 'λ'; Alias = 'ai'; Desc = 'Analyze' }
                @{ Icon = '❯'; Alias = 'hawkchat'; Desc = 'AI chat' }
                @{ Icon = '⌥'; Alias = 'hawkmodel'; Desc = 'Models' }
                @{ Icon = '?'; Alias = 'hawkhelp'; Desc = 'AI cmd help' }
                @{ Icon = '▶'; Alias = 'llamastart'; Desc = 'Start server' }
                @{ Icon = '■'; Alias = 'llamastop'; Desc = 'Stop server' }
                @{ Icon = '◉'; Alias = 'aidoctor'; Desc = 'Server status' }
                @{ Icon = '⏭'; Alias = 'llamadoctor'; Desc = 'Server doctor' }
            )
        }
        @{
            Title = '🔁 WORKFLOWS'
            Desc  = 'Deep Scans & Dispatch'
            Items = @(
                @{ Icon = '◈'; Alias = 'sysdiag'; Desc = 'Dispatch system' }
                @{ Icon = '◆'; Alias = 'auditdiag'; Desc = 'Dispatch audits' }
                @{ Icon = '◇'; Alias = 'netview'; Desc = 'Dispatch network' }
                @{ Icon = '⬡'; Alias = 'envdiag'; Desc = 'Dispatch environ' }
                @{ Icon = '☰'; Alias = 'sysreview'; Desc = 'System review' }
                @{ Icon = '⛨'; Alias = 'secaudit'; Desc = 'Security review' }
                @{ Icon = '≋'; Alias = 'netdiag'; Desc = 'Network sweep' }
                @{ Icon = '⚑'; Alias = 'threathunt'; Desc = 'Threat hunt' }
            )
        }
        @{
            Title = '💬 HUB & MEMORY'
            Desc  = 'Conversational Pipeline'
            Items = @(
                @{ Icon = '◎'; Alias = 'hub'; Desc = 'AI companion' }
                @{ Icon = '✚'; Alias = 'fix'; Desc = 'Auto-fix issue' }
                @{ Icon = '▤'; Alias = 'stat'; Desc = 'Session stats' }
                @{ Icon = '⌁'; Alias = 'ask'; Desc = 'Quick ask AI' }
                @{ Icon = '▣'; Alias = 'mem'; Desc = 'Memory shell' }
                @{ Icon = '＋'; Alias = 'remember'; Desc = 'Save memory' }
                @{ Icon = '⌕'; Alias = 'recall'; Desc = 'Search memory' }
                @{ Icon = '⊞'; Alias = 'memmap'; Desc = 'Memory map' }
                @{ Icon = '≡'; Alias = 'readmem'; Desc = 'Read memories' }
            )
        }
        @{
            Title = '📁 WORKSPACE'
            Desc  = 'Projects & Console'
            Items = @(
                @{ Icon = '↗'; Alias = 'proj'; Desc = 'Root' }
                @{ Icon = '⑂'; Alias = 'projaudit'; Desc = 'Repos' }
                @{ Icon = '▧'; Alias = 'hawkreport'; Desc = 'Report + MD' }
                @{ Icon = '☀'; Alias = 'hawkdaily'; Desc = 'Daily sweep' }
                @{ Icon = '⟳'; Alias = 'hawkwatch'; Desc = 'Live dash' }
                @{ Icon = '▦'; Alias = 'dash'; Desc = 'Dashboard' }
                @{ Icon = '↻'; Alias = 'reload'; Desc = 'Profile' }
                @{ Icon = '?'; Alias = 'hawkman'; Desc = 'Guide' }
                @{ Icon = '⇧'; Alias = 'onboard'; Desc = 'Setup wizard' }
                @{ Icon = '⌖'; Alias = 'locate'; Desc = 'Find app' }
                @{ Icon = '⇲'; Alias = 'open'; Desc = 'Explorer here' }
            )
        }
        @{
            Title = '⛁ SYSTEM MATRIX'
            Desc  = 'Hardware Snapshot'
            Items = @(
                @{ Icon = '⛁'; Alias = 'specs'; Desc = 'Specs' }
                @{ Icon = '⏱'; Alias = 'uptime'; Desc = 'Uptime' }
                @{ Icon = '▥'; Alias = 'raminfo'; Desc = 'RAM sticks' }
                @{ Icon = '⚡'; Alias = 'battery'; Desc = 'Battery' }
                @{ Icon = '🌡'; Alias = 'temps'; Desc = 'Thermals' }
                @{ Icon = '🌀'; Alias = 'fans'; Desc = 'Fans' }
                @{ Icon = '⛶'; Alias = 'displays'; Desc = 'Displays' }
                @{ Icon = '⧉'; Alias = 'hypervisor'; Desc = 'Hypervisor' }
                @{ Icon = '⏻'; Alias = 'power'; Desc = 'Power plan' }
                @{ Icon = '⚿'; Alias = 'license'; Desc = 'License' }
            )
        }
        @{
            Title = '≋ NET INTEL'
            Desc  = 'Network Deep Dive'
            Items = @(
                @{ Icon = 'ᯤ'; Alias = 'wifi'; Desc = 'Wi-Fi' }
                @{ Icon = '⏳'; Alias = 'dnsbench'; Desc = 'DNS bench' }
                @{ Icon = '⇅'; Alias = 'linkspeed'; Desc = 'Link speed' }
                @{ Icon = '⊞'; Alias = 'shares'; Desc = 'SMB shares' }
                @{ Icon = '⌗'; Alias = 'hostscheck'; Desc = 'Hosts file' }
                @{ Icon = '↺'; Alias = 'dnscache'; Desc = 'DNS cache' }
            )
        }
        @{
            Title = '⛨ SEC SCAN'
            Desc  = 'Defense Inventory'
            Items = @(
                @{ Icon = '⛨'; Alias = 'shield'; Desc = 'Defender' }
                @{ Icon = '☗'; Alias = 'admins'; Desc = 'Admins' }
                @{ Icon = '◫'; Alias = 'apps'; Desc = 'Apps' }
                @{ Icon = '⎇'; Alias = 'patchhistory'; Desc = 'Patches' }
                @{ Icon = '⛭'; Alias = 'driveraudit'; Desc = 'Drivers' }
                @{ Icon = '✪'; Alias = 'certs'; Desc = 'Certs' }
            )
        }
        @{
            Title = '▤ STORAGE'
            Desc  = 'Files & Volumes'
            Items = @(
                @{ Icon = '⎘'; Alias = 'clipcheck'; Desc = 'Clipboard' }
                @{ Icon = '◔'; Alias = 'recent'; Desc = 'Recent files' }
                @{ Icon = '♥'; Alias = 'drivehealth'; Desc = 'SMART' }
                @{ Icon = '⌦'; Alias = 'dumps'; Desc = 'Crash dumps' }
                @{ Icon = '⚠'; Alias = 'badfiles'; Desc = 'Zero-byte' }
                @{ Icon = '⛓'; Alias = 'links'; Desc = 'Symlinks' }
                @{ Icon = '⊘'; Alias = 'locked'; Desc = 'Locked files' }
                @{ Icon = '░'; Alias = 'sparse'; Desc = 'Sparse files' }
                @{ Icon = '⊟'; Alias = 'compress'; Desc = 'Compressed' }
            )
        }
    )

    for ($suiteIndex = 0; $suiteIndex -lt $suites.Count; $suiteIndex += $columnCount) {
        $lastSuiteIndex = [Math]::Min($suiteIndex + $columnCount - 1, $suites.Count - 1)
        $suiteGroup = @($suites[$suiteIndex..$lastSuiteIndex])
        $maxItems = @($suiteGroup | ForEach-Object { $_.Items.Count } | Measure-Object -Maximum).Maximum

        $titleLine = @(
            foreach ($suite in $suiteGroup) {
                # Emoji titles always — colorful-by-default rendering.
                & $fitText $suite.Title $columnWidth
            }
        )
        Write-Host ("  " + ($titleLine -join $gap)) -ForegroundColor Cyan

        $descLine = @(
            foreach ($suite in $suiteGroup) {
                & $fitText $suite.Desc $columnWidth
            }
        )
        Write-Host ("  " + ($descLine -join $gap)) -ForegroundColor DarkGray

        $sectionRule = @(
            foreach ($suite in $suiteGroup) {
                '─' * $columnWidth
            }
        )
        Write-Host ("  " + ($sectionRule -join $gap)) -ForegroundColor DarkGray

        for ($itemIndex = 0; $itemIndex -lt $maxItems; $itemIndex++) {
            $itemLine = @(
                foreach ($suite in $suiteGroup) {
                    if ($itemIndex -lt $suite.Items.Count) {
                        $item = $suite.Items[$itemIndex]
                        $icon = if ($script:HawkEmojiGlyphs.ContainsKey($item.Alias)) {
                            $script:HawkEmojiGlyphs[$item.Alias]
                        }
                        elseif ($useNf -and $script:HawkNerdGlyphs.ContainsKey($item.Alias)) {
                            $script:HawkNerdGlyphs[$item.Alias]
                        }
                        else { $item.Icon }
                        $command = "$icon $($item.Alias.PadRight(12)) $($item.Desc)"
                        & $fitText $command $columnWidth
                    }
                    else {
                        ' ' * $columnWidth
                    }
                }
            )
            Write-Host ("  " + ($itemLine -join $gap)) -ForegroundColor White
        }

        Write-Host ''
    }
}

<#
.SYNOPSIS
Re-renders the Hawkward dashboard on an interval until you quit.
.DESCRIPTION
Clears the screen and draws the dashboard every -IntervalSec seconds so
system counters, AI status, and port data stay live. Press q or Escape to
exit (Ctrl+C also works). Alias: hawkwatch.
.PARAMETER IntervalSec
Seconds between refreshes. Default: 10. Minimum 3.
#>
function Watch-HawkDashboard {
    [CmdletBinding()]
    param(
        [ValidateRange(3, 3600)]
        [int]$IntervalSec = 10
    )

    if (-not (Test-HawkInteractiveSession)) {
        Write-Host '  [watch] requires an interactive console' -ForegroundColor Yellow
        return
    }

    Write-Host "  [watch] refreshing every ${IntervalSec}s — press q to stop" -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 800

    while ($true) {
        Clear-Host
        Show-HawkDashboard

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $IntervalSec) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -in 'Q', 'Escape') {
                    Clear-Host
                    Write-Host '  [watch] stopped' -ForegroundColor DarkGray
                    return
                }
            }
            Start-Sleep -Milliseconds 200
        }
    }
}

function Update-HawkProfile {
    <#
    .SYNOPSIS
    Reloads the current PowerShell profile from disk.
    .DESCRIPTION
    Dot-sources the current user's $PROFILE to pick up any changes without
    restarting the shell. Alias: reload.
    #>
    $sw = [Diagnostics.Stopwatch]::StartNew()
    . $PROFILE
    Write-Host "  [OK] Profile reloaded in $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
}

# ════════════════════════════════════════════════════════════
# LEGACY MATRIX MIGRATION (v11.2) — 40-core scans absorbed from
# the retired HawkModules satellite module (removed in v12.0).
# Unique tools brought forward with proper comment-based help;
# duplicates retired in favor of the audit/map suites above.
# ════════════════════════════════════════════════════════════

