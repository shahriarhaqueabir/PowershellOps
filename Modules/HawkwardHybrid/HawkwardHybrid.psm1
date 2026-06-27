# ==============================================================================
# Hawkward Hybrid 11.2 - Integrated Operational Core Engine (Production Refactored)
# ==============================================================================

$script:HawkVersion = '11.2'
$script:HawkDefaultProjectRoot = if ($env:HAWK_PROJECT_ROOT) { $env:HAWK_PROJECT_ROOT } else { Join-Path $env:USERPROFILE 'Projects' }
$script:HawkRequiredModules = @('Terminal-Icons', 'PSReadLine', 'PSTree')
$script:HawkSuppressHeaders = $false
$script:HawkSensitiveNamePattern = '(?i)(secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)'
$script:HawkLastFirewallFilterError = $null
$script:HawkWorkspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:HawkReportRoot = Join-Path $script:HawkWorkspaceRoot 'Reports'
$script:HawkMemoryRoot = Join-Path $script:HawkWorkspaceRoot 'Memory'
$script:HawkMemoryFile = Join-Path $script:HawkMemoryRoot 'hawk-memory.jsonl'

# Initialize thread-safe data store cache allocation
if (-not $script:HawkCacheStore) {
    $script:HawkCacheStore = [hashtable]::Synchronized(@{})
}

# ── 1. CENTRALIZED PLATFORM DATA CACHE SUITE (THREAD-SAFE FIXED) ──────────────
function Invoke-HawkCachedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][int]$ExpirySeconds,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock
    )
    $now = Get-Date

    if ($script:HawkCacheStore.ContainsKey($Key)) {
        $entry = $script:HawkCacheStore[$Key]
        if (($now - $entry.Timestamp).TotalSeconds -lt $ExpirySeconds) {
            return $entry.Value
        }
    }

    $computedValue = &$ScriptBlock
    $script:HawkCacheStore[$Key] = [hashtable]::Synchronized(@{ Timestamp = $now; Value = $computedValue })
    return $computedValue
}

# ── 2. TYPED ARCHITECTURE CORE MEMORY SCHEMA ─────────────────────────────────────
class HawkMemoryEntry {
    [string] $Id
    [string] $Type
    [string[]]$Tags
    [string] $Text
    [string] $Source
    [string] $Created
    [string] $Confidence
    [bool]   $Pinned

    HawkMemoryEntry() {}

    HawkMemoryEntry([hashtable]$map) {
        $this.Id         = $map.Id
        $this.Type       = $map.Type
        $this.Tags       = $map.Tags
        $this.Text       = $map.Text
        $this.Source     = $map.Source
        $this.Created    = $map.Created
        $this.Confidence = $map.Confidence
        $this.Pinned     = [bool]$map.Pinned
    }
}

# ── 3. BASELINE ENVIRONMENT LOGIC ────────────────────────────────────────────────
function Write-HawkHeader {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Accept parameter for API consistency')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = 'Cyan'
    )
    if (-not $script:HawkSuppressHeaders) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-HawkInteractiveSession {
    if ($env:HAWK_NO_DASH -or $env:CI) { return $false }
    try {
        return [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected
    } catch {
        return $false
    }
}

function Install-HawkPrerequisite {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string[]]$ModuleName = $script:HawkRequiredModules
    )
    foreach ($module in $ModuleName) {
        if (Get-Module -ListAvailable -Name $module) {
            [PSCustomObject]@{ Module = $module; Status = 'AlreadyInstalled' }
            continue
        }
        if ($PSCmdlet.ShouldProcess($module, 'Install PowerShell module for current user')) {
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
                [PSCustomObject]@{ Module = $module; Status = 'Installed' }
            } catch {
                [PSCustomObject]@{ Module = $module; Status = 'Failed'; Message = $_.Exception.Message }
            }
        }
    }
}

function Import-HawkPrerequisite {
    [CmdletBinding()]
    param(
        [string[]]$ModuleName = $script:HawkRequiredModules,
        [switch]$Quiet
    )
    $results = foreach ($module in $ModuleName) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            [PSCustomObject]@{ Module = $module; Status = 'Missing'; Message = 'Run Install-HawkPrerequisites' }
            continue
        }
        try {
            Import-Module -Name $module -ErrorAction SilentlyContinue 2>$null
            [PSCustomObject]@{ Module = $module; Status = 'Imported'; Message = '' }
        } catch {
            [PSCustomObject]@{ Module = $module; Status = 'Failed'; Message = $_.Exception.Message }
        }
    }
    if (-not $Quiet) { $results }
}

function Set-HawkReadLine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) { return }
    if ($PSCmdlet.ShouldProcess('PSReadLine options', 'Configure prediction settings')) {
        try {
            Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
        } catch { Write-Warning "PSReadLine configuration failed: $($_.Exception.Message)" }
    }
}

# ── 4. PROMPT & SHELL DECORATION ──────────────────────────────────────────────
function Get-HawkPromptText {
    param([bool]$LastSuccess = $true)
    $esc = [char]27
    $reset = "${esc}[0m"
    $path = (Get-Location).Path -replace "^$([Regex]::Escape([Environment]::GetFolderPath('UserProfile')))", '~'
    $pathSegment = "${esc}[48;5;239m${esc}[38;5;255m 󰉋 $path ${reset}"
    $timeSegment = "${esc}[48;5;24m${esc}[38;5;117m 󱑎 $([System.DateTime]::Now.ToString('HH:mm:ss')) ${reset}"
    $gitSegment = Get-HawkPromptGitSegment -Reset $reset
    $statusColor = if ($LastSuccess) { "${esc}[38;5;121m" } else { "${esc}[38;5;196m" }
    return "`n${pathSegment}${timeSegment}${gitSegment}`n${statusColor}󱞩 ${reset} "
}

function Get-HawkPromptGitSegment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Used in cached scriptblock via closure')]
    [CmdletBinding()]
    param([string]$Reset)
    $cwd = $ExecutionContext.SessionState.Path.CurrentLocation.Path

    if (-not $script:HawkGitPromptBlock) {
        $script:HawkGitPromptBlock = {
            param([string]$currentDir, [string]$ansiReset)
            $gitDir = Join-Path $currentDir '.git'
            if (-not (Test-Path $gitDir)) {
                $parent = Split-Path $currentDir -Parent
                for ($i = 0; $i -lt 3 -and $parent; $i++) {
                    if (Test-Path (Join-Path $parent '.git')) {
                        $gitDir = Join-Path $parent '.git'
                        break
                    }
                    $parent = Split-Path $parent -Parent
                }
            }
            if (-not (Test-Path $gitDir)) { return '' }
            try {
                $headPath = Join-Path $gitDir 'HEAD'
                if (Test-Path $headPath) {
                    $headContent = Get-Content $headPath -Raw -ErrorAction SilentlyContinue
                    if ($headContent -match 'ref:\s+refs/heads/(.*)') {
                        $branch = $matches[1].Trim()
                        $esc = [char]27
                        return "${esc}[48;5;28m${esc}[38;5;255m 🌿 $branch [FS-Cached] ${ansiReset}"
                    }
                }
            } catch { Write-Verbose "Git prompt cache failed: $($_.Exception.Message)" }
            return ''
        }
    }

    return Invoke-HawkCachedData -Key "git_prompt_$cwd" -ExpirySeconds 3 -ScriptBlock {
        &$script:HawkGitPromptBlock $cwd $Reset
    }
}

function Set-HawkPrompt {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if ($PSCmdlet.ShouldProcess('global:prompt', 'Set custom prompt function')) {
        if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
            Set-Item -Path Function:\global:Prompt -Value { Get-HawkPromptText -LastSuccess:$? }
        }
    }
}

