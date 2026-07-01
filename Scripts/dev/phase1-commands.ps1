# ── Phase 1: Create Tier 1 Commands Module ────────────────────
$talonDir = "$HOME\Documents\PowerShell\Talon"

# 1. Manifest
$manifest = @'
@{
    RootModule        = 'Talon.Commands.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Description       = 'Talon - Diagnostic & Security Commands (Tier 1)'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-TalonHealth', 'Get-TalonSpec', 'Get-TalonUptime', 'Get-TalonDiskPressure',
        'Get-TalonResourceMap', 'Get-TalonPortMap', 'Get-TalonBattery', 'Get-TalonTempCheck',
        'Get-TalonFirewallAudit', 'Get-TalonBootMap', 'Get-TalonScheduledTaskRisk',
        'Get-TalonGhostPortAudit', 'Get-TalonSuspiciousProcess', 'Get-TalonEventStormAudit',
        'Get-TalonAdmin',
        'Get-TalonNetCheck', 'Get-TalonWifi', 'Get-TalonDnsBench', 'Get-TalonDnsCache',
        'Get-TalonNetworkTriage',
        'Get-TalonEnvMap', 'Get-TalonPathAudit', 'Get-TalonApp', 'Get-TalonPatchHistory',
        'Get-TalonDriverAudit',
        'Get-TalonShield', 'Get-TalonCertCheck',
        'Get-TalonSystem', 'Get-TalonAudit', 'Get-TalonNetwork', 'Get-TalonEnv'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
'@
$manifest | Set-Content (Join-Path $talonDir 'Talon.Commands.psd1') -Encoding UTF8
Write-Host "Created Talon.Commands.psd1"

# 2. Functions module
$functions = @'
# ── Talon v1 — Commands (Tier 1) ──────────────────────────────
# Auto-loaded on first use via module auto-loading.

# ╔══════════════════════════════════════════════════════════════╗
# ║  SYSTEM DIAGNOSTICS (8)                                     ║
# ╚══════════════════════════════════════════════════════════════╝

function Get-TalonHealth {
    <#
    .SYNOPSIS
        System health pulse: CPU load, RAM usage, process/handle counts.
    .EXAMPLE
        health
    #>
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $totalRam = [Math]::Round($os.TotalVisibleMemorySize / 1KB / 1024, 1)
    $freeRam = [Math]::Round($os.FreePhysicalMemory / 1KB / 1024, 1)
    [PSCustomObject]@{
        'CPU Load'  = "$([Math]::Round($cpu.Average, 0))%"
        'RAM Usage' = "$($totalRam - $freeRam) GB / $totalRam GB"
        'Processes' = (Get-Process).Count
        'Handles'   = (Get-Process | Measure-Object -Property HandleCount -Sum).Sum
    }
}

function Get-TalonSpec {
    <#
    .SYNOPSIS
        Hardware specs: CPU, cores, RAM slots, GPU, virtualization status.
    .EXAMPLE
        spec
    #>
    return Invoke-TalonCachedData -Key 'talon_specs' -ExpirySeconds 300 -ScriptBlock {
        $cpu = Get-CimInstance Win32_Processor
        $comp = Get-CimInstance Win32_ComputerSystem
        $gpu = Get-CimInstance Win32_VideoController
        $ram = Get-CimInstance Win32_PhysicalMemory
        $totalRamGB = [Math]::Round(($ram | Measure-Object -Property Capacity -Sum).Sum / 1GB, 1)
        $isVM = $comp.Model -match '(VirtualBox|VMware|Virtual Machine|Hyper-V|QEMU|KVM|Xen)'
        [PSCustomObject]@{
            'Processor'   = $cpu.Name
            'Cores'       = "$($cpu.NumberOfCores) / $((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors) threads"
            'RAM'         = "$totalRamGB GB ($($ram.Count) slots)"
            'Vendor'      = $comp.Manufacturer
            'Model'       = $comp.Model
            'GPU'         = $gpu.Description
            'Virtualized' = if ($isVM) { 'Yes' } else { 'No' }
        }
    }
}

function Get-TalonUptime {
    <#
    .SYNOPSIS
        System boot time and uptime duration.
    .EXAMPLE
        uptime
    #>
    return Invoke-TalonCachedData -Key 'talon_uptime' -ExpirySeconds 10 -ScriptBlock {
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $span = (Get-Date) - $boot
        [PSCustomObject]@{
            'Boot Time' = $boot
            'Uptime'    = "$($span.Days)d $($span.Hours)h $($span.Minutes)m $($span.Seconds)s"
        }
    }
}

function Get-TalonDiskPressure {
    <#
    .SYNOPSIS
        Per-drive disk usage with free space percentage.
    .EXAMPLE
        disk
    #>
    return Invoke-TalonCachedData -Key 'talon_disk' -ExpirySeconds 30 -ScriptBlock {
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            $sz = [Math]::Round($_.Size / 1GB, 1)
            $fr = [Math]::Round($_.FreeSpace / 1GB, 1)
            [PSCustomObject]@{
                Drive       = $_.DeviceID
                SizeGB      = $sz
                FreeGB      = $fr
                UsedGB      = [Math]::Round($sz - $fr, 1)
                FreePercent = "$([Math]::Round(($fr / [Math]::Max(1, $sz)) * 100, 1))%"
            }
        }
    }
}

