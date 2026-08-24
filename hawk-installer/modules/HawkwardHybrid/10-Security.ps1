function Get-HawkBootMap {
    [CmdletBinding()]
    param()

    if (-not $script:HawkSuppressHeaders -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning 'Non-admin session: registry access may be limited.'
    }

    Write-HawkHeader '  [Startup] Registry startup scraper' Yellow
    $regPaths = @(
        @{ Hive = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' }
    )

    foreach ($entry in $regPaths) {
        if (-not (Test-Path $entry.Path)) { continue }

        $key = Get-ItemProperty -Path $entry.Path -ErrorAction SilentlyContinue
        $key.PSObject.Properties |
        Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*' } |
        ForEach-Object {
            [PSCustomObject]@{
                Hive   = $entry.Hive
                Name   = $_.Name
                Target = $_.Value
                Source = $entry.Path
            }
        }
    }
}

# --- Registry security audit helpers (private) ---

function Resolve-HawkAutostartExe {
    # Extracts the executable target from an autostart command string.
    param([string]$Command)

    $expanded = [Environment]::ExpandEnvironmentVariables($Command.Trim())
    $exe = $null
    $rest = ''

    if ($expanded.StartsWith('"')) {
        $closeIdx = $expanded.IndexOf('"', 1)
        if ($closeIdx -gt 0) {
            $exe = $expanded.Substring(1, $closeIdx - 1)
            $rest = $expanded.Substring($closeIdx + 1).Trim()
        }
    }

    if (-not $exe) {
        $tokens = $expanded -split '\s+'
        for ($t = [Math]::Min($tokens.Count, 6); $t -ge 1; $t--) {
            $candidate = ($tokens[0..($t - 1)] -join ' ')
            if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $exe = $candidate
                $rest = if ($t -lt $tokens.Count) { ($tokens[$t..($tokens.Count - 1)] -join ' ') } else { '' }
                break
            }
        }
        if (-not $exe -and $tokens.Count -gt 0) {
            $exe = $tokens[0]
            $rest = if ($tokens.Count -gt 1) { ($tokens[1..($tokens.Count - 1)] -join ' ') } else { '' }
        }
    }

    if ($exe -and -not (Test-Path -LiteralPath $exe)) {
        $cmd = Get-Command -Name $exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $exe = $cmd.Source }
    }

    $chain = ''
    $baseName = ''
    if ($exe) { $baseName = (Split-Path $exe -Leaf).ToLowerInvariant() }
    if ($expanded -match '(?i)(^|[\\"])(cmd|powershell|pwsh)\.exe(\.exe)?\s') { $chain = 'shell-chain' }

    [PSCustomObject]@{
        Exe   = $exe
        Rest  = $rest
        Chain = $chain
        Base  = $baseName
    }
}