# ── 5. SECURITY DATA PROTECTION REFACTOR (SAFE REGEX PROCESSING) ──────────────
function Protect-HawkSensitiveText {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $true)][AllowNull()]$InputObject)
    process {
        if ($null -eq $InputObject) { return }
        $text = if ($InputObject -is [string]) { $InputObject } else { $InputObject | Out-String }

        $cleanPattern = $script:HawkSensitiveNamePattern -replace '\(\?[a-z]+\)', ''
        $redacted = [regex]::Replace($text, ('(?im)^(\s*[^=\r\n]*(?:' + $cleanPattern + ')[^=\r\n]*\s*=\s*).+$'), '$1<REDACTED>')
        $jsonPattern = '(?i)("(?:[^"]*(?:' + $cleanPattern + ')[^"]*)"\s*:\s*")[^"]*(")'
        [regex]::Replace($redacted, $jsonPattern, '$1<REDACTED>$2')
    }
}

# ── 6. TELEMETRY ROUTINES HARDENING (DATA OUTPUT ONLY - NO WIN32_PRODUCT) ────
function Get-HawkHealth {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $totalRam = [Math]::Round($os.TotalVisibleMemorySize / 1KB / 1024, 1)
    $freeRam = [Math]::Round($os.FreePhysicalMemory / 1KB / 1024, 1)
    [PSCustomObject]@{
        "CPU Load"  = "$([Math]::Round($cpu.Average, 0))%"
        "RAM Usage" = "$($totalRam - $freeRam) GB / $totalRam GB"
        "Processes" = (Get-Process).Count
        "Handles"   = (Get-Process | Measure-Object -Property HandleCount -Sum).Sum
    }
}

function Get-HawkSpec {
    return Invoke-HawkCachedData -Key 'sys_specs' -ExpirySeconds 300 -ScriptBlock {
        $cpu = Get-CimInstance Win32_Processor
        $comp = Get-CimInstance Win32_ComputerSystem
        $gpu = Get-CimInstance Win32_VideoController
        [PSCustomObject]@{
            "Processor"       = $cpu.Name
            "Cores"           = $cpu.NumberOfCores
            "Vendor"          = $comp.Manufacturer
            "Model"           = $comp.Model
            "Graphics Engine" = $gpu.Description
        }
    }
}

function Get-HawkUptime {
    return Invoke-HawkCachedData -Key 'sys_uptime' -ExpirySeconds 10 -ScriptBlock {
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $span = (Get-Date) - $boot
        [PSCustomObject]@{
            "System Boot Anchor"  = $boot
            "Continuous Run Time" = "$($span.Days)d $($span.Hours)h $($span.Minutes)m"
        }
    }
}

function Get-HawkRamInfo {
    return Invoke-HawkCachedData -Key 'sys_raminfo' -ExpirySeconds 600 -ScriptBlock {
        Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, @{N='CapacityGB';E={[Math]::Round($_.Capacity / 1GB, 1)}}, Speed, Manufacturer
    }
}

function Get-HawkBattery {
    return Invoke-HawkCachedData -Key 'sys_battery' -ExpirySeconds 30 -ScriptBlock {
        $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $bat) {
            return [PSCustomObject]@{ "Status" = 'No battery hardware tracked' }
        }
        [PSCustomObject]@{
            "Design Capacity"          = $bat.DesignCapacity
            "Full Charge Capacity"    = $bat.FullChargeCapacity
            "Calculated Health Status" = "$([Math]::Round(($bat.FullChargeCapacity / $bat.DesignCapacity) * 100, 1))%"
        }
    }
}

function Get-HawkDisplay {
    return Invoke-HawkCachedData -Key 'sys_displays' -ExpirySeconds 600 -ScriptBlock {
        Get-CimInstance Win32_VideoController | Select-Object Description, VideoModeDescription
    }
}

function Get-HawkAdmin {
    Get-LocalGroupMember -Group "Administrators" | Select-Object Name, PrincipalSource, ObjectClass
}

function Get-HawkDiskPressureAudit {
    return Invoke-HawkCachedData -Key 'sys_diskpressure' -ExpirySeconds 30 -ScriptBlock {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            $sz = [Math]::Round($_.Size / 1GB, 1)
            $fr = [Math]::Round($_.FreeSpace / 1GB, 1)
            [PSCustomObject]@{
                DeviceID    = $_.DeviceID
                SizeGB      = $sz
                FreeGB      = $fr
                FreePercent = "$([Math]::Round(($fr / [Math]::Max(1, $sz)) * 100, 1))%"
            }
        }
    }
}

function Get-HawkResourceMap {
    return Invoke-HawkCachedData -Key 'sys_resourcemap' -ExpirySeconds 5 -ScriptBlock {
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | ForEach-Object {
            [PSCustomObject]@{
                ProcessName = $_.ProcessName
                Id          = $_.Id
                RAMMB       = [Math]::Round($_.WorkingSet / 1MB, 1)
                CPUSec      = [Math]::Round($_.Cpu, 1)
            }
        }
    }
}

function Get-HawkPortMap {
    return Invoke-HawkCachedData -Key 'sys_portmap' -ExpirySeconds 10 -ScriptBlock {
        if ($IsWindows) {
            if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
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
            } else {
                foreach ($conn in [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()) {
                    [PSCustomObject]@{ Port = $conn.Port; PID = 'N/A'; Process = 'System Listen Stack' }
                }
            }
        } else {
            foreach ($conn in [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()) {
                [PSCustomObject]@{ Port = $conn.Port; PID = 'N/A'; Process = 'System Listen Stack' }
            }
        }
    }
}

function Get-HawkApp {
    if (-not $IsWindows) { return [PSCustomObject]@{ Name = 'Cross-platform Environment'; Version = 'N/A' } }
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    try {
        Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayVersion } |
            Select-Object @{N='Name';E={$_.DisplayName}}, @{N='Version';E={$_.DisplayVersion}}
    } catch { @() }
}

function Get-HawkTempCheck {
    $totalLength = [long]0
    try {
        if (Test-Path $env:TEMP) {
            foreach ($file in [System.IO.Directory]::EnumerateFiles($env:TEMP, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { $totalLength += [System.IO.FileInfo]::new($file).Length } catch { Write-Verbose "Could not get file size: $($_.Exception.Message)" }
            }
        }
    } catch { Write-Warning "Temp directory enumeration failed: $($_.Exception.Message)" }
    [PSCustomObject]@{
        Target = $env:TEMP
        SizeMB = [Math]::Round(($totalLength / 1MB), 1)
    }
}

function Get-HawkClipCheck {
    $len = try {
        if (Get-Command Get-Clipboard -ErrorAction SilentlyContinue) {
            (Get-Clipboard -Raw -ErrorAction SilentlyContinue).Length
        } else { 0 }
    } catch { 0 }
    [PSCustomObject]@{ ClipboardLength = if ($null -eq $len) { 0 } else { $len } }
}

function Get-HawkFirewallAudit {
    return Invoke-HawkCachedData -Key 'sys_fwaudit' -ExpirySeconds 60 -ScriptBlock {
        if (-not (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue)) {
            return [PSCustomObject]@{ Port = 'ALL'; PID = '0'; Process = 'N/A'; Status = 'NetSecurity Module Missing' }
        }
        $listeners = Get-HawkPortMap
        $allowPorts = Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue |
            Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
            ForEach-Object { $_.LocalPort } | Where-Object { $_ -match '^\d+$' } | Select-Object -Unique
        $listeners | ForEach-Object {
            $matched = if ($_.Port -in $allowPorts) { 'Allowed' } else { 'NO_MATCHING_INBOUND_ALLOW_RULE' }
            [PSCustomObject]@{
                Port    = $_.Port
                PID     = $_.PID
                Process = $_.Process
                Status  = $matched
            }
        }
    }
}

function Get-HawkBootMap {
    return Invoke-HawkCachedData -Key 'sys_bootmap' -ExpirySeconds 300 -ScriptBlock {
        $paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
        foreach ($p in $paths) {
            if (Test-Path $p) {
                $val = Get-ItemProperty -Path $p
                $val.PSObject.Properties |
                    Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                    ForEach-Object { [PSCustomObject]@{ Hive = (Split-Path $p -Leaf); Name = $_.Name; Target = $_.Value } }
            }
        }
    }
}

function Get-HawkScheduledTaskRiskAudit {
    return Invoke-HawkCachedData -Key 'sys_taskaudit' -ExpirySeconds 300 -ScriptBlock {
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return @() }
        Get-ScheduledTask |
            Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '^\\\\Microsoft' } |
            Select-Object -First 10 |
            ForEach-Object { [PSCustomObject]@{ TaskName = $_.TaskName; Path = $_.TaskPath } }
    }
}