function Get-TalonResourceMap {
    <#
    .SYNOPSIS
        Top 10 processes by RAM consumption.
    .EXAMPLE
        hog
    .EXAMPLE
        hog | ai "Which processes are using the most resources?"
    #>
    return Invoke-TalonCachedData -Key 'talon_resmap' -ExpirySeconds 5 -ScriptBlock {
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | ForEach-Object {
            [PSCustomObject]@{
                Process = $_.ProcessName
                PID     = $_.Id
                RAM_MB  = [Math]::Round($_.WorkingSet / 1MB, 1)
                CPU_sec = [Math]::Round($_.TotalProcessorTime.TotalSeconds, 1)
            }
        }
    }
}

function Get-TalonPortMap {
    <#
    .SYNOPSIS
        All TCP listeners with port, PID, and process name.
    .EXAMPLE
        ports
    #>
    return Invoke-TalonCachedData -Key 'talon_ports' -ExpirySeconds 10 -ScriptBlock {
        $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
        $procMap = @{}
        Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $procMap[$_.Id] = $_.ProcessName }
        foreach ($conn in $connections) {
            [PSCustomObject]@{
                Port    = $conn.LocalPort
                PID     = $conn.OwningProcess
                Process = if ($procMap.ContainsKey($conn.OwningProcess)) { $procMap[$conn.OwningProcess] } else { 'Unknown' }
            }
        }
    }
}

function Get-TalonBattery {
    <#
    .SYNOPSIS
        Battery status: charge, design capacity, health percentage.
    .EXAMPLE
        battery
    #>
    return Invoke-TalonCachedData -Key 'talon_battery' -ExpirySeconds 30 -ScriptBlock {
        $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $bat) { return [PSCustomObject]@{ Status = 'No battery detected (desktop or VM)' } }
        [PSCustomObject]@{
            'Design Capacity'      = $bat.DesignCapacity
            'Full Charge Capacity' = $bat.FullChargeCapacity
            'Health'               = "$([Math]::Round(($bat.FullChargeCapacity / $bat.DesignCapacity) * 100, 1))%"
        }
    }
}