<#
.SYNOPSIS
Audits registry autostart persistence entries for suspicious executables.
.DESCRIPTION
Sweeps all six autostart locations: Run and RunOnce under HKLM, HKCU,
and the WOW64 (32-bit) view of HKLM. Each entry's command is parsed to its
executable target, checked for existence, Authenticode signature validity,
and uncommon location. Flags dangling entries (deleted binaries) and
shell-chain commands. RunOnce semantics follow KB docs: values are deleted
before execution unless prefixed with '!'; '*' prefix runs even in Safe Mode.
.PARAMETER SkipWow64
Skip the WOW64 HKLM Run/RunOnce sweep.
#>
function Get-HawkRegAudit {
    [CmdletBinding()]
    param([switch]$SkipWow64)

    Write-HawkHeader '  [Registry] Autostart persistence sweep' Red

    $targets = @(
        @{ Scope = 'HKLM';   Key = 'Run';     Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Scope = 'HKLM';   Key = 'RunOnce'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' },
        @{ Scope = 'HKCU';   Key = 'Run';     Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Scope = 'HKCU';   Key = 'RunOnce'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' }
    )
    if (-not $SkipWow64) {
        $targets += @(
            @{ Scope = 'WOW64';  Key = 'Run';     Path = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run' },
            @{ Scope = 'WOW64';  Key = 'RunOnce'; Path = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce' }
        )
    }

    $results = foreach ($target in $targets) {
        $key = Get-Item -LiteralPath $target.Path -ErrorAction SilentlyContinue
        if (-not $key) { continue }

        foreach ($name in $key.GetValueNames()) {
            $raw = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $resolved = Resolve-HawkAutostartExe -Command $raw

            $exists = $false
            $sigStatus = '<none>'
            $uncommon = $false
            if ($resolved.Exe) {
                $exists = Test-Path -LiteralPath $resolved.Exe -PathType Leaf
                if ($exists) {
                    $sig = Get-AuthenticodeSignature -FilePath $resolved.Exe -ErrorAction SilentlyContinue
                    if ($sig) { $sigStatus = [string]$sig.Status }
                    $full = ((Split-Path $resolved.Exe -Parent) + '\').ToLowerInvariant()
                    $uncommon = ($full -match '\\temp\\|\\downloads\\|\\users\\public\\|\\appdata\\local\\temp\\')
                }
            }

            $notes = @()
            if ($name.StartsWith('*')) { $notes += 'safe-mode' }
            if ($name.StartsWith('!')) { $notes += 'deferred-delete' }
            if ($target.Key -eq 'RunOnce') { $notes += 'one-shot' }
            if ($resolved.Chain) { $notes += $resolved.Chain }
            if ($resolved.Exe -and -not $exists) { $notes += 'missing-binary' }
            if ($uncommon) { $notes += 'uncommon-location' }

            $risk = 'Medium'
            if (-not $exists) { $risk = 'High' }
            elseif ($sigStatus -eq 'Valid' -and -not $uncommon) { $risk = 'Low' }
            elseif ($sigStatus -notin @('Valid', 'NotSigned')) { $risk = 'High' }
            elseif ($sigStatus -eq 'NotSigned' -and $uncommon) { $risk = 'High' }
            elseif ($sigStatus -eq 'NotSigned') { $risk = 'Medium' }

            [PSCustomObject]@{
                Scope   = $target.Scope
                Key     = $target.Key
                Name    = $name
                Exe     = $resolved.Exe
                Sig     = $sigStatus
                Risk    = $risk
                Notes   = ($notes -join ',')
                Target  = $raw
            }
        }
    }

    $results = @($results)
    if ($results.Count -gt 0) { $results }

    $high = @($results | Where-Object Risk -eq 'High').Count
    $medium = @($results | Where-Object Risk -eq 'Medium').Count
    $summary = "entries: $($results.Count) | high-risk: $high | medium: $medium"
    Write-HawkHeader ('  [' + $(if ($high -gt 0) { '!!' } else { 'OK' }) + "] $summary") $(if ($high -gt 0) { 'Red' } else { 'Green' })
}

<#
.SYNOPSIS
Scans Image File Execution Options (IFEO) keys for debugger hijacking.
.DESCRIPTION
Enumerates every subkey under the machine-wide IFEO key plus the per-user
(HKCU) IFEO key and flags any 'Debugger' value - the classic persistence/
execution-hijack technique. Legitimate software rarely sets Debugger values.
Read-only scan.
#>
function Get-HawkIfeoAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Registry] IFEO debugger hijack scan' Red

    $roots = @(
        @{ Scope = 'HKLM'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' },
        @{ Scope = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' }
    )

    $scanned = 0
    $results = foreach ($root in $roots) {
        $parent = Get-Item -LiteralPath $root.Path -ErrorAction SilentlyContinue
        if (-not $parent) { continue }

        foreach ($sub in $parent.GetSubKeyNames()) {
            $scanned++
            $subKey = Get-Item -LiteralPath (Join-Path $root.Path $sub) -ErrorAction SilentlyContinue
            if (-not $subKey) { continue }
            $debugger = $subKey.GetValue('Debugger', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($debugger) {
                [PSCustomObject]@{
                    Scope    = $root.Scope
                    Image    = $sub
                    Debugger = $debugger
                }
            }
        }
    }

    $results = @($results)
    if ($results.Count -gt 0) { $results }
    Write-HawkHeader ("  [" + $(if ($results.Count -gt 0) { '!!' } else { 'OK' }) + "] images inspected: $scanned | debugger hijacks: $($results.Count)") $(if ($results.Count -gt 0) { 'Red' } else { 'Green' })
}

function Save-HawkRegistrySnapshot {
    <#
    .SYNOPSIS
    Exports a registry key to a versioned .reg snapshot before edits.
    .DESCRIPTION
    Uses reg.exe export to save a regedit-compatible snapshot of the given key
    into the Hawkward Reports directory. Run this before any registry-modifying
    workflow so changes can be reviewed or re-imported. Alias: regsnap.
    .PARAMETER KeyPath
    Registry key to export. Accepts PowerShell forms (HKLM:\..., HKCU:\...)
    or bare forms (HKLM\..., HKCU\...).
    .PARAMETER Name
    Optional label inserted into the file name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$KeyPath,
        [Parameter(Position = 1)]
        [string]$Name
    )

    $normalized = $KeyPath.Trim() -replace '^HKLM:\\', 'HKLM\' -replace '^HKCU:\\', 'HKCU\'
    $providerForm = $normalized -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'

    if (-not (Test-Path -LiteralPath $providerForm)) {
        Write-Host "  [snap] registry key not found: $KeyPath" -ForegroundColor Yellow
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $fileName = if ($Name) { "regsnap-$stamp-$Name.reg" } else { "regsnap-$stamp.reg" }
    $outFile = Join-Path $script:HawkReportRoot $fileName

    Write-Host "`n  ◫ REGISTRY SNAPSHOT" -ForegroundColor Cyan
    Write-Host '  Key  : ' -NoNewline; Write-Host $providerForm -ForegroundColor White

    $output = & reg.exe export $normalized $outFile /y 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outFile)) {
        Write-Host "  [!!] reg.exe export failed (exit $LASTEXITCODE) $output" -ForegroundColor Red
        return
    }

    Write-Host '  File : ' -NoNewline; Write-Host $outFile -ForegroundColor White
    Write-Host '  Size : ' -NoNewline; Write-Host ("{0:N1} KB" -f ((Get-Item -LiteralPath $outFile).Length / 1KB)) -ForegroundColor DarkGray
    Write-Host '  [OK] snapshot saved — restore with: reg import "<file>"' -ForegroundColor Green
}

<#
.SYNOPSIS
Shows recent System/Application warnings and errors.
.DESCRIPTION
Lists the last N warning/error events from the requested logs. Use
-RegistryHealth to also scan the System log for hive-corruption indicators
(unexpected shutdowns and disk I/O errors) per Microsoft KB822705.
.PARAMETER MaxEvents
Maximum events to list. Default: 20.
.PARAMETER LogName
Event logs to query. Default: System and Application.
.PARAMETER RegistryHealth
Append a hive-corruption indicator scan (event IDs 6008, 9, 11, 15).
#>
function Get-HawkEventMap {
    [CmdletBinding()]
    param(
        [int]$MaxEvents = 20,
        [string[]]$LogName = @('System', 'Application'),
        [switch]$RegistryHealth
    )

    Write-HawkHeader "  [Events] System/Application warnings and errors (last $MaxEvents)" Cyan
    Get-WinEvent -FilterHashtable @{ LogName = $LogName; Level = 2, 3 } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message

    if ($RegistryHealth) {
        Write-HawkHeader "`n  [Events] Hive-corruption indicators (System log)" Yellow
        $corruptionIds = @(6008, 9, 11, 15)
        $hits = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = $corruptionIds } -MaxEvents 50 -ErrorAction SilentlyContinue)
        if (-not $hits.Count) {
            Write-Host '  [OK] no unexpected-shutdown or disk-error events' -ForegroundColor Green
            return
        }
        foreach ($e in $hits) {
            $meaning = switch ($e.ProviderName) {
                'disk' { 'disk I/O error' }
                'EventLog' { 'unexpected shutdown' }
                default { 'storage/hive maintenance' }
            }
            Write-Host ('  {0}  #{1,-5} {2,-24} {3}' -f $e.TimeCreated.ToString('yyyy-MM-dd HH:mm'), $e.Id, $meaning, $e.ProviderName) -ForegroundColor Yellow
        }
        Write-Host ("  [!!] $($hits.Count) corruption indicator(s) - if hives misbehave see KB822705 (chkdsk /r, restore from backup)") -ForegroundColor Red
        $hits | Select-Object TimeCreated, Id, ProviderName, Message
    }
}

<#
.SYNOPSIS
Maps active Windows Firewall rules.
.DESCRIPTION
Lists the first N enabled inbound allow firewall rules with name and profile.
.PARAMETER First
Number of rules to display. Default: 15.
#>
function Get-HawkFirewallMap {
    [CmdletBinding()]
    param([int]$First = 15)

    Write-HawkHeader '  [Firewall] Enabled inbound allow rules' Yellow
    Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, Profile |
    Select-Object -First $First
}

<#
.SYNOPSIS
Maps environment variables and system paths.
.DESCRIPTION
Displays PATH entries, user vs system variables, and highlights unusual or sensitive values.
Use -IncludeSensitive to show values that might contain tokens or secrets.
.PARAMETER IncludeSensitive
Include potentially sensitive variables (API keys, tokens). Default: hidden.
#>
function Get-HawkEnvMap {
    <#
    .SYNOPSIS
    Audits environment variables across process, machine, and user scopes.
    .DESCRIPTION
    Lists variables from the live process scope plus the persisted registry
    scopes (HKLM Session Manager Environment and HKCU Environment). Persisted
    REG_EXPAND_SZ values are shown expanded with an Expandable marker so
    unexpanded templates stay visible. Sensitive names are redacted unless
    -IncludeSensitive. Alias: envmap.
    .PARAMETER Scope
    Which scopes to audit: All (default), Process, Machine, or User.
    .PARAMETER IncludeSensitive
    Show values of sensitive-named variables instead of <REDACTED>.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Process', 'Machine', 'User')]
        [string]$Scope = 'All',
        [switch]$IncludeSensitive
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $redact = { param($name) ($name -match $script:HawkSensitiveNamePattern) }

    if ($Scope -in 'All', 'Process') {
        Write-HawkHeader '  [Environment] Process scope' Blue
        Get-ChildItem Env: |
        Sort-Object Name |
        ForEach-Object {
            $sensitive = & $redact $_.Name
            $rows.Add([PSCustomObject]@{
                Scope      = 'Process'
                Name       = $_.Name
                Type       = 'String'
                Expandable = $false
                Value      = if ($sensitive -and -not $IncludeSensitive) { '<REDACTED>' } else { $_.Value }
                Sensitive  = $sensitive
            })
        }
    }

    if ($Scope -in 'All', 'Machine', 'User') {
        $targets = @()
        if ($Scope -in 'All', 'Machine') { $targets += @{ Label = 'Machine'; Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' } }
        if ($Scope -in 'All', 'User') { $targets += @{ Label = 'User'; Key = 'HKCU:\Environment' } }

        foreach ($t in $targets) {
            Write-HawkHeader "  [Environment] $($t.Label) scope (persisted)" Blue
            try {
                $key = Get-Item -LiteralPath $t.Key -ErrorAction Stop
            }
            catch {
                Write-Host "  [!!] cannot read $($t.Key): $($_.Exception.Message)" -ForegroundColor Yellow
                continue
            }
            foreach ($name in ($key.GetValueNames() | Sort-Object)) {
                if (-not $name) { continue }
                $raw = $key.GetValue($name, '', 'DoNotExpandEnvironmentNames')
                $kind = try { $key.GetValueKind($name).ToString() } catch { 'Unknown' }
                $expandable = ($raw -is [string] -and $raw -match '%[^%]+%')
                $shown = if ($expandable) { [Environment]::ExpandEnvironmentVariables($raw) } else { $raw }
                $sensitive = & $redact $name
                $rows.Add([PSCustomObject]@{
                    Scope      = $t.Label
                    Name       = $name
                    Type       = $kind
                    Expandable = $expandable
                    Value      = if ($sensitive -and -not $IncludeSensitive) { '<REDACTED>' } else { "$shown" }
                    Sensitive  = $sensitive
                })
            }
        }
    }

    $rows | Format-Table Scope, Name, Type, Expandable, Value -AutoSize | Out-Host
    Write-Host ("  [OK] variables: {0} (process/machine/user)" -f $rows.Count) -ForegroundColor Green
    return $rows
}

<#
.SYNOPSIS
Lists active TCP listeners and their associated processes.
.DESCRIPTION
Shows all TCP ports currently listening, the process owning each, and the
owning user. Useful for identifying services, ghost ports, or unexpected
listeners. For risk-rated ghost port analysis, use Get-HawkGhostPortAudit.
#>
function Get-HawkTcpListeners {
    [CmdletBinding()]
    param()

    try {
        Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Select-Object LocalAddress, LocalPort, OwningProcess, @{ Name = 'Source'; Expression = { 'Get-NetTCPConnection' } }
        return
    }
    catch {
        Write-Verbose "Get-NetTCPConnection unavailable, falling back to netstat: $($_.Exception.Message)"
    }

    $lines = & netstat -ano -p tcp 2>$null
    foreach ($line in $lines) {
        if ($line -match '^\s*TCP\s+(.+):(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$') {
            [PSCustomObject]@{
                LocalAddress  = $matches[1]
                LocalPort     = [int]$matches[2]
                OwningProcess = [int]$matches[3]
                Source        = 'netstat'
            }
        }
    }
}

<#
.SYNOPSIS
Scans for open ports and compares them to expected/known services.
.DESCRIPTION
Finds orphaned TCP listeners whose owning process is no longer running.
These ghost ports indicate resources that weren't cleaned up properly.
#>
function Get-HawkGhostPortAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Ports] Ghost listener audit' Red
    $net = Get-HawkTcpListeners
    $ghosts = foreach ($conn in $net) {
        if ($conn.OwningProcess -ne 0 -and -not (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue)) {
            [PSCustomObject]@{
                Port   = $conn.LocalPort
                PID    = $conn.OwningProcess
                Status = 'Ghost/Orphaned'
            }
        }
    }

    if ($ghosts) { $ghosts }
    else { Write-HawkHeader '  [OK] No ghost listeners detected.' Green }
}

function Get-HawkEnabledInboundTcpPortFilters {
    [CmdletBinding()]
    param()

    $script:HawkLastFirewallFilterError = $null
    try {
        $rules = Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction Stop
        foreach ($rule in $rules) {
            $filters = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
            foreach ($filter in $filters) {
                if ($filter.Protocol -in @('TCP', 'Any')) {
                    [PSCustomObject]@{
                        RuleName    = $rule.Name
                        DisplayName = $rule.DisplayName
                        Profile     = [string]$rule.Profile
                        Protocol    = [string]$filter.Protocol
                        LocalPort   = [string]$filter.LocalPort
                    }
                }
            }
        }
    }
    catch {
        $script:HawkLastFirewallFilterError = $_.Exception.Message
        @()
    }
}

function Test-HawkPortSpecMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$PortSpec,
        [Parameter(Mandatory = $true)][int]$Port
    )

    foreach ($token in ($PortSpec -split ',')) {
        $value = $token.Trim()
        if (-not $value) { continue }
        if ($value -eq 'Any') { return $true }
        if ($value -match '^\d+$' -and [int]$value -eq $Port) { return $true }
        if ($value -match '^(\d+)-(\d+)$') {
            $start = [int]$matches[1]
            $end = [int]$matches[2]
            if ($Port -ge $start -and $Port -le $end) { return $true }
        }
    }

    return $false
}