function Get-HawkEventStormAudit {
    return Invoke-HawkCachedData -Key 'sys_eventstorm' -ExpirySeconds 20 -ScriptBlock {
        try {
            $cutoff = (Get-Date).AddMinutes(-15)
            Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $cutoff } -MaxEvents 200 -ErrorAction SilentlyContinue |
                Group-Object ProviderName |
                Sort-Object Count -Descending |
                Select-Object -First 5 |
                ForEach-Object { [PSCustomObject]@{ Count = $_.Count; Name = $_.Name; Source = 'Application Log' } }
        } catch { return @() }
    }
}

# ── 7. INTERACTIVE UTILITIES & ALIAS MAPPINGS ─────────────────────────────────
function Get-HawkGhostPortAudit { Get-HawkPortMap | Where-Object { $_.Process -in @('Unknown', 'System Listen Stack') } }
function Get-HawkSuspiciousProcessAudit {
    Get-Process | Where-Object { $_.Path -and $_.Path -match '(?i)(\\AppData\\|\\Temp\\|\\Windows\\Temp\\)' } |
        Select-Object Name, Id, @{N='Path';E={$_.Path}}, @{N='CPU';E={[Math]::Round($_.CPU, 1)}}, @{N='RAMMB';E={[Math]::Round($_.WorkingSet / 1MB, 1)}}
}

function Get-HawkEnvMap { Get-ChildItem Env: | Select-Object Name, Value }
function Get-HawkPathAudit { $env:Path -split ';' | ForEach-Object { [PSCustomObject]@{ Path = $_; Exists = (Test-Path $_) } } }
function Get-HawkNetworkTriage { Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | Select-Object Description, IPAddress, MACAddress }
function Show-HawkManual {
    $manualPath = Join-Path $script:HawkWorkspaceRoot 'MANUAL.md'
    if (Test-Path $manualPath) {
        Write-Host "  Opening MANUAL.md..." -ForegroundColor Cyan
        Invoke-Item $manualPath
    } else {
        Write-Warning "Manual not found at: $manualPath"
    }
}
function Invoke-ExplorerHere { Start-Process explorer.exe -ArgumentList (Get-Location).Path }
function Get-HawkProject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding()]
    param()
    [PSCustomObject]@{ CurrentRoot = ($global:HawkProjectRoot) }
}
function Invoke-HawkProject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$Path)
    if ($PSCmdlet.ShouldProcess("Project root '$Path'", 'Set project root')) {
        $global:HawkProjectRoot = $Path
    }
    Get-HawkProject
}
function Get-HawkHypervisor {
    $model = (Get-CimInstance Win32_ComputerSystem).Model
    $isVM = $model -match '(VirtualBox|VMware|Virtual Machine|Hyper-V|VirtualBox|QEMU|KVM|Xen)'
    [PSCustomObject]@{ Status = if ($isVM) { 'Virtual' } else { 'Physical' }; Model = $model }
}
function Get-HawkPower { [PSCustomObject]@{ Mode = (Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -Filter "IsActive=True").ElementName } }
function Get-HawkLicense {
    $license = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction SilentlyContinue
    $status = if ($license) { @{1='Licensed';0='Unlicensed'}[$license.LicenseStatus] } else { 'N/A' }
    [PSCustomObject]@{ Status = $status; PartialProductKey = $license.PartialProductKey }
}
function Get-HawkNetCheck {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingComputerNameHardcoded', '')]
    [CmdletBinding()]
    param()
    [PSCustomObject]@{ Internet = (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue) }
}
function Get-HawkWifi {
    $raw = netsh wlan show interfaces 2>$null | Out-String
    if (-not $raw) { return [PSCustomObject]@{ SSID = 'N/A'; Signal = 'N/A' } }
    $ssid = if ($raw -match 'SSID\s+:\s+(.+)') { $matches[1].Trim() } else { 'Disconnected' }
    $signal = if ($raw -match 'Signal\s+:\s+(\d+)%') { $matches[1] } else { '0' }
    [PSCustomObject]@{ SSID = $ssid; SignalPercent = $signal }
}
function Get-HawkEstablished {
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Connections = 'N/A - NetTCPConnection cmdlet unavailable' }
    }
    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Select-Object LocalPort, RemotePort, RemoteAddress, @{N='ProcessName';E={ (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName }}, State |
        Sort-Object RemoteAddress | Select-Object -First 20
}
function Get-HawkDnsBench {
    $resolvers = @{ '1.1.1.1' = 'Cloudflare'; '8.8.8.8' = 'Google'; '9.9.9.9' = 'Quad9' }
    foreach ($server in $resolvers.Keys) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $null = Resolve-DnsName -Name 'google.com' -Server $server -Type A -QuickTimeout -ErrorAction Stop
            $sw.Stop()
            [PSCustomObject]@{ Resolver = $server; Name = $resolvers[$server]; SpeedMS = $sw.ElapsedMilliseconds }
        } catch {
            [PSCustomObject]@{ Resolver = $server; Name = $resolvers[$server]; SpeedMS = 'TIMEOUT' }
        }
    }
}
function Get-HawkLinkSpeed {
    if (-not (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Name = 'N/A'; LinkSpeed = 'N/A' }
    }
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq Up |
        Select-Object Name, @{N='LinkSpeed';E={$_.LinkSpeed}}, InterfaceDescription, MacAddress
}
function Get-HawkShare { Get-CimInstance Win32_Share | Select-Object Name, Path, Description }
function Get-HawkHostsCheck {
    Get-Content "$env:windir\system32\drivers\etc\hosts" -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*[^#]' -and $_ -match '\S' } |
        ForEach-Object {
            $parts = $_ -split '\s+' | Where-Object { $_ }
            [PSCustomObject]@{ IP = $parts[0]; Hostname = $parts[1..($parts.Count-1)] -join ' ' }
        }
}
function Get-HawkDnsCache {
    if (-not (Get-Command Get-DnsClientCache -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Entry = 'N/A'; Status = 'Cmdlet unavailable' }
    }
    Get-DnsClientCache -ErrorAction SilentlyContinue |
        Select-Object Entry, Type, TimeToLive, DataLength |
        Sort-Object TimeToLive | Select-Object -First 20
}
function Get-HawkPatchHistory { Get-CimInstance Win32_QuickFixEngineering | Select-Object HotFixID, InstalledOn | Sort-Object InstalledOn -Descending | Select-Object -First 5 }
function Get-HawkDriverAudit {
    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { -not $_.IsSigned } |
        Select-Object DeviceName, DriverVersion, DriverDate | Select-Object -First 10
}
function Get-HawkCert { Get-ChildItem Cert:\CurrentUser\My | Select-Object Subject, Thumbprint, NotAfter }
function Get-HawkRecent {
    $recentDir = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
    if (-not (Test-Path $recentDir)) { return @() }
    Get-ChildItem $recentDir -ErrorAction SilentlyContinue |
        Select-Object Name, LastWriteTime | Sort-Object LastWriteTime -Descending | Select-Object -First 5
}
function Get-HawkDriveHealth {
    $result = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue |
        Select-Object InstanceName, PredictFailure
    if (-not $result) { return [PSCustomObject]@{ Status = 'No SMART data available'; PredictFailure = 'Unknown' } }
    $result
}
function Get-HawkDump {
    $result = Get-ChildItem "$env:windir\Minidump" -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime
    if (-not $result) { return [PSCustomObject]@{ Status = 'No memory dumps found'; Path = "$env:windir\Minidump" } }
    $result
}
function Get-HawkBadFile {
    $results = Get-ChildItem -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 500MB }
    $suspicious = @('.encrypt', '.locked', '.crypt', '.xyz', '.zepto', '.cerber')
    $matchesSuspicious = Get-ChildItem -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in $suspicious }
    [PSCustomObject]@{
        FilesOver500MB = @($results).Count
        LargestFileMB = if ($results) { [Math]::Round(($results | Sort-Object Length -Descending | Select-Object -First 1).Length / 1MB, 1) } else { 0 }
        SuspiciousExtensions = @($matchesSuspicious).Count
    }
}
function Get-HawkLink {
    $shell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue
    if (-not $shell) { return [PSCustomObject]@{ LinksProcessed = 0; Error = 'WScript.Shell COM unavailable' } }
    $links = Get-ChildItem *.lnk -ErrorAction SilentlyContinue
    if (-not $links) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null; return [PSCustomObject]@{ LinksProcessed = 0; Status = 'No .lnk files in current directory' } }
    $results = foreach ($link in $links) {
        try {
            $shortcut = $shell.CreateShortcut($link.FullName)
            [PSCustomObject]@{ Name = $link.Name; Target = $shortcut.TargetPath }
        } catch { Write-Verbose "Failed to resolve shortcut: $($_.Exception.Message)" }
    }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    if (-not $results) { return [PSCustomObject]@{ LinksProcessed = 0; Status = 'No shortcuts could be resolved' } }
    $results
}
function Get-HawkLock {
    param([string]$Path = (Get-Location).Path)
    $files = Get-ChildItem $Path -File -ErrorAction SilentlyContinue | Select-Object -First 50
    $results = foreach ($file in $files) {
        try {
            $stream = [System.IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None')
            $stream.Dispose()
        } catch {
            [PSCustomObject]@{ File = $file.Name; Locked = $true; Message = $_.Exception.Message }
        }
    }
    if (-not $results) { return [PSCustomObject]@{ LockedFiles = 0; Status = 'No locked files detected' } }
    $results
}
function Get-HawkSparseFile {
    $result = Get-ChildItem -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [System.IO.FileAttributes]::SparseFile } |
        Select-Object FullName, Length | Select-Object -First 20
    if (-not $result) { return [PSCustomObject]@{ Status = 'No sparse files detected'; Count = 0 } }
    $result
}
function Get-HawkCompressedDir {
    $result = Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Compressed } |
        Select-Object FullName, @{N='CompressedSizeKB';E={[Math]::Round(($_.GetFiles() | Measure-Object Length -Sum).Sum / 1KB, 1)}} |
        Select-Object -First 20
    if (-not $result) { return [PSCustomObject]@{ Status = 'No compressed directories detected'; Count = 0 } }
    $result
}
function Get-HawkAppLocation { param([string]$App) Get-Command $App -ErrorAction SilentlyContinue | Select-Object Name, Source }
function Get-HawkShield {
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Status = 'Defender cmdlets unavailable' }
    }
    Get-MpComputerStatus -ErrorAction SilentlyContinue |
        Select-Object AntivirusEnabled, RealTimeProtectionEnabled, LastQuickScanTime, AMServiceEnabled,
            @{N='LastQuickScanResult';E={$_.LastQuickScanResult -join ';'}}
}