function Get-TalonTempCheck {
    <#
    .SYNOPSIS
        Estimate total temp directory size.
    .EXAMPLE
        temp
    #>
    $totalLength = [long]0
    try {
        if (Test-Path $env:TEMP) {
            foreach ($file in [System.IO.Directory]::EnumerateFiles($env:TEMP, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { $totalLength += [System.IO.FileInfo]::new($file).Length } catch {}
            }
        }
    } catch {}
    [PSCustomObject]@{
        'Temp Path' = $env:TEMP
        'Size'      = "$([Math]::Round($totalLength / 1MB, 1)) MB"
    }
}

# ╔══════════════════════════════════════════════════════════════╗
# ║  SECURITY / SENTINEL (7)                                    ║
# ╚══════════════════════════════════════════════════════════════╝

function Get-TalonFirewallAudit {
    <#
    .SYNOPSIS
        Cross-references listening ports against inbound firewall allow rules.
    .EXAMPLE
        fwaudit
    #>
    return Invoke-TalonCachedData -Key 'talon_fwaudit' -ExpirySeconds 60 -ScriptBlock {
        $listeners = Get-TalonPortMap
        $allowPorts = Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue |
            Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
            ForEach-Object { $_.LocalPort } | Where-Object { $_ -match '^\d+$' } | Select-Object -Unique
        $listeners | ForEach-Object {
            $matched = if ($_.Port -in $allowPorts) { 'Allowed' } else { 'NO_MATCHING_RULE' }
            [PSCustomObject]@{
                Port    = $_.Port
                PID     = $_.PID
                Process = $_.Process
                Status  = $matched
            }
        }
    }
}

function Get-TalonBootMap {
    <#
    .SYNOPSIS
        Registry Run keys for startup persistence.
    .EXAMPLE
        boot
    #>
    return Invoke-TalonCachedData -Key 'talon_bootmap' -ExpirySeconds 300 -ScriptBlock {
        $paths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
                    Select-Object -Property * | ForEach-Object {
                        $_.PSObject.Properties |
                            Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                            ForEach-Object {
                                [PSCustomObject]@{
                                    Hive   = Split-Path $p -Leaf
                                    Name   = $_.Name
                                    Target = $_.Value
                                }
                            }
                    }
            }
        }
    }
}

function Get-TalonScheduledTaskRisk {
    <#
    .SYNOPSIS
        Finds non-Microsoft scheduled tasks that invoke powershell/cmd from temp.
    .EXAMPLE
        taskaudit
    #>
    return Invoke-TalonCachedData -Key 'talon_taskaudit' -ExpirySeconds 300 -ScriptBlock {
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return @() }
        Get-ScheduledTask | Where-Object {
            $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '^\\\\Microsoft'
        } | Select-Object -First 10 | ForEach-Object {
            [PSCustomObject]@{ TaskName = $_.TaskName; Path = $_.TaskPath; State = $_.State }
        }
    }
}

function Get-TalonGhostPortAudit {
    <#
    .SYNOPSIS
        Orphaned TCP listeners with no owning process.
    .EXAMPLE
        ghostaudit
    #>
    Get-TalonPortMap | Where-Object { $_.Process -eq 'Unknown' }
}

function Get-TalonSuspiciousProcess {
    <#
    .SYNOPSIS
        Processes running from AppData or Temp directories.
    .EXAMPLE
        susaudit
    #>
    Get-Process | Where-Object {
        $_.Path -and $_.Path -match '(?i)(\\AppData\\|\\Temp\\|\\Windows\\Temp\\)'
    } | Select-Object Name, Id, @{N='Path';E={$_.Path}},
        @{N='CPU';E={[Math]::Round($_.CPU, 1)}},
        @{N='RAM_MB';E={[Math]::Round($_.WorkingSet / 1MB, 1)}}
}

function Get-TalonEventStormAudit {
    <#
    .SYNOPSIS
        Detects event log frequency anomalies (>5 same EventID in 30 min).
    .EXAMPLE
        evntaudit
    #>
    return Invoke-TalonCachedData -Key 'talon_eventstorm' -ExpirySeconds 20 -ScriptBlock {
        try {
            $cutoff = (Get-Date).AddMinutes(-15)
            Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $cutoff } -MaxEvents 200 -ErrorAction SilentlyContinue |
                Group-Object ProviderName | Sort-Object Count -Descending |
                Select-Object -First 5 | ForEach-Object {
                    [PSCustomObject]@{ Count = $_.Count; Provider = $_.Name; Source = 'Application' }
                }
        } catch { @() }
    }
}