<#
.SYNOPSIS
Audits Windows Firewall status and active rules.
.DESCRIPTION
Reviews firewall profiles (Domain, Private, Public), counts rules by direction, and flags insecure inbound allow rules.
#>
function Get-HawkFirewallAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Firewall] Open ports vs enabled inbound allow rules' Magenta
    $connections = Get-HawkTcpListeners
    $filters = @(Get-HawkEnabledInboundTcpPortFilters)

    if ($script:HawkLastFirewallFilterError) {
        [PSCustomObject]@{
            Port        = ''
            PID         = ''
            Process     = ''
            Status      = "Firewall rules unavailable: $script:HawkLastFirewallFilterError"
            MatchedRule = ''
        }
        return
    }

    foreach ($group in ($connections | Group-Object LocalPort | Sort-Object { [int]$_.Name })) {
        $port = [int]$group.Name
        $pids = @($group.Group.OwningProcess | Sort-Object -Unique)
        $processNames = foreach ($procId in $pids) {
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc) { $proc.ProcessName }
        }

        $matched = $filters | Where-Object { Test-HawkPortSpecMatch -PortSpec $_.LocalPort -Port $port } | Select-Object -First 1
        if (-not $matched) {
            [PSCustomObject]@{
                Port        = $port
                PID         = ($pids -join ',')
                Process     = (($processNames | Sort-Object -Unique) -join ',')
                Status      = 'No enabled inbound allow port filter'
                MatchedRule = ''
            }
        }
    }
}