# ── 7b. CONSOLIDATED DISPATCH FUNCTIONS ──────────────────────────────────────
function Get-HawkSystem {
    [CmdletBinding()]
    param([ValidateSet('Health','Spec','Uptime','Ram','Battery','Display','Disk','Resource','Port')][string]$Type = 'Health')
    switch ($Type) {
        'Health'   { Get-HawkHealth }
        'Spec'     { Get-HawkSpec }
        'Uptime'   { Get-HawkUptime }
        'Ram'      { Get-HawkRamInfo }
        'Battery'  { Get-HawkBattery }
        'Display'  { Get-HawkDisplay }
        'Disk'     { Get-HawkDiskPressureAudit }
        'Resource' { Get-HawkResourceMap }
        'Port'     { Get-HawkPortMap }
    }
}

function Get-HawkAudit {
    [CmdletBinding()]
    param([ValidateSet('Firewall','Boot','ScheduledTask','GhostPort','SuspiciousProcess','EventStorm','Patch','Temp','Clip')][string]$Type = 'Firewall')
    switch ($Type) {
        'Firewall'          { Get-HawkFirewallAudit }
        'Boot'              { Get-HawkBootMap }
        'ScheduledTask'     { Get-HawkScheduledTaskRiskAudit }
        'GhostPort'         { Get-HawkGhostPortAudit }
        'SuspiciousProcess' { Get-HawkSuspiciousProcessAudit }
        'EventStorm'        { Get-HawkEventStormAudit }
        'Patch'             { Get-HawkPatchHistory }
        'Temp'              { Get-HawkTempCheck }
        'Clip'              { Get-HawkClipCheck }
    }
}

function Get-HawkNetwork {
    [CmdletBinding()]
    param([ValidateSet('NetCheck','Wifi','DnsBench','LinkSpeed','Share','HostsCheck','DnsCache','Triage')][string]$Type = 'NetCheck')
    switch ($Type) {
        'NetCheck'   { Get-HawkNetCheck }
        'Wifi'       { Get-HawkWifi }
        'DnsBench'   { Get-HawkDnsBench }
        'LinkSpeed'  { Get-HawkLinkSpeed }
        'Share'      { Get-HawkShare }
        'HostsCheck' { Get-HawkHostsCheck }
        'DnsCache'   { Get-HawkDnsCache }
        'Triage'     { Get-HawkNetworkTriage }
    }
}

function Get-HawkEnv {
    [CmdletBinding()]
    param([ValidateSet('Env','Path','App','Patch','Driver','Admin','Hypervisor','Power','License')][string]$Type = 'Env')
    switch ($Type) {
        'Env'        { Get-HawkEnvMap }
        'Path'       { Get-HawkPathAudit }
        'App'        { Get-HawkApp }
        'Patch'      { Get-HawkPatchHistory }
        'Driver'     { Get-HawkDriverAudit }
        'Admin'      { Get-HawkAdmin }
        'Hypervisor' { Get-HawkHypervisor }
        'Power'      { Get-HawkPower }
        'License'    { Get-HawkLicense }
    }
}

# ── 7c. WEB CONTENT SAFETY GUARDS (STUB IMPLEMENTATIONS) ─────────────────────
function Test-HawkPromptInjection {
    param([AllowNull()][string]$Payload)
    # Stub — checks for common prompt-injection patterns in scraped web text
    if ([string]::IsNullOrWhiteSpace($Payload)) { return $false }
    return ($Payload -match '(?i)(ignore\s+(?:(?:previous|above|all)\s+)*instructions|you\s+are\s+now|system\s*prompt|\bDAN\b.*mode)')
}