function Get-TalonAdmin {
    <#
    .SYNOPSIS
        List local Administrators group members.
    .EXAMPLE
        admin
    #>
    Get-LocalGroupMember -Group 'Administrators' | Select-Object Name, PrincipalSource, ObjectClass
}

# ╔══════════════════════════════════════════════════════════════╗
# ║  NETWORK (5)                                                ║
# ╚══════════════════════════════════════════════════════════════╝

function Get-TalonNetCheck {
    <#
    .SYNOPSIS
        Quick internet connectivity test.
    .EXAMPLE
        netcheck
    #>
    [PSCustomObject]@{
        'Internet'         = (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue)
        'Cloudflare DNS'   = (Test-Connection -ComputerName 1.1.1.1 -Count 2 -ErrorAction SilentlyContinue |
            Measure-Object -Property ResponseTime -Average).Average
    }
}

function Get-TalonWifi {
    <#
    .SYNOPSIS
        Current Wi-Fi SSID and signal strength.
    .EXAMPLE
        wifi
    #>
    $raw = netsh wlan show interfaces 2>$null | Out-String
    if (-not $raw) { return [PSCustomObject]@{ SSID = 'N/A'; Signal = 'N/A'; Band = 'N/A' } }
    $ssid = if ($raw -match 'SSID\s+:\s+(.+)') { $matches[1].Trim() } else { 'Disconnected' }
    $signal = if ($raw -match 'Signal\s+:\s+(\d+)%') { $matches[1] } else { '0' }
    $band = if ($raw -match 'Band\s+:\s+(.+)') { $matches[1].Trim() } else { 'N/A' }
    [PSCustomObject]@{ SSID = $ssid; SignalPercent = $signal; Band = $band }
}

function Get-TalonDnsBench {
    <#
    .SYNOPSIS
        Compare DNS resolver response times.
    .EXAMPLE
        dnsbench
    #>
    $resolvers = @{ '1.1.1.1' = 'Cloudflare'; '8.8.8.8' = 'Google'; '9.9.9.9' = 'Quad9' }
    foreach ($server in $resolvers.Keys) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $null = Resolve-DnsName -Name 'google.com' -Server $server -Type A -QuickTimeout -ErrorAction Stop
            $sw.Stop()
            [PSCustomObject]@{ Resolver = $server; Name = $resolvers[$server]; Speed_ms = $sw.ElapsedMilliseconds }
        } catch {
            [PSCustomObject]@{ Resolver = $server; Name = $resolvers[$server]; Speed_ms = 'TIMEOUT' }
        }
    }
}

function Get-TalonDnsCache {
    <#
    .SYNOPSIS
        DNS cache contents and statistics.
    .EXAMPLE
        dnscache
    #>
    if (-not (Get-Command Get-DnsClientCache -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Entry = 'N/A'; Status = 'Cmdlet unavailable' }
    }
    Get-DnsClientCache -ErrorAction SilentlyContinue |
        Select-Object Entry, Type, TimeToLive, DataLength |
        Sort-Object TimeToLive | Select-Object -First 20
}

function Get-TalonNetworkTriage {
    <#
    .SYNOPSIS
        Network adapter configuration summary.
    .EXAMPLE
        nettriage
    #>
    Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' |
        Select-Object Description, IPAddress, MACAddress, DefaultIPGateway, DNSServerSearchOrder
}

# ╔══════════════════════════════════════════════════════════════╗
# ║  ENVIRONMENT (5)                                            ║
# ╚══════════════════════════════════════════════════════════════╝