<#
.SYNOPSIS
Audits Microsoft Defender engine health and configuration.
.DESCRIPTION
Checks Defender running mode, real-time protection layers, signature age,
tamper protection, exclusions, and recent threat detections. Renders a
color-coded summary; use -PassThru to receive the raw result object.
Alias: defendermap.
.PARAMETER PassThru
Emit the raw audit object in addition to rendering.
#>
function Get-HawkDefenderAudit {
    [CmdletBinding()]
    param([switch]$PassThru)

    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        Write-Host '  [defender] Microsoft Defender is not available on this system' -ForegroundColor Yellow
        return
    }

    $status = $null
    try { $status = Get-MpComputerStatus -ErrorAction Stop } catch { }
    if (-not $status) {
        Write-Host '  [defender] unable to query Defender status (service unavailable?)' -ForegroundColor Yellow
        return
    }

    $prop = { param($n) if ($status.PSObject.Properties[$n]) { $status.$n } else { $null } }

    $pref = $null
    try { $pref = Get-MpPreference -ErrorAction Stop } catch { }

    $threats = @()
    try { $threats = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Sort-Object InitialDetectionTime -Descending) } catch { }

    $warnings = 0

    Write-Host "`n  ⛨ DEFENDER AUDIT" -ForegroundColor Yellow

    # Engine / running mode
    $runMode = & $prop 'AMRunningMode'
    $amService = & $prop 'AMServiceEnabled'
    $engineOk = ($amService -eq $true) -and (-not $runMode -or $runMode -match '^Normal')
    if ($engineOk) {
        Write-Host '  Engine       : ' -NoNewline
        Write-Host "[OK] $($runMode ?? 'service running')" -ForegroundColor Green
    }
    else {
        Write-Host '  Engine       : ' -NoNewline
        Write-Host "[!!] $(if ($runMode) { $runMode } elseif ($amService -eq $false) { 'AM service disabled' } else { 'unknown state' })" -ForegroundColor Red
        $warnings++
    }

    # Real-time protection
    $rtp = & $prop 'RealTimeProtectionEnabled'
    Write-Host '  Real-time    : ' -NoNewline
    if ($rtp) { Write-Host '[OK] enabled' -ForegroundColor Green }
    else { Write-Host '[!!] DISABLED' -ForegroundColor Red; $warnings++ }

    # Behavior monitoring
    $behavior = & $prop 'BehaviorMonitorEnabled'
    Write-Host '  Behavior     : ' -NoNewline
    if ($behavior) { Write-Host '[OK] enabled' -ForegroundColor Green }
    else { Write-Host '[!!] off' -ForegroundColor Red; $warnings++ }

    # Network inspection
    $nis = & $prop 'NISEnabled'
    Write-Host '  NetInspect   : ' -NoNewline
    if ($nis) { Write-Host '[OK] enabled' -ForegroundColor Green }
    else { Write-Host '[!!] off' -ForegroundColor Red; $warnings++ }

    # Signature freshness
    $sigTime = & $prop 'AntivirusSignatureLastUpdated'
    if ($sigTime) {
        $ageDays = [int]((Get-Date) - $sigTime).TotalDays
        Write-Host '  Signatures   : ' -NoNewline
        $ageText = "$ageDays day(s) old · $($sigTime.ToString('yyyy-MM-dd HH:mm'))"
        if ($ageDays -le 2) { Write-Host "[OK] $ageText" -ForegroundColor Green }
        elseif ($ageDays -le 7) { Write-Host "[!!] $ageText" -ForegroundColor Yellow; $warnings++ }
        else { Write-Host "[!!] $ageText" -ForegroundColor Red; $warnings++ }
    }

    # Tamper protection
    $tamper = if ($status.PSObject.Properties['IsTamperProtected']) { $status.IsTamperProtected } else { $null }
    Write-Host '  Tamper       : ' -NoNewline
    if ($null -eq $tamper) { Write-Host 'n/a' -ForegroundColor DarkGray }
    elseif ($tamper) { Write-Host '[OK] protected' -ForegroundColor Green }
    else { Write-Host '[!!] unprotected' -ForegroundColor Red; $warnings++ }

    # Exclusions
    $exPaths = @($pref.ExclusionPath | Where-Object { $_ })
    $exProcs = @($pref.ExclusionProcess | Where-Object { $_ })
    $exExts = @($pref.ExclusionExtension | Where-Object { $_ })
    $exColor = if ($exPaths.Count -gt 8) { 'Yellow' } else { 'White' }
    if ($exPaths.Count -gt 8) { $warnings++ }
    Write-Host '  Exclusions   : ' -NoNewline
    Write-Host "$($exPaths.Count) path(s) · $($exProcs.Count) process(es) · $($exExts.Count) ext(s)" -ForegroundColor $exColor
    foreach ($p in ($exPaths | Select-Object -First 3)) {
        $short = if ("$p".Length -gt 58) { "$p".Substring(0, 55) + '...' } else { "$p" }
        Write-Host "                 - $short" -ForegroundColor DarkGray
    }
    if ($exPaths.Count -gt 3) { Write-Host "                 ... +$($exPaths.Count - 3) more" -ForegroundColor DarkGray }

    # Threat detections
    Write-Host '  Threats      : ' -NoNewline
    if (-not $threats.Count) {
        Write-Host '[OK] no detections on record' -ForegroundColor Green
    }
    else {
        $latest = $threats[0]
        $recent = ((Get-Date) - $latest.InitialDetectionTime).TotalDays -le 7
        $threatColor = if ($recent) { 'Red' } else { 'Yellow' }
        if ($recent) { $warnings++ }
        Write-Host "[$(if ($recent) { '!!' } else { '--' })] $($threats.Count) detection record(s), latest $($(Get-Date $latest.InitialDetectionTime -Format 'yyyy-MM-dd'))" -ForegroundColor $threatColor
    }

    if ($warnings -eq 0) {
        Write-Host '  [OK] defender healthy' -ForegroundColor Green
    }
    else {
        Write-Host "  [!!] $warnings item(s) need attention" -ForegroundColor Red
    }

    if ($PassThru) {
        $lastThreatName = $null
        if ($threats.Count) {
            try { $lastThreatName = (Get-MpThreat -ThreatID $threats[0].ThreatID -ErrorAction Stop | Select-Object -First 1).ThreatName } catch { }
        }
        [PSCustomObject]@{
            RunMode            = $runMode
            RealTime           = [bool]$rtp
            Behavior           = [bool]$behavior
            NetworkInspection  = [bool]$nis
            SignatureAgeDays   = if ($sigTime) { $ageDays } else { $null }
            TamperProtection   = $tamper
            ExclusionPaths     = $exPaths
            ExclusionProcesses = $exProcs
            ExclusionExtensions= $exExts
            ThreatDetections   = $threats.Count
            LastThreat         = $lastThreatName
            Warnings           = $warnings
        }
    }
}