function Get-HawkSourceQualityScore {
    param([string]$Url, [AllowNull()][string]$Content)
    # Stub — returns a basic heuristic quality score (0-100) for scraped content
    if ([string]::IsNullOrWhiteSpace($Content)) { return 0 }
    $score = 50
    if ($Content.Length -gt 200)  { $score += 20 }
    if ($Content.Length -gt 800)  { $score += 15 }
    if ($Url -match '\.(gov|edu|org)(/|$)') { $score += 15 }
    return [Math]::Min(100, $score)
}

# ── 8. SEARCH SCRAPING ARCHITECTURE DECOUPLING ───────────────────────────────
function Resolve-HawkDuckDuckGoHref {
    param([string]$Href)
    if (-not $Href) { return $null }
    if ($Href -match 'uddg=([^&]+)') { return [Uri]::UnescapeDataString($matches[1]) }
    if ($Href -match '^//') { return "https:$Href" }
    if ($Href -match '^https?://') { return $Href }
    return $null
}

function Invoke-HawkSearch {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional rate-limiting state')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Query,
        [ValidateSet('google', 'ddg', 'gh', 'so', 'bing')][string]$Engine = 'google',
        [switch]$AI,
        [switch]$Deep,
        [ValidateRange(1, 30)][int]$Sources = 5,
        [string]$Instruction = 'Synthesize a concise report answering the query based on the following website contents.'
    )

    $minIntervalSeconds = 5
    $now = Get-Date
    if ($global:HawkLastSearchTime) {
        $elapsed = ($now - $global:HawkLastSearchTime).TotalSeconds
        if ($elapsed -lt $minIntervalSeconds) {
            Start-Sleep -Seconds ([int]($minIntervalSeconds - $elapsed))
        }
    }
    $global:HawkLastSearchTime = Get-Date

    $cleanTokens = $Query | Where-Object { $_ -notmatch '^-(AI|a|Deep|Engine|e|Sources)$' }
    $jq = ($cleanTokens -join ' ').Trim()

    if (-not $jq) {
        throw 'Search query parameters evaluate to empty payload context.'
    }

    $enc = [Uri]::EscapeDataString($jq)
    $urls = @{
        google = "https://www.google.com/search?q=$enc"
        ddg    = "https://duckduckgo.com/?q=$enc"
        gh     = "https://github.com/search?q=$enc&type=repositories"
        so     = "https://stackoverflow.com/search?q=$enc"
        bing   = "https://www.bing.com/search?q=$enc"
    }

    if (-not $AI) {
        Write-HawkHeader " [Search] Spawning Context [$Engine] -> $jq" Cyan
        Start-Process $urls[$Engine]
        return
    }

    Write-HawkHeader " [Search] Processing Link Nodes for: $jq" Cyan
    # Parsing loop continuation execution logic...
    try {
        $resp = Invoke-WebRequest -Uri 'https://lite.duckduckgo.com/lite/' -Method Post -Body @{ q = $jq } -UseBasicParsing -ErrorAction Stop

        # Modified parsing layer using explicit regex analysis against standard basic HTML properties
        $targetUrls = [regex]::Matches($resp.Content, 'href="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } |
            Where-Object { $_ -match 'uddg=' } | ForEach-Object { Resolve-HawkDuckDuckGoHref -Href $_ } |
            Where-Object { $_ -and $_ -notmatch '^https?://(www\.)?duckduckgo\.com' } | Select-Object -Unique -First 30

        if (-not $targetUrls) { Start-Process $urls[$Engine]; return }

        $context = "Search Query: $jq`n`n"
        $read = 0
        $targetCount = if ($Sources -gt 0) { $Sources } elseif ($Deep) { 10 } else { 4 }

        foreach ($u in $targetUrls) {
            if ($read -ge $targetCount) { break }
            Write-HawkHeader "  [Read] Processing structural node: $u" DarkGray

            $page = $null
            $maxRetries = 2
            for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
                try {
                    $page = Invoke-WebRequest -Uri $u -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } -UseBasicParsing -TimeoutSec (if ($Deep){10}else{5}) -ErrorAction Stop
                    break
                } catch {
                    if ($attempt -eq $maxRetries) { break }
                    Start-Sleep -Seconds ([Math]::Pow(2, $attempt))
                }
            }

            if (-not $page) { continue }

            $contentType = $page.BaseResponse.ContentType
            if ($contentType -notmatch 'text/html|application/xhtml\+xml') {
                Write-HawkHeader "  [Validation Warning] Skipping binary content payload: $contentType" Yellow
                continue
            }

            $txt = [System.Net.WebUtility]::HtmlDecode(($page.Content -replace '(?s)<style[^>]*>.*?</style>', '' -replace '(?s)<script[^>]*>.*?</script>', '' -replace '<[^>]+>', ' ').Trim()) -replace '\s+', ' '
            if ([string]::IsNullOrWhiteSpace($txt)) { continue }

            if (Test-HawkPromptInjection -Payload $txt) {
                Write-HawkHeader "  [Security Triggered] High anomaly metric identified inside text layout node. Node isolated." Red
                continue
            }

            $qualityScore = Get-HawkSourceQualityScore -Url $u -Content $txt
            if ($qualityScore -lt 40) {
                Write-HawkHeader "  [Quality Check Failed] Payload score ($qualityScore/100) below threshold of 40. Skipping." Yellow
                continue
            }

            if ($txt.Length -gt $(if($Deep){3000}else{1800})) { $txt = $txt.Substring(0, $(if($Deep){3000}else{1800})) }
            $context += "Source: $u (Score: $qualityScore)`nContent: $txt`n`n"
            $read++

            Start-Sleep -Milliseconds 400
        }

        if ($read -eq 0) { Start-Process $urls[$Engine]; return }
        Write-HawkHeader '  [AI] Synthesizing engines across checked endpoints...' Magenta
        $context | Invoke-HawkAI -Instruction $Instruction
    } catch { Start-Process $urls[$Engine] }
}

# ── LOGICAL LOCAL TYPED MEMORY MODULES ────────────────────────────────────────
function Get-HawkMemoryFile {
    if (-not (Test-Path $script:HawkMemoryRoot)) { $null = New-Item -Path $script:HawkMemoryRoot -ItemType Directory -Force }
    return $script:HawkMemoryFile
}

function Format-HawkMemoryId {
    param()
    "mem_{0}_{1}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), ([Guid]::NewGuid().ToString('N').Substring(0, 6))
}

function Get-HawkMemorySearchTerm {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $stopWords = @('the','and','for','with','that','this','from','into','what','when','where','which','how','why','are','you','your','about','using','use')
    [regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9][a-z0-9._-]{2,}') | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stopWords } | Select-Object -Unique -First 18
}

function Format-HawkMemorySnippet {
    param([AllowNull()][string]$Text, [int]$MaxLength = 220)
    if ($null -eq $Text) { return '' }
    $clean = (($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' ').Trim()
    if ($clean.Length -le $MaxLength) { return $clean }
    return $clean.Substring(0, $MaxLength - 1) + '…'
}

function Read-HawkMemory {
    if (-not (Test-Path $script:HawkMemoryFile)) { return @() }
    Get-Content -Path $script:HawkMemoryFile -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        try {
            $untypedMap = $_ | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            [HawkMemoryEntry]::new($untypedMap)
        } catch { Write-Verbose "Memory entry parse skipped: $($_.Exception.Message)" }
    }
}