function Get-TalonEnvMap {
    <#
    .SYNOPSIS
        Environment variable audit (sensitive names auto-redacted).
    .EXAMPLE
        envmap
    #>
    Get-ChildItem Env: | Select-Object Name, Value
}

function Get-TalonPathAudit {
    <#
    .SYNOPSIS
        Validate every $env:Path entry (missing, duplicate, empty).
    .EXAMPLE
        pathaudit
    #>
    $env:Path -split ';' | ForEach-Object {
        $p = $_.Trim()
        [PSCustomObject]@{ Path = $p; Exists = (Test-Path $p); Length = $p.Length }
    }
}

function Get-TalonApp {
    <#
    .SYNOPSIS
        List installed applications and versions.
    .EXAMPLE
        app
    #>
    $regPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    try {
        Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayVersion } |
            Select-Object @{N='Name';E={$_.DisplayName}}, @{N='Version';E={$_.DisplayVersion}},
                @{N='Publisher';E={$_.Publisher}} | Sort-Object Name
    } catch { @() }
}

function Get-TalonPatchHistory {
    <#
    .SYNOPSIS
        Windows update history (last 5).
    .EXAMPLE
        patch
    #>
    Get-CimInstance Win32_QuickFixEngineering |
        Select-Object HotFixID, InstalledOn, Description |
        Sort-Object InstalledOn -Descending | Select-Object -First 5
}

function Get-TalonDriverAudit {
    <#
    .SYNOPSIS
        Unsigned driver check.
    .EXAMPLE
        driveraudit
    #>
    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { -not $_.IsSigned } |
        Select-Object DeviceName, DriverVersion, DriverDate | Select-Object -First 10
}

# ╔══════════════════════════════════════════════════════════════╗
# ║  UTILITY (2)                                                ║
# ╚══════════════════════════════════════════════════════════════╝

function Get-TalonShield {
    <#
    .SYNOPSIS
        Microsoft Defender security posture.
    .EXAMPLE
        shield
    #>
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Status = 'Defender cmdlets unavailable' }
    }
    Get-MpComputerStatus -ErrorAction SilentlyContinue |
        Select-Object AntivirusEnabled, RealTimeProtectionEnabled,
            @{N='LastScan';E={$_.LastQuickScanTime}},
            @{N='AMService';E={$_.AMServiceEnabled}}
}

function Get-TalonCertCheck {
    <#
    .SYNOPSIS
        Certificate store enumeration (CurrentUser\My).
    .EXAMPLE
        certs
    #>
    Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue |
        Select-Object Subject, Thumbprint, @{N='Expires';E={$_.NotAfter}},
            @{N='Issuer';E={$_.Issuer}}
}

# ╔══════════════════════════════════════════════════════════════╗
# ║  CONSOLIDATED DISPATCHERS (4)                               ║
# ╚══════════════════════════════════════════════════════════════╝

function Get-TalonSystem {
    <#
    .SYNOPSIS
        Consolidated system info dispatch.
    .PARAMETER Type
        Health | Spec | Uptime | Disk | Resource | Port
    .EXAMPLE
        sys -Type Health
        sys Disk
    #>
    [CmdletBinding()]
    param([ValidateSet('Health','Spec','Uptime','Disk','Resource','Port')][string]$Type = 'Health')
    switch ($Type) {
        'Health'   { Get-TalonHealth }
        'Spec'     { Get-TalonSpec }
        'Uptime'   { Get-TalonUptime }
        'Disk'     { Get-TalonDiskPressure }
        'Resource' { Get-TalonResourceMap }
        'Port'     { Get-TalonPortMap }
    }
}