<#
.SYNOPSIS
Scans running processes for suspicious characteristics.
.DESCRIPTION
Finds processes executing from AppData or Temp folders, which is a common malware indicator.
Shows process name, PID, path, and publisher company.
#>
function Get-HawkSuspiciousProcessAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Processes] Temp/AppData process audit' Red
    foreach ($proc in (Get-Process -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $proc.Path } catch { }
        if ($path -and $path -match '(?i)\\(AppData|Temp)\\') {
            [PSCustomObject]@{
                ProcessName = $proc.ProcessName
                Id          = $proc.Id
                Path        = $path
                Company     = try { $proc.Company } catch { $null }
            }
        }
    }
}

<#
.SYNOPSIS
Audits disk usage and identifies cleanup candidates.
.DESCRIPTION
Shows per-drive size, free space, and free percentage for fixed drives.
#>
function Get-HawkDiskPressureAudit {
    <#
    .SYNOPSIS
    Maps disk free space; optionally scans storage hogs and temp bloat.
    .DESCRIPTION
    Lists fixed drives with size/free/percent via CIM, falling back to
    PSDrive. With -IncludeHogs, also lists the largest files under
    -HogPath and the total temp-directory footprint. Alias: diskaudit.
    .PARAMETER IncludeHogs
    Append storage-hog and temp-footprint sections after the disk table.
    .PARAMETER HogPath
    Root path for the storage-hog scan. Default: user profile.
    .PARAMETER HogCount
    Number of largest files to list. Default: 20.
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeHogs,
        [string]$HogPath = "$env:USERPROFILE",
        [int]$HogCount = 20
    )

    Write-HawkHeader '  [Disk] Disk pressure map' Yellow
    $disks = $null
    try {
        $disks = @(Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object DriveType -eq 3)
        if ($disks.Count -eq 0) { $disks = $null }
    }
    catch {
        Write-Verbose "CIM disk query unavailable, falling back to PSDrive: $($_.Exception.Message)"
        $disks = $null
    }

    if ($disks) {
        $disks | Select-Object DeviceID,
        @{ Name = 'SizeGB'; Expression = { [Math]::Round($_.Size / 1GB, 2) } },
        @{ Name = 'FreeGB'; Expression = { [Math]::Round($_.FreeSpace / 1GB, 2) } },
        @{ Name = 'FreePercent'; Expression = { if ($_.Size) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 } } },
        @{ Name = 'Source'; Expression = { 'CIM' } }
    }
    else {
        Get-PSDrive -PSProvider FileSystem |
        Where-Object { $null -ne $_.Free -and $null -ne $_.Used -and $_.Root -match '^[A-Za-z]:\\$' } |
        Select-Object @{ Name = 'DeviceID'; Expression = { "$($_.Name):" } },
        @{ Name = 'SizeGB'; Expression = { [Math]::Round(($_.Used + $_.Free) / 1GB, 2) } },
        @{ Name = 'FreeGB'; Expression = { [Math]::Round($_.Free / 1GB, 2) } },
        @{ Name = 'FreePercent'; Expression = { if (($_.Used + $_.Free) -gt 0) { [Math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 2) } else { 0 } } },
        @{ Name = 'Source'; Expression = { 'PSDrive' } }
    }

    if ($IncludeHogs) {
        Write-HawkHeader "  [Disk] Top $HogCount storage hogs under $HogPath" Magenta
        Get-ChildItem -Path $HogPath -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First $HogCount |
        Select-Object Name, @{ Name = 'MB'; Expression = { [Math]::Round($_.Length / 1MB, 1) } }, DirectoryName

        $tempStats = Get-ChildItem $env:TEMP -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
        Write-Host ("  [Temp] Active System Temp Footprint Volume: {0} MB Allocation" -f [Math]::Round($tempStats.Sum / 1MB, 1)) -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
Audits scheduled tasks for security risks.
.DESCRIPTION
Identifies enabled scheduled tasks whose execution path includes Temp, AppData, or PowerShell/cmd interpreters.
These patterns are common malware persistence mechanisms.
#>
function Get-HawkScheduledTaskRiskAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Tasks] Scheduled task risk audit' DarkYellow
    Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object State -ne 'Disabled' |
    ForEach-Object {
        $task = $_
        $execActions = $task.Actions | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskExecAction' }
        foreach ($action in $execActions) {
            $text = "$($action.Execute) $($action.Arguments)"
            if ($text -match '(?i)AppData|Temp|powershell|pwsh|cmd') {
                [PSCustomObject]@{
                    TaskPath = $task.TaskPath
                    TaskName = $task.TaskName
                    Path     = $action.Execute
                    Args     = $action.Arguments
                }
            }
        }
    }
}