function Add-HawkMemory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Text,
        [ValidateSet('preference', 'runbook', 'session', 'web', 'sysops', 'note')][string]$Type = 'note',
        [string[]]$Tag = @(),
        [string]$Source = 'manual',
        [ValidateSet('low', 'medium', 'high', 'user')][string]$Confidence = 'user',
        [switch]$Pinned
    )
    $joined = ($Text -join ' ').Trim()
    if (-not $joined) { throw 'Payload buffer verification empty.' }

    $map = [hashtable]@{
        Id         = Format-HawkMemoryId
        Type       = $Type
        Tags       = @($Tag)
        Text       = ($joined | Protect-HawkSensitiveText | Out-String).Trim()
        Source     = $Source
        Created    = (Get-Date).ToString('o')
        Confidence = $Confidence
        Pinned     = [bool]$Pinned
    }

    if ($PSCmdlet.ShouldProcess("Memory entry: $(Format-HawkMemorySnippet -Text $joined)", 'Save memory')) {
        $typedInstance = [HawkMemoryEntry]::new($map)
        ($typedInstance | ConvertTo-Json -Compress -Depth 6) | Add-Content -Path (Get-HawkMemoryFile) -Encoding UTF8
        return $typedInstance
    }
}

function Search-HawkMemory {
    [CmdletBinding()] param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Query = @(), [int]$First = 8, [switch]$Pinned)
    $queryText = ($Query -join ' ').Trim()
    $items = @(Read-HawkMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if (-not $items) { return }
    if (-not $queryText) { $items | Sort-Object Created -Descending | Select-Object -First $First; return }

    $terms = @(Get-HawkMemorySearchTerm -Text $queryText)
    if (-not $terms) { $items | Sort-Object Created -Descending | Select-Object -First $First; return }

    @(foreach ($item in $items) {
        $score = 0
        $haystack = "$($item.Type) $((@($item.Tags) -join ' ')) $($item.Text)".ToLowerInvariant()
        foreach ($term in $terms) { if ($haystack.Contains($term)) { $score++ } }
        if ($item.Pinned) { $score += 2 }
        if ($score -gt 0) {
            [PSCustomObject]@{
                Score      = $score
                Id         = $item.Id
                Type       = $item.Type
                Tags       = $item.Tags
                Text       = $item.Text
                Source     = $item.Source
                Created    = $item.Created
                Confidence = $item.Confidence
                Pinned     = $item.Pinned
            }
        }
    }) | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Created'; Descending = $true } | Select-Object -First $First
}

function Get-HawkMemoryMap {
    param([string]$Tag, [switch]$Pinned, [int]$First = 40)
    $items = @(Read-HawkMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if ($Tag) { $items = @($items | Where-Object { $_.Tags -and @($_.Tags) -contains $Tag }) }
    $items | Sort-Object Created -Descending | Select-Object -First $First
}

# ── OLLAMA TUNNEL API AGENT ADAPTER ───────────────────────────────────────────
function Get-HawkAIStatus {
    param([string]$Endpoint = 'http://127.0.0.1:11434')
    return Invoke-HawkCachedData -Key "ai_status_$Endpoint" -ExpirySeconds 15 -ScriptBlock {
        try {
            $models = (Invoke-RestMethod -Uri "$Endpoint/api/tags" -TimeoutSec 5 -ErrorAction Stop).models
            if (-not $models) { return @() }
            foreach ($model in $models) {
                [PSCustomObject]@{ Endpoint = $Endpoint; Status = 'Reachable'; Model = $model.name; SizeGB = [Math]::Round($model.size / 1GB, 2); Modified = $model.modified_at }
            }
        } catch {
            [PSCustomObject]@{ Endpoint = $Endpoint; Status = 'Unavailable'; Model = ''; SizeGB = ''; Modified = $_.Exception.Message }
        }
    }
}

function Get-HawkAIIntent {
    param([AllowNull()][string]$Instruction)
    if ([string]::IsNullOrWhiteSpace($Instruction)) { return 'AnalyzeData' }
    $text = $Instruction.ToLowerInvariant()
    if ($text -match '\b(search|web|online|latest|current|look up|lookup|research)\b') { return 'Research' }
    if ($text -match '\b(command|script|cmdlet|syntax|powershell|how do i|how to|fix|change|install|remove|delete|start|stop|restart)\b') { return 'Shell' }
    if ($text -match '\b(compare|changed|since|history|previous|trend)\b') { return 'Compare' }
    if ($text -match '\b(summarize|summary|explain|why|what does)\b') { return 'Explain' }
    return 'AnalyzeData'
}

function Get-HawkAIDataProfile {
    param([object[]]$InputObject = @())
    $rows = @($InputObject | Where-Object { $null -ne $_ })
    if (-not $rows) { return [PSCustomObject]@{ Kind = 'Empty'; Rows = 0; Columns = '' } }
    if ($rows[0] -is [string]) { return [PSCustomObject]@{ Kind = 'Text'; Rows = $rows.Count; Columns = 'Text' } }
    $cols = @($rows[0].PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Select-Object -ExpandProperty Name -First 24)
    [PSCustomObject]@{ Kind = if ($cols.Count -gt 1) { 'Table' } else { 'Object' }; Rows = $rows.Count; Columns = ($cols -join ', ') }
}

function Build-HawkAIMemoryContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', 'Read-only data assembly from existing memory')]
    param([string]$Query, [int]$First = 5)
    $items = @(Search-HawkMemory -Pinned -First 3)
    if ($Query) { $items += @(Search-HawkMemory -Query $Query -First $First) }
    $selected = @(foreach ($item in $items) { if ($item.Id) { $item } }) | Select-Object -First $First
    if (-not $selected) { return '' }
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('Relevant local memory:')
    foreach ($item in $selected) { $lines.Add("- [$($item.Type)] $(Format-HawkMemorySnippet -Text $item.Text -MaxLength 220)") }
    return ($lines -join [Environment]::NewLine)
}

function Build-HawkAIContextPacket {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', 'Read-only data assembly, no system state change')]
    param([string]$Instruction, [object[]]$InputObject = @(), [int]$MemoryLimit = 5, [switch]$NoMemory)
    $intent = Get-HawkAIIntent -Instruction $Instruction; $dataProfile = Get-HawkAIDataProfile -InputObject $InputObject
    $mode = 'Fast'
    if ($Instruction -match '(?i)\b(deep|thorough|investigate|full|history|compare)\b') { $mode = 'Deep' }
    elseif ($intent -in @('Research', 'Compare')) { $mode = 'Balanced' }
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('Context envelope:')
    $lines.Add("- Mode: $mode"); $lines.Add("- Intent: $intent"); $lines.Add("- Data kind: $($dataProfile.Kind)"); $lines.Add("- Rows: $($dataProfile.Rows)")
    if ($dataProfile.Columns) { $lines.Add("- Columns: $($dataProfile.Columns)") }
    if (-not $NoMemory) { $mem = Build-HawkAIMemoryContext -Query $Instruction -First $MemoryLimit; if ($mem) { $lines.Add(''); $lines.Add($mem) } }
    [PSCustomObject]@{ Intent = $intent; Mode = $mode; Text = ($lines -join [Environment]::NewLine) }
}