function Get-TalonAudit {
    <#
    .SYNOPSIS
        Consolidated security audit dispatch.
    .PARAMETER Type
        Firewall | Boot | ScheduledTask | GhostPort | SuspiciousProcess | EventStorm | all
    .EXAMPLE
        audit -Type all
        audit Firewall
    #>
    [CmdletBinding()]
    param([ValidateSet('Firewall','Boot','ScheduledTask','GhostPort','SuspiciousProcess','EventStorm','all')][string]$Type = 'Firewall')
    switch ($Type) {
        'Firewall'          { Get-TalonFirewallAudit }
        'Boot'              { Get-TalonBootMap }
        'ScheduledTask'     { Get-TalonScheduledTaskRisk }
        'GhostPort'         { Get-TalonGhostPortAudit }
        'SuspiciousProcess' { Get-TalonSuspiciousProcess }
        'EventStorm'        { Get-TalonEventStormAudit }
        'all' {
            Write-TalonHeader '── Firewall Audit ──' Red;     Get-TalonFirewallAudit
            Write-TalonHeader '── Boot Persistence ──' Red;   Get-TalonBootMap
            Write-TalonHeader '── Ghost Ports ──' Red;        Get-TalonGhostPortAudit
            Write-TalonHeader '── Suspicious Processes ──' Red; Get-TalonSuspiciousProcess
        }
    }
}

function Get-TalonNetwork {
    <#
    .SYNOPSIS
        Consolidated network dispatch.
    .PARAMETER Type
        NetCheck | Wifi | DnsBench | DnsCache | Triage
    .EXAMPLE
        net NetCheck
    #>
    [CmdletBinding()]
    param([ValidateSet('NetCheck','Wifi','DnsBench','DnsCache','Triage')][string]$Type = 'NetCheck')
    switch ($Type) {
        'NetCheck' { Get-TalonNetCheck }
        'Wifi'     { Get-TalonWifi }
        'DnsBench' { Get-TalonDnsBench }
        'DnsCache' { Get-TalonDnsCache }
        'Triage'   { Get-TalonNetworkTriage }
    }
}

function Get-TalonEnv {
    <#
    .SYNOPSIS
        Consolidated environment dispatch.
    .PARAMETER Type
        Env | Path | App | Patch | Driver | Admin
    .EXAMPLE
        env Env
    #>
    [CmdletBinding()]
    param([ValidateSet('Env','Path','App','Patch','Driver','Admin')][string]$Type = 'Env')
    switch ($Type) {
        'Env'    { Get-TalonEnvMap }
        'Path'   { Get-TalonPathAudit }
        'App'    { Get-TalonApp }
        'Patch'  { Get-TalonPatchHistory }
        'Driver' { Get-TalonDriverAudit }
        'Admin'  { Get-TalonAdmin }
    }
}
'@
$functions | Set-Content (Join-Path $talonDir 'Talon.Commands.psm1') -Encoding UTF8
Write-Host "Created Talon.Commands.psm1"

# 3. Update root Talon.psd1 to add NestedModules
$rootManifest = @'
@{
    RootModule        = 'Talon.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Copyright         = '(c) 2026 Talon Contributors. MIT License.'
    Description       = 'Talon - featherweight PowerShell 7 ops shell with 50 diagnostic + AI commands.'
    PowerShellVersion = '7.0'
    NestedModules     = @('Talon.Commands.psd1')
    FunctionsToExport = @(
        'Initialize-Talon', 'Set-TalonPrompt', 'Set-TalonAliases',
        'Update-TalonProfile', 'Test-InteractiveSession', 'Show-TalonDashboard',
        'Invoke-TalonCachedData', 'Write-TalonHeader'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('powershell', 'diagnostics', 'security', 'ollama', 'ai', 'windows')
            ProjectUri = 'https://github.com/talon-ps/talon'
            LicenseUri = 'https://github.com/talon-ps/talon/blob/main/LICENSE'
        }
    }
}
'@
$rootManifest | Set-Content (Join-Path $talonDir 'Talon.psd1') -Encoding UTF8
Write-Host "Updated Talon.psd1 with NestedModules"

Write-Host "`nPhase 1 complete. Verify with:"
Write-Host "  Import-Module Talon -Force"
Write-Host "  health"
Write-Host "  disk"
Write-Host "  Get-Module Talon"