<#
.SYNOPSIS
Audits recent Windows Event Logs for storms or anomalies.
.DESCRIPTION
Counts error/warning events in the last N minutes across System, Application, or Security logs.
Identifies event storms (rapid repeated errors) that indicate system instability.
.PARAMETER WindowMinutes
Lookback window in minutes. Default: 30.
.PARAMETER Threshold
Minimum event count to flag as a storm. Default: 5.
.PARAMETER LogName
Event log to scan. Default: System.
#>
function Get-HawkEventStormAudit {
    [CmdletBinding()]
    param(
        [int]$WindowMinutes = 30,
        [int]$Threshold = 5,
        [string]$LogName = 'System'
    )

    Write-HawkHeader "  [Events] Event storm detection ($WindowMinutes minute window)" DarkRed
    $window = (Get-Date).AddMinutes(-$WindowMinutes)
    Get-WinEvent -FilterHashtable @{ LogName = $LogName; StartTime = $window } -ErrorAction SilentlyContinue |
    Group-Object Id |
    Where-Object Count -gt $Threshold |
    Select-Object Count, Name, @{ Name = 'Source'; Expression = { $_.Group[0].ProviderName } },
        @{ Name = 'Flag'; Expression = { if ($_.Name -in @(6008, 9, 11, 15)) { 'hive-corruption-class' } else { '' } } }
}