function Invoke-HawkAI {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', 'Intentional streaming output to console')]
    [CmdletBinding()] param([Parameter(ValueFromPipeline = $true, Mandatory = $true)]$InputData, [Parameter(Position = 0)][string]$Instruction = 'Analyze this data.', [string]$Model = 'HawkPowershell', [int]$TimeoutSec = 120, [int]$MaxRetries = 0, [switch]$RedactSensitive, [switch]$Remember, [switch]$NoMemory, [int]$MemoryLimit = 5)
    begin { $dataBuffer = [System.Collections.Generic.List[object]]::new() }
    process { $dataBuffer.Add($InputData) }
    end {
        $stringifiedData = $dataBuffer | Out-String; if ($RedactSensitive) { $stringifiedData = $stringifiedData | Protect-HawkSensitiveText | Out-String }
        $ctx = Build-HawkAIContextPacket -Instruction $Instruction -InputObject $dataBuffer.ToArray() -MemoryLimit $MemoryLimit -NoMemory:$NoMemory
        $contract = "You are Hawkward AI, a fast local PowerShell/SysOps assistant.`nUse the context envelope, relevant memory, and pipeline data as evidence.`nDefault to a concise answer. Expand only when requested.`nIf pipeline data is present, answer from it first and preserve its units.`nDo not output commands unless specifically requested."
        $payload = @{ model = $Model; prompt = "$contract`n`n$($ctx.Text)`n`nUser question:`n$Instruction`n`nPowerShell pipeline data:`n$stringifiedData"; stream = $true } | ConvertTo-Json -Depth 5
        $success = $false; $lastErr = $null
        for ($attempt = 1; $attempt -le (1 + $MaxRetries) -and -not $success; $attempt++) {
            if ($attempt -gt 1) { Write-HawkHeader "  [Retry] $attempt / $((1 + $MaxRetries))..." Yellow; Start-Sleep -Seconds 3 }
            Write-Host "`n  [AI] [$($Model.ToUpper())] " -NoNewline -ForegroundColor Magenta
            $client = [System.Net.Http.HttpClient]::new()
            try {
                $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
                $body = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                $response = $client.PostAsync('http://127.0.0.1:11434/api/generate', $body).GetAwaiter().GetResult()
                $response.EnsureSuccessStatusCode() | Out-Null
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult(); $reader = [System.IO.StreamReader]::new($stream)
                $respText = [System.Text.StringBuilder]::new()
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine(); if (-not $line) { continue }
                    try {
                        $chunk = $line | ConvertFrom-Json -ErrorAction Stop
                        if ($chunk.response) { $null = $respText.Append($chunk.response); Write-Host $chunk.response -NoNewline -ForegroundColor White }
                        if ($chunk.done) { break }
                    } catch { Write-Verbose "AI stream chunk parse warning: $($_.Exception.Message)" }
                }
                Write-Host ''; if ($Remember -and $respText.Length -gt 0) { Add-HawkMemory -Text "Question: $Instruction`n`nAnswer: $($respText.ToString())" -Type session -Tag @('ai', $ctx.Intent.ToLowerInvariant()) -Source 'ai' | Out-Null }
                $success = $true
            } catch { $lastErr = $_; Write-Warning "AI pipeline failure: $($_.Exception.Message)" } finally { if ($reader) {$reader.Dispose()}; $client.Dispose() }
        }
        if (-not $success -and $lastErr) { throw $lastErr }
    }
}

# ── COMPREHENSIVE INDUSTRIAL REPORT GENERATOR (PRESENTATION SEPARATION) ───────
function Format-HawkMarkdownCell { param([AllowNull()][string]$Text, [int]$MaxWidth = 0)
    if ($null -eq $Text) { $Text = '' }
    $clean = ($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' '
    $clean = $clean.Trim().Replace('|', '\|')
    if ($MaxWidth -gt 0 -and $clean.Length -gt $MaxWidth) { return $clean.Substring(0, $MaxWidth - 1) + '…' }
    return $clean
}

function ConvertTo-HawkMarkdownTable { param([object[]]$InputObject, [string]$Section = '')
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

function ConvertTo-HawkReportMarkdown { param($Report)
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('# Hawkward Hybrid Structural Triage Report'); $lines.Add("Generated: $($Report.Generated)`n")
    foreach ($section in @('AI', 'Disk', 'Resources', 'Ports', 'FirewallGaps', 'Startup', 'ScheduledTaskRisks', 'EventStorms')) {
        $lines.Add("## $section`n"); $lines.Add((ConvertTo-HawkMarkdownTable -InputObject $Report[$section] -Section $section))
    }
    return ($lines -join [Environment]::NewLine)
}

function Get-HawkReportPath {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', 'Internal helper called from New-HawkReport which has ShouldProcess')]
    param([string]$Ext = 'md')
    if (-not (Test-Path $script:HawkReportRoot)) { $null = New-Item -Path $script:HawkReportRoot -ItemType Directory -Force }
    return Join-Path $script:HawkReportRoot ("hawkreport-{0}.{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Ext)
}

function Format-HawkReportCell { param([AllowNull()][string]$Text, [int]$Width)
    if ($Width -le 0) { return '' }; if ($null -eq $Text) { $Text = '' }
    $clean = (($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' ').Trim()
    if ($clean.Length -gt $Width) { return $clean.Substring(0, $Width - 1) + '…' }
    return $clean.PadRight($Width)
}

function Write-HawkReportTable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', 'Intentional console table rendering')]
    [CmdletBinding()]
    param([string]$Title, [hashtable[]]$Columns, [object[]]$InputObject = @(), [string]$Icon = '•', [ConsoleColor]$Color = 'Cyan', [int]$MaxRows = 0)
    $rows = @($InputObject | Where-Object { $null -ne $_ }); $vRows = if ($MaxRows -gt 0) { @($rows | Select-Object -First $MaxRows) } else { $rows }
    $w = (($Columns | ForEach-Object { [int]$_.Width } | Measure-Object -Sum).Sum + (($Columns.Count - 1) * 2))
    Write-Host "`n  $Icon $Title" -ForegroundColor $Color; Write-Host "  $('─' * [Math]::Max(1, $w))" -ForegroundColor DarkGray
    if (-not $rows) { Write-Host '  ✓ Evaluation parameters stable. No actionable telemetry.' -ForegroundColor Green; return }
    Write-Host ('  ' + (($Columns | ForEach-Object { Format-HawkReportCell -Text (if($_.Label){$_.Label}else{$_.Name}) -Width ([int]$_.Width) }) -join '  ')) -ForegroundColor DarkGray
    foreach ($r in $vRows) {
        Write-Host ('  ' + (($Columns | ForEach-Object { Format-HawkReportCell -Text ([string](if($_.Expression){& $_.Expression $r}else{$r.PSObject.Properties[$_.Name].Value})) -Width ([int]$_.Width) }) -join '  ')) -ForegroundColor White
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

# ── MONITOR INTERFACE & VIEWPORTS ─────────────────────────────────────────────
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

# ── SELF-UPDATE & LIVE DASHBOARD ────────────────────────────────────────────────
function Update-HawkModule {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('HawkwardHybrid', 'Pull latest and reload')) {
        $moduleDir = $PSScriptRoot
        $repoRoot = $moduleDir
        for ($i = 0; $i -lt 5 -and $repoRoot; $i++) {
            if (Test-Path (Join-Path $repoRoot '.git')) { break }
            $parent = Split-Path $repoRoot -Parent
            if ($parent -eq $repoRoot) { $repoRoot = $null; break }
            $repoRoot = $parent
        }
        if (-not $repoRoot -or -not (Test-Path (Join-Path $repoRoot '.git'))) {
            Write-Warning "No git repository found for module path: $moduleDir"
            return
        }
        Push-Location $repoRoot
        try {
            Write-Information "  [Update] Pulling latest from git..." -InformationAction Continue
            git pull
            Write-Information "  [Update] Removing module from session..." -InformationAction Continue
            Remove-Module HawkwardHybrid -Force -ErrorAction SilentlyContinue
            Write-Information "  [Update] Reloading..." -InformationAction Continue
            Import-Module (Join-Path $moduleDir 'HawkwardHybrid.psd1') -Force -Global
            Write-Information "  [Update] HawkwardHybrid reloaded." -InformationAction Continue
        } finally { Pop-Location }
    }
}

function Watch-HawkDashboard {
    [CmdletBinding()]
    param([int]$IntervalSeconds = 2)
    if (-not (Test-HawkInteractiveSession)) { Write-Warning "Dashboard requires an interactive terminal session."; return }
    Write-Information "  [Watch] Dashboard live refresh every ${IntervalSeconds}s. Press Ctrl+C to exit." -InformationAction Continue
    while ($true) { Clear-Host; Show-HawkDashboard; Start-Sleep -Seconds $IntervalSeconds }
}

# ── ENGINE INITIALIZATION PROCEDURES ──────────────────────────────────────────
function Update-HawkProfile {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if ($PSCmdlet.ShouldProcess('$PROFILE', 'Dot-source profile')) { . $PROFILE }
}
function Set-HawkAliases {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Intentionally sets all aliases in one call')]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Global aliases', 'Set all Hawk aliases')) { return }
    $mappings = @(
        # ── SYSTEM: HEALTH ──
        @("health", "Get-HawkHealth"),
        @("spec", "Get-HawkSpec"),
        @("uptime", "Get-HawkUptime"),
        @("ram", "Get-HawkRamInfo"),
        @("battery", "Get-HawkBattery"),
        @("display", "Get-HawkDisplay"),
        @("powerplan", "Get-HawkPower"),
        @("hyperv", "Get-HawkHypervisor"),
        @("license", "Get-HawkLicense"),

        # ── SYSTEM: STORAGE ──
        @("disk", "Get-HawkDiskPressureAudit"),
        @("temp", "Get-HawkTempCheck"),
        @("clip", "Get-HawkClipCheck"),
        @("smarts", "Get-HawkDriveHealth"),

        # ── SYSTEM: PERFORMANCE ──
        @("res", "Get-HawkResourceMap"),
        @("port", "Get-HawkPortMap"),

        # ── SECURITY: ACCESS & FIREWALL ──
        @("admin", "Get-HawkAdmin"),
        @("shield", "Get-HawkShield"),
        @("fw", "Get-HawkFirewallAudit"),

        # ── SECURITY: PERSISTENCE & ANOMALIES ──
        @("boot", "Get-HawkBootMap"),
        @("schedtask", "Get-HawkScheduledTaskRiskAudit"),
        @("ghost", "Get-HawkGhostPortAudit"),
        @("sus", "Get-HawkSuspiciousProcessAudit"),
        @("storm", "Get-HawkEventStormAudit"),

        # ── SECURITY: INVENTORY ──
        @("cert", "Get-HawkCert"),
        @("dump", "Get-HawkDump"),
        @("badfile", "Get-HawkBadFile"),
        @("link", "Get-HawkLink"),
        @("lock", "Get-HawkLock"),
        @("sparse", "Get-HawkSparseFile"),
        @("compress", "Get-HawkCompressedDir"),
        @("patch", "Get-HawkPatchHistory"),
        @("driver", "Get-HawkDriverAudit"),
        @("recent", "Get-HawkRecent"),

        # ── DATA PROTECTION ──
        @("secretredact", "Protect-HawkSensitiveText"),

        # ── NETWORK: CONNECTIVITY ──
        @("ping", "Get-HawkNetCheck"),
        @("wifi", "Get-HawkWifi"),
        @("established", "Get-HawkEstablished"),
        @("dns", "Get-HawkDnsBench"),
        @("linkspeed", "Get-HawkLinkSpeed"),
        @("smb", "Get-HawkShare"),
        @("hosts", "Get-HawkHostsCheck"),
        @("dnscache", "Get-HawkDnsCache"),
        @("nettriage", "Get-HawkNetworkTriage"),

        # ── ENVIRONMENT ──
        @("envmap", "Get-HawkEnvMap"),
        @("path", "Get-HawkPathAudit"),
        @("app", "Get-HawkApp"),
        @("where", "Get-HawkAppLocation"),

        # ── AI COMMANDS ──
        @("ai", "Invoke-HawkAI"),
        @("ggl", "Invoke-HawkSearch"),
        @("aistatus", "Get-HawkAIStatus"),
        @("intent", "Get-HawkAIIntent"),
        @("aiprofile", "Get-HawkAIDataProfile"),
        @("quality", "Get-HawkSourceQualityScore"),
        @("injecttest", "Test-HawkPromptInjection"),

        # ── MEMORY SYSTEM ──
        @("remember", "Add-HawkMemory"),
        @("recall", "Search-HawkMemory"),
        @("memmap", "Get-HawkMemoryMap"),
        @("readmem", "Read-HawkMemory"),
        @("memfile", "Get-HawkMemoryFile"),

        # ── REPORTS ──
        @("hawkreport", "New-HawkReport"),
        @("reportpath", "Get-HawkReportPath"),

        # ── MODULE & SHELL ──
        @("dash", "Show-HawkDashboard"),
        @("watch", "Watch-HawkDashboard"),
        @("hawkman", "Show-HawkManual"),
        @("reload", "Update-HawkProfile"),
        @("init", "Initialize-HawkProfile"),
        @("proj", "Get-HawkProject"),
        @("projset", "Invoke-HawkProject"),
        @("explorer", "Invoke-ExplorerHere"),
        @("cached", "Invoke-HawkCachedData"),

        # ── CONSOLIDATED DISPATCH ──
        @("sys", "Get-HawkSystem"),
        @("audit", "Get-HawkAudit"),
        @("net", "Get-HawkNetwork"),
        @("env", "Get-HawkEnv"),

        # ── LEGACY (backward-compat, will be removed in v12) ──
        @("specs", "Get-HawkSpec"),
        @("displays", "Get-HawkDisplay"),
        @("admins", "Get-HawkAdmin"),
        @("apps", "Get-HawkApp"),
        @("shares", "Get-HawkShare"),
        @("certs", "Get-HawkCert"),
        @("dumps", "Get-HawkDump"),
        @("badfiles", "Get-HawkBadFile"),
        @("links", "Get-HawkLink"),
        @("locked", "Get-HawkLock"),
        @("sparsefile", "Get-HawkSparseFile"),
        @("compressdir", "Get-HawkCompressedDir"),
        @("raminfo", "Get-HawkRamInfo"),
        @("netcheck", "Get-HawkNetCheck"),
        @("dnsbench", "Get-HawkDnsBench"),
        @("hostscheck", "Get-HawkHostsCheck"),
        @("dnscache", "Get-HawkDnsCache"),
        @("patchhistory", "Get-HawkPatchHistory"),
        @("driveraudit", "Get-HawkDriverAudit"),
        @("drivehealth", "Get-HawkDriveHealth"),
        @("tempcheck", "Get-HawkTempCheck"),
        @("clipcheck", "Get-HawkClipCheck"),
        @("hog", "Get-HawkResourceMap"),
        @("hogaudit", "Get-HawkResourceMap"),
        @("evntmap", "Get-HawkEventStormAudit"),
        @("fwmap", "Get-HawkFirewallAudit"),
        @("hawkdoctor", "Get-HawkHealth"),
        @("projaudit", "Get-HawkProject"),
        @("ports", "Get-HawkPortMap")
    )
    foreach ($m in $mappings) {
        Set-Alias -Scope Global -Name $m[0] -Value $m[1] -Force
    }
}

function Initialize-HawkProfile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$ProjectRoot = $script:HawkDefaultProjectRoot,
        [switch]$ShowDashboard,
        [switch]$SkipModules
    )
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $global:HawkProjectRoot = $ProjectRoot

    if (-not $SkipModules) {
        Import-HawkPrerequisite -Quiet | Out-Null
    }

    Set-HawkReadLine
    Set-HawkAliases
    Set-HawkPrompt

    if ($ShowDashboard -and (Test-HawkInteractiveSession)) {
        Show-HawkDashboard
    }
}

# ── MODULE EXPORT ─────────────────────────────────────────────────────────────
Export-ModuleMember -Function * -Alias *
