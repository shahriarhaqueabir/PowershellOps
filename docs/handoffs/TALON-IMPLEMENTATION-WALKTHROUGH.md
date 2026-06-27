# Talon v1 — Phase-by-Phase Implementation Walkthrough

> **Agent:** Zed (Big Pickle LM)  
> **Runtime:** PowerShell 7 (Windows)  
> **Project root:** `E:\Projects\projectx\powershellOps`  
> **Target location:** `E:\Projects\projectx\powershellOps\Talon\`  
> **Status:** Ready to implement  
> **Total estimate:** ~6 days

---

## How to Use This Document

Each phase is a self-contained implementation block. Within each phase, steps are ordered sequentially — later steps depend on earlier ones. After completing a phase, verify the exit criteria before moving to the next.

**Conventions:**
- `📝` = Write/edit a file
- `▶️` = Run a terminal command
- `🔍` = Verify output matches expected
- `⚠️` = Watch out for this gotcha

---

## Phase 0 — Skeleton (Day 1)

**Goal:** Create the module scaffold, three-tier loading architecture, thin profile loader, and configuration system. By the end of this phase, a user who installs Talon sees a prompt change and can run `dash`.

### Step 0.1 — Create Target Directory Structure

```powershell
# Create the Talon module directory
📝 mkdir "$env:USERPROFILE\Documents\PowerShell\Talon" -Force
📝 mkdir "$env:USERPROFILE\Documents\PowerShell\Talon\AI" -Force
📝 mkdir "$env:USERPROFILE\Documents\PowerShell\Talon\Scripts" -Force
```

### Step 0.2 — Write the Module Manifest (Talon.psd1)

This is the root manifest that allows PowerShell to find and auto-import the module.

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.psd1"

@{
    RootModule        = 'Talon.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Copyright         = '(c) 2026 Talon Contributors. MIT License.'
    Description       = 'Talon — featherweight PowerShell 7 ops shell with 50 diagnostic + AI commands.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        # Tier 0 — Shell Core
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
```

**⚠️ Gotcha:** `FunctionsToExport` in the *root* manifest only lists Tier 0. Tiers 1 and 2 use *nested modules*.

### Step 0.3 — Write Tier 0 Shell Core (Talon.psm1)

This is the heart of Talon. It must load under 200ms. Every other module is loaded lazily.

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.psm1"

# ── Talon v1 — Shell Core (Tier 0) ──────────────────────────────────────────
# Loads on every session. Must complete in <200ms.
# Everything else — commands, AI — is lazy-loaded via nested modules.

# Script-scoped state (not global)
$script:TalonVersion = '1.0.0'
$script:TalonConfigPath = Join-Path $HOME '.talon' 'config.json'
$script:TalonCacheStore = [hashtable]::Synchronized(@{})
$script:TalonSuppressHeaders = $false
$script:TalonDefaultProjectRoot = if ($env:TALON_PROJECT_ROOT) { $env:TALON_PROJECT_ROOT } else { "$HOME\Projects" }
$script:TalonConfig = $null

# ── CONFIGURATION ────────────────────────────────────────────────────────────

function Get-TalonConfig {
    <#
    .SYNOPSIS
        Load Talon configuration from ~\.talon\config.json with env var overrides.
    #>
    if ($script:TalonConfig) { return $script:TalonConfig }
    $configPath = $script:TalonConfigPath
    $defaults = @{
        version              = '1'
        theme                = 'auto'
        dashboardEnabled     = $true
        dashboardDismissSec  = 2
        ollama = @{
            endpoint    = 'http://127.0.0.1:11434'
            model       = 'talon-default'
            contextSize = 8192
            timeoutSec  = 120
        }
        modules = @{
            system   = $true
            security = $true
            network  = $true
            ai       = $true
        }
        gitPromptCacheMs     = 2000
        suppressBranding     = $false
    }

    if (Test-Path $configPath) {
        try {
            $userConfig = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            # Deep-merge user config into defaults (simple approach)
            foreach ($key in $userConfig.Keys) {
                if ($userConfig[$key] -is [hashtable] -and $defaults.ContainsKey($key) -and $defaults[$key] -is [hashtable]) {
                    foreach ($subKey in $userConfig[$key].Keys) {
                        $defaults[$key][$subKey] = $userConfig[$key][$subKey]
                    }
                } else {
                    $defaults[$key] = $userConfig[$key]
                }
            }
        } catch { Write-Verbose "Talon config parse failed: $($_.Exception.Message)" }
    }

    # Environment variable overrides (highest priority)
    if ($env:TALON_PROJECT_ROOT)  { $defaults['projectRoot'] = $env:TALON_PROJECT_ROOT }
    if ($env:TALON_NO_DASH)       { $defaults['dashboardEnabled'] = $false }
    if ($env:TALON_OLLAMA_ENDPOINT) { $defaults['ollama']['endpoint'] = $env:TALON_OLLAMA_ENDPOINT }

    $script:TalonConfig = $defaults
    return $defaults
}

# ── CACHE ENGINE ────────────────────────────────────────────────────────────

function Invoke-TalonCachedData {
    <#
    .SYNOPSIS
        Thread-safe cache with TTL expiry. Used by all diagnostic functions.
    .PARAMETER Key
        Cache key (string).
    .PARAMETER ExpirySeconds
        Time-to-live in seconds.
    .PARAMETER ScriptBlock
        ScriptBlock to execute if cache miss.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][int]$ExpirySeconds,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )
    $now = Get-Date
    if ($script:TalonCacheStore.ContainsKey($Key)) {
        $entry = $script:TalonCacheStore[$Key]
        if (($now - $entry.Timestamp).TotalSeconds -lt $ExpirySeconds) {
            return $entry.Value
        }
    }
    $computedValue = &$ScriptBlock
    $script:TalonCacheStore[$Key] = @{ Timestamp = $now; Value = $computedValue }
    return $computedValue
}

# ── OUTPUT HELPERS ──────────────────────────────────────────────────────────

function Write-TalonHeader {
    <#
    .SYNOPSIS
        Colored section header for rendered output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ConsoleColor]$Color = 'Cyan'
    )
    if (-not $script:TalonSuppressHeaders) {
        Write-Host $Message -ForegroundColor $Color
    }
}

# ── INTERACTIVITY DETECTION ────────────────────────────────────────────────

function Test-InteractiveSession {
    <#
    .SYNOPSIS
        Returns $true if in an interactive terminal (not CI, not redirected).
    #>
    if ($env:TALON_CI -or $env:CI) { return $false }
    try {
        return [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected
    } catch { return $false }
}

# ── PROMPT SYSTEM ──────────────────────────────────────────────────────────

function Get-TalonPromptGitSegment {
    <#
    .SYNOPSIS
        Cached git branch/status segment for prompt.
    #>
    [CmdletBinding()]
    param([string]$Reset)
    $cwd = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    $gitDir = Join-Path $cwd '.git'
    if (-not (Test-Path $gitDir)) { return '' }

    $config = Get-TalonConfig
    $cacheMs = $config['gitPromptCacheMs']
    $result = Invoke-TalonCachedData -Key "git_$cwd" -ExpirySeconds ([Math]::Max(1, $cacheMs / 1000)) -ScriptBlock {
        $branch = git --no-pager symbolic-ref --short HEAD 2>$null
        if (-not $branch) { return '' }
        $status = git --no-pager status --porcelain 2>$null
        $dirty = if ($status) { ' +' } else { '' }
        [PSCustomObject]@{ Text = " ($branch$dirty)" }
    }
    $esc = [char]27
    return "${esc}[38;5;121m$($result.Text)${Reset}"
}

function Get-TalonPromptText {
    <#
    .SYNOPSIS
        Builds the prompt string with path, time, git, and status.
    #>
    param([bool]$LastSuccess = $true)
    $esc = [char]27
    $reset = "${esc}[0m"

    $path = (Get-Location).Path -replace "^$([Regex]::Escape([Environment]::GetFolderPath('UserProfile')))", '~'
    $pathSegment = "${esc}[38;5;239m${esc}[38;5;255m $path ${reset}"
    $timeSegment = "${esc}[38;5;24m${esc}[38;5;117m $(Get-Date -Format 'HH:mm:ss') ${reset}"
    $gitSegment = Get-TalonPromptGitSegment -Reset $reset
    $statusColor = if ($LastSuccess) { "${esc}[38;5;121m" } else { "${esc}[38;5;196m}" }

    return "`n${pathSegment}${timeSegment}${gitSegment}`n${statusColor}> ${reset}"
}

function Set-TalonPrompt {
    <#
    .SYNOPSIS
        Install the Talon prompt function (replaces default prompt).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('global:prompt', 'Set custom prompt function')) {
        if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
            Set-Item -Path Function:\global:Prompt -Value {
                Get-TalonPromptText -LastSuccess:$?
            }
        }
    }
}

# ── READLINE ───────────────────────────────────────────────────────────────

function Set-TalonReadLine {
    <#
    .SYNOPSIS
        Configure PSReadLine for history prediction.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) { return }
    if ($PSCmdlet.ShouldProcess('PSReadLine options', 'Configure prediction settings')) {
        try {
            Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
        } catch { Write-Warning "PSReadLine configuration failed: $($_.Exception.Message)" }
    }
}

# ── ALIAS SYSTEM ───────────────────────────────────────────────────────────

function Set-TalonAliases {
    <#
    .SYNOPSIS
        Register all 50+ short aliases. Called once at startup.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Global aliases', 'Set all Talon aliases')) { return }

    $mappings = @(
        # ── SYSTEM ──
        @('health',    'Get-TalonHealth')
        @('spec',      'Get-TalonSpec')
        @('uptime',    'Get-TalonUptime')
        @('disk',      'Get-TalonDiskPressure')
        @('hog',       'Get-TalonResourceMap')
        @('ports',     'Get-TalonPortMap')
        @('battery',   'Get-TalonBattery')
        @('temp',      'Get-TalonTempCheck')

        # ── SECURITY ──
        @('fwaudit',   'Get-TalonFirewallAudit')
        @('boot',      'Get-TalonBootMap')
        @('taskaudit', 'Get-TalonScheduledTaskRisk')
        @('ghostaudit','Get-TalonGhostPortAudit')
        @('susaudit',  'Get-TalonSuspiciousProcess')
        @('evntaudit', 'Get-TalonEventStormAudit')
        @('admin',     'Get-TalonAdmin')

        # ── NETWORK ──
        @('netcheck',  'Get-TalonNetCheck')
        @('wifi',      'Get-TalonWifi')
        @('dnsbench',  'Get-TalonDnsBench')
        @('dnscache',  'Get-TalonDnsCache')
        @('nettriage', 'Get-TalonNetworkTriage')

        # ── ENVIRONMENT ──
        @('envmap',    'Get-TalonEnvMap')
        @('pathaudit', 'Get-TalonPathAudit')
        @('app',       'Get-TalonApp')
        @('patch',     'Get-TalonPatchHistory')
        @('driveraudit','Get-TalonDriverAudit')

        # ── AI ──
        @('ai',         'Invoke-TalonAI')
        @('ggl',        'Invoke-TalonSearch')
        @('secretredact','Protect-TalonSensitiveText')
        @('aistatus',   'Get-TalonAIStatus')
        @('injecttest', 'Test-TalonPromptInjection')
        @('quality',    'Get-TalonSourceQuality')

        # ── MEMORY ──
        @('remember',  'Add-TalonMemory')
        @('recall',    'Search-TalonMemory')
        @('memmap',    'Get-TalonMemoryMap')

        # ── REPORTS ──
        @('report',    'New-TalonReport')

        # ── SHELL ──
        @('dash',      'Show-TalonDashboard')
        @('reload',    'Update-TalonProfile')
        @('shield',    'Get-TalonShield')
        @('certs',     'Get-TalonCertCheck')

        # ── CONSOLIDATED DISPATCH ──
        @('sys',       'Get-TalonSystem')
        @('audit',     'Get-TalonAudit')
        @('net',       'Get-TalonNetwork')
        @('env',       'Get-TalonEnv')
    )

    foreach ($m in $mappings) {
        Set-Alias -Scope Global -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force
    }
}

# ── PROFILE RELOAD ─────────────────────────────────────────────────────────

function Update-TalonProfile {
    <#
    .SYNOPSIS
        Dot-source the profile without restarting the terminal.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('$PROFILE', 'Dot-source profile')) { . $PROFILE }
}

# ── DASHBOARD (STUB — Phase 3 will flesh this out) ────────────────────────

function Show-TalonDashboard {
    <#
    .SYNOPSIS
        TUI dashboard with category columns, lazy-rendered.
        Phase 3 will add the full multi-column render.
    #>
    [CmdletBinding()]
    param()

    $config = Get-TalonConfig
    $aiStatus = 'STANDBY'
    try {
        $null = Invoke-RestMethod -Uri "$($config['ollama']['endpoint'])/api/tags" -TimeoutSec 2 -ErrorAction Stop
        $aiStatus = 'ACTIVE'
    } catch {}

    $cWidth = try { [Console]::WindowWidth } catch { 120 }
    $rule = '─' * [Math]::Max(78, [Math]::Min(($cWidth - 2), 150))

    Write-Host "`n  ╭$rule╮" -ForegroundColor DarkGray
    Write-Host "  │  TALON $($script:TalonVersion) — All Commands" -ForegroundColor Cyan
    Write-Host "  │  AI: $aiStatus" -ForegroundColor DarkGray
    Write-Host "  ╰$rule╯" -ForegroundColor DarkGray
    Write-Host "  Type 'tutorial' for a walkthrough. Type 'dash' to redraw." -ForegroundColor DarkGray
    Write-Host ''
}

# ── INITIALIZATION (ENTRY POINT) ──────────────────────────────────────────

function Initialize-Talon {
    <#
    .SYNOPSIS
        Entry point. Configures prompt, aliases, ReadLine, dashboard.
        Called from profile loader.
    .PARAMETER ProjectRoot
        Default project workspace root.
    .PARAMETER DashboardEnabled
        Show dashboard on startup (respects $env:TALON_NO_DASH).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ProjectRoot,
        [switch]$DashboardEnabled
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Load config
    $config = Get-TalonConfig
    if ($ProjectRoot) { $config['projectRoot'] = $ProjectRoot }

    # Configure shell
    Set-TalonReadLine
    Set-TalonAliases
    Set-TalonPrompt

    # Dashboard (only in interactive sessions)
    $showDash = if ($PSBoundParameters.ContainsKey('DashboardEnabled')) { $DashboardEnabled } else { $config['dashboardEnabled'] }
    if ($showDash -and (Test-InteractiveSession)) {
        Show-TalonDashboard
        if ($config['dashboardDismissSec'] -gt 0 -and -not $env:TALON_NO_DASH) {
            Start-Sleep -Seconds $config['dashboardDismissSec']
        }
    }
}
```

### Step 0.4 — Write the Profile Loader

This is the thin `Microsoft.PowerShell_profile.ps1` that PowerShell runs automatically.

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

# =============================================================================
# Talon v1 — Profile Loader (thin)
# =============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$talonModule = Join-Path $PSScriptRoot 'Talon\Talon.psd1'
if (Test-Path $talonModule) {
    Import-Module $talonModule -Force -ErrorAction Stop
    Initialize-Talon
} else {
    Write-Warning "Talon module not found at: $talonModule"
}
```

**⚠️ Gotcha:** The profile must be symlinked/copied to `$PROFILE.CurrentUserCurrentHost` if that path differs.

### Step 0.5 — Create the Config Directory

```powershell
▶️ # Create config directory with default config
$configDir = Join-Path $HOME '.talon'
if (-not (Test-Path $configDir)) { New-Item $configDir -ItemType Directory -Force | Out-Null }

$defaultConfig = @{
    version              = '1'
    theme                = 'auto'
    dashboardEnabled     = $true
    dashboardDismissSec  = 2
    ollama = @{
        endpoint    = 'http://127.0.0.1:11434'
        model       = 'talon-default'
        contextSize = 8192
        timeoutSec  = 120
    }
    modules = @{
        system   = $true
        security = $true
        network  = $true
        ai       = $true
    }
    gitPromptCacheMs     = 2000
    suppressBranding     = $false
}

$configPath = Join-Path $configDir 'config.json'
if (-not (Test-Path $configPath)) {
    $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
}
```

### Step 0.6 — Verify Phase 0

```powershell
🔍 # 1. Open a new PowerShell 7 terminal
🔍 # 2. Verify prompt shows path + time
🔍 # 3. Run: dash
🔍 # Expected: Talon dashboard with AI: STANDBY and message
🔍 # 4. Run: reload
🔍 # Expected: profile reloads without error
🔍 # 5. Run: health
🔍 # Expected: "health" is not recognized — Tier 1 not yet created
```

**✅ Phase 0 exit criteria:**
- [ ] New PS7 terminal shows Talon prompt with path/time/git
- [ ] `dash` renders the dashboard
- [ ] `reload` works
- [ ] Profile load takes <300ms (measure with `Measure-Command { Import-Module Talon }`)
- [ ] `~\.talon\config.json` exists with defaults

---

## Phase 1 — Core 50 Functions (Day 2-3)

**Goal:** All 34 Tier 1 functions implemented, tested, and loading on demand via nested module.

### Step 1.1 — Create Tier 1 Module Manifest

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.Commands.psd1"

@{
    RootModule        = 'Talon.Commands.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Description       = 'Talon — Diagnostic & Security Commands (Tier 1)'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        # System
        'Get-TalonHealth', 'Get-TalonSpec', 'Get-TalonUptime', 'Get-TalonDiskPressure',
        'Get-TalonResourceMap', 'Get-TalonPortMap', 'Get-TalonBattery', 'Get-TalonTempCheck',
        # Security
        'Get-TalonFirewallAudit', 'Get-TalonBootMap', 'Get-TalonScheduledTaskRisk',
        'Get-TalonGhostPortAudit', 'Get-TalonSuspiciousProcess', 'Get-TalonEventStormAudit',
        'Get-TalonAdmin',
        # Network
        'Get-TalonNetCheck', 'Get-TalonWifi', 'Get-TalonDnsBench', 'Get-TalonDnsCache',
        'Get-TalonNetworkTriage',
        # Environment
        'Get-TalonEnvMap', 'Get-TalonPathAudit', 'Get-TalonApp', 'Get-TalonPatchHistory',
        'Get-TalonDriverAudit',
        # Utility
        'Get-TalonShield', 'Get-TalonCertCheck',
        # Dispatchers
        'Get-TalonSystem', 'Get-TalonAudit', 'Get-TalonNetwork', 'Get-TalonEnv'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
```

**⚠️ Gotcha:** Each function name here MUST exist in `FunctionsToExport` or module auto-loading won't trigger.

### Step 1.2 — Implement All 34 Tier 1 Functions

This is the bulk of the work. Each function follows the same pattern:
- Accept pipeline input where relevant
- Use `Invoke-TalonCachedData` for data that takes >100ms to collect
- Return `[PSCustomObject]` for structured output
- Handle errors gracefully (no exceptions to user)

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.Commands.psm1"

# ── Talon v1 — Commands (Tier 1) ───────────────────────────────────────────
# Auto-loaded on first use via module auto-loading.

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SYSTEM DIAGNOSTICS (8)                                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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
            'Processor'     = $cpu.Name
            'Cores'         = "$($cpu.NumberOfCores) / $((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors) threads"
            'RAM'           = "$totalRamGB GB ($($ram.Count) slots)"
            'Vendor'        = $comp.Manufacturer
            'Model'         = $comp.Model
            'GPU'           = $gpu.Description
            'Virtualized'   = if ($isVM) { 'Yes' } else { 'No' }
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
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
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
        resmap | ai "Which processes are using the most resources?"
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
            'Design Capacity'       = $bat.DesignCapacity
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

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SECURITY / SENTINEL (7)                                                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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
        Finds non-Microsoft scheduled tasks that invoke powershell/cmd/temp.
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

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  NETWORK (5)                                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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
    Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" |
        Select-Object Description, IPAddress, MACAddress, DefaultIPGateway, DNSServerSearchOrder
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  ENVIRONMENT (5)                                                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  UTILITY (2)                                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  CONSOLIDATED DISPATCHERS (4)                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

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
        Firewall | Boot | ScheduledTask | GhostPort | SuspiciousProcess | EventStorm
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
```

### Step 1.3 — Wire Tier 1 as Nested Module in Root Manifest

Now update the root `Talon.psd1` to declare the nested module:

```powershell
📝 Edit: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.psd1"

# Add this line to the existing manifest:
NestedModules = @('Talon.Commands.psd1')
# + 'Talon.AI.psd1' (added in Phase 2)
```

### Step 1.4 — Verify Phase 1

```powershell
🔍 # Open new PS7 terminal (or reload)
▶️ reload

🔍 # Run each Tier 1 function and verify output:
▶️ health       # → System health pulse
▶️ spec         # → Hardware specs
▶️ uptime       # → Boot time + uptime
▶️ disk         # → Per-drive free space
▶️ hog          # → Top 10 processes
▶️ ports        # → TCP listeners
▶️ battery      # → Battery health
▶️ temp         # → Temp dir size

▶️ fwaudit      # → Firewall gaps
▶️ boot         # → Run keys
▶️ taskaudit    # → Scheduled tasks
▶️ ghostaudit   # → Orphan ports
▶️ susaudit     # → Suspicious procs
▶️ evntaudit    # → Event storms
▶️ admin        # → Admin group

▶️ netcheck     # → Internet test
▶️ wifi         # → SSID/signal
▶️ dnsbench     # → Resolver speeds
▶️ dnscache     # → DNS cache
▶️ nettriage    # → Adapter config

▶️ envmap       # → Env vars
▶️ pathaudit    # → PATH validation
▶️ app          # → Installed apps
▶️ patch        # → Update history
▶️ driveraudit  # → Unsigned drivers

▶️ shield       # → Defender status
▶️ certs        # → Certificates

▶️ sys Health   # → Dispatch
▶️ audit all    # → All security audits
▶️ net NetCheck # → Network dispatch
▶️ env Admin    # → Environment dispatch
```

**✅ Phase 1 exit criteria:**
- [ ] All 34 Tier 1 functions return structured output
- [ ] All 44 aliases resolve to their functions
- [ ] First call to any Tier 1 function triggers ~60ms module load
- [ ] No errors or exceptions in normal conditions
- [ ] `sys/audit/net/env` dispatchers work with `-Type` parameter
- [ ] Pipeline integration works: `ports | ai "summarize"`

---

## Phase 2 — AI Pipeline (Day 4)

**Goal:** Ollama streaming client, web scraping pipeline, sensitive text redaction, memory system.

### Step 2.1 — Create Tier 2 Module Manifest

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.AI.psd1"

@{
    RootModule        = 'Talon.AI.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c3d4e5f6-a7b8-9012-cdef-123456789012'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Description       = 'Talon — AI Engine (Tier 2, lazy-loaded)'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-TalonAI', 'Invoke-TalonSearch',
        'Protect-TalonSensitiveText',
        'Get-TalonAIStatus',
        'Test-TalonPromptInjection', 'Get-TalonSourceQuality',
        'Resolve-TalonSearchHref',
        'Add-TalonMemory', 'Search-TalonMemory', 'Get-TalonMemoryMap'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
```

### Step 2.2 — Implement AI Engine

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.AI.psm1"

# ── Talon v1 — AI Engine (Tier 2) ──────────────────────────────────────────
# Zero cost until invoked. Requires Ollama running on localhost:11434.

# ── MEMORY SUPPORT CLASS ──────────────────────────────────────────────────

class TalonMemoryEntry {
    [string]   $Id
    [string]   $Type
    [string[]] $Tags
    [string]   $Text
    [string]   $Source
    [datetime] $Created
    [string]   $Confidence
    [bool]     $Pinned

    TalonMemoryEntry() {}

    TalonMemoryEntry([hashtable]$Map) {
        $this.Id         = $Map['Id']
        $this.Type       = $Map['Type']
        $this.Tags       = @($Map['Tags'])
        $this.Text       = $Map['Text']
        $this.Source     = $Map['Source']
        $this.Created    = [datetime]::Parse($Map['Created'])
        $this.Confidence = $Map['Confidence']
        $this.Pinned     = [bool]$Map['Pinned']
    }
}

# ── CONFIG HELPERS ─────────────────────────────────────────────────────────

function Get-TalonAIEndpoint {
    $configPath = Join-Path $HOME '.talon' 'config.json'
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            return $config['ollama']['endpoint']
        } catch {}
    }
    return 'http://127.0.0.1:11434'
}

function Get-TalonAIModel {
    $configPath = Join-Path $HOME '.talon' 'config.json'
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
            return $config['ollama']['model']
        } catch {}
    }
    return 'talon-default'
}

# ── MEMORY FILE HELPERS (internal, not exported) ──────────────────────────

function Get-TalonMemoryFile {
    $memDir = Join-Path $HOME '.talon' 'Memory'
    if (-not (Test-Path $memDir)) { $null = New-Item $memDir -ItemType Directory -Force }
    return Join-Path $memDir 'talon-memory.jsonl'
}

function Format-TalonMemoryId {
    "mem_{0}_{1}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), ([Guid]::NewGuid().ToString('N').Substring(0, 6))
}

function Format-TalonMemorySnippet {
    param([AllowNull()][string]$Text, [int]$MaxLength = 220)
    if ($null -eq $Text) { return '' }
    $clean = (($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' ').Trim()
    if ($clean.Length -le $MaxLength) { return $clean }
    return $clean.Substring(0, $MaxLength - 1) + '…'
}

# ── SENSITIVE TEXT REDACTION ──────────────────────────────────────────────

function Protect-TalonSensitiveText {
    <#
    .SYNOPSIS
        Redacts secrets, tokens, passwords, and keys from pipeline output.
    .DESCRIPTION
        Automatically masks values for keys matching:
        secret, token, password, passwd, pwd, credential, connectionstring,
        sas, bearer, apikey, privatekey, aws_secret, api_key
    .EXAMPLE
        envmap | Protect-TalonSensitiveText
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $true)][AllowNull()]$InputObject)
    begin { $buffer = [System.Collections.Generic.List[string]]::new() }
    process {
        if ($null -eq $InputObject) { return }
        $text = if ($InputObject -is [string]) { $InputObject } else { $InputObject | Out-String }
        $buffer.Add($text)
    }
    end {
        $combined = ($buffer -join "`n")
        $patterns = @(
            '(?im)(^\s*[^=\r\n]*(?:secret|token|password|passwd|pwd|credential|connectionstring|sas|bearer|apikey|privatekey|api_key|aws_secret)[^=\r\n]*\s*=\s*).+$'
            '(?i)("(?:[^"]*(?:secret|token|password|passwd|pwd|credential|connectionstring|sas|bearer|apikey|privatekey|api_key|aws_secret)[^"]*)"\s*:\s*")[^"]*(")'
        )
        $result = $combined
        foreach ($pattern in $patterns) {
            $result = [regex]::Replace($result, $pattern, '$1<REDACTED>$2')
        }
        $result
    }
}

# ── AI STATUS ──────────────────────────────────────────────────────────────

function Get-TalonAIStatus {
    <#
    .SYNOPSIS
        Check Ollama reachability and list available models.
    .EXAMPLE
        aistatus
    #>
    $endpoint = Get-TalonAIEndpoint
    try {
        $models = (Invoke-RestMethod -Uri "$endpoint/api/tags" -TimeoutSec 5 -ErrorAction Stop).models
        if (-not $models) { return [PSCustomObject]@{ Endpoint = $endpoint; Status = 'Reachable'; Models = '(none)' } }
        foreach ($model in $models) {
            [PSCustomObject]@{
                Endpoint = $endpoint
                Status   = 'Reachable'
                Model    = $model.name
                Size     = "$([Math]::Round($model.size / 1GB, 2)) GB"
                Modified = $model.modified_at
            }
        }
    } catch {
        [PSCustomObject]@{ Endpoint = $endpoint; Status = "Unavailable — $($_.Exception.Message)"; Model = ''; Size = '' }
    }
}

# ── SECURITY GATE ─────────────────────────────────────────────────────────

function Test-TalonPromptInjection {
    <#
    .SYNOPSIS
        Check scraped web text for common prompt injection patterns.
    .EXAMPLE
        Test-TalonPromptInjection -Payload "ignore previous instructions"
    #>
    param([AllowNull()][string]$Payload)
    if ([string]::IsNullOrWhiteSpace($Payload)) { return $false }
    return ($Payload -match '(?i)(ignore\s+(?:(?:previous|above|all)\s+)*instructions|you\s+are\s+now|system\s*prompt|\bDAN\b.*mode)')
}

# ── SOURCE QUALITY SCORE ──────────────────────────────────────────────────

function Get-TalonSourceQuality {
    <#
    .SYNOPSIS
        Heuristic quality score (0-100) for scraped web content.
    .EXAMPLE
        Get-TalonSourceQuality -Url "https://example.gov/report" -Content "..."
    #>
    param([string]$Url, [AllowNull()][string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return 0 }
    $score = 50
    if ($Content.Length -gt 200)  { $score += 20 }
    if ($Content.Length -gt 800)  { $score += 15 }
    if ($Url -match '\.(gov|edu|org)(/|$)') { $score += 15 }
    return [Math]::Min(100, $score)
}

# ── SEARCH HREF RESOLVER ─────────────────────────────────────────────────

function Resolve-TalonSearchHref {
    <#
    .SYNOPSIS
        Resolve DuckDuckGo redirect URLs to real target URLs.
    #>
    param([string]$Href)
    if (-not $Href) { return $null }
    if ($Href -match 'uddg=([^&]+)') { return [Uri]::UnescapeDataString($matches[1]) }
    if ($Href -match '^//') { return "https:$Href" }
    if ($Href -match '^https?://') { return $Href }
    return $null
}

# ── WEB SEARCH (with optional AI synthesis) ──────────────────────────────

function Invoke-TalonSearch {
    <#
    .SYNOPSIS
        Web search with DuckDuckGo. Use -AI to synthesize results via Ollama.
    .PARAMETER Query
        Search query text.
    .PARAMETER AI
        Fetch results and synthesize with AI (instead of opening browser).
    .PARAMETER Sources
        Max sources to read (1-15, default 5).
    .PARAMETER Deep
        Read more content per source (3000 chars vs 1800).
    .PARAMETER Instruction
        Custom instruction for AI synthesis.
    .EXAMPLE
        ggl "windows firewall hardening"         # Opens browser
        ggl "windows firewall hardening" -AI     # AI synthesis
        ggl "windows firewall hardening" -AI -Deep -Sources 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)][string[]]$Query,
        [switch]$AI,
        [switch]$Deep,
        [ValidateRange(1, 15)][int]$Sources = 5,
        [string]$Instruction = 'Synthesize a concise report answering the query based on the following website contents.'
    )

    $cleanTokens = $Query | Where-Object { $_ -notmatch '^-' }
    $jq = ($cleanTokens -join ' ').Trim()
    if (-not $jq) { throw 'Search query is empty.' }

    # Browser mode
    if (-not $AI) {
        $enc = [Uri]::EscapeDataString($jq)
        $url = "https://duckduckgo.com/?q=$enc"
        Write-TalonHeader " [Search] Opening browser: $jq" Cyan
        Start-Process $url
        return
    }

    # AI synthesis mode
    Write-TalonHeader " [Search] Fetching results for: $jq" Cyan
    try {
        $resp = Invoke-WebRequest -Uri 'https://lite.duckduckgo.com/lite/' -Method Post -Body @{ q = $jq } -UseBasicParsing -ErrorAction Stop

        $targetUrls = [regex]::Matches($resp.Content, 'href="([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value } |
            Where-Object { $_ -match 'uddg=' } |
            ForEach-Object { Resolve-TalonSearchHref -Href $_ } |
            Where-Object { $_ -and $_ -notmatch '^https?://(www\.)?duckduckgo\.com' } |
            Select-Object -Unique -First 30

        if (-not $targetUrls) {
            $enc = [Uri]::EscapeDataString($jq)
            Start-Process "https://duckduckgo.com/?q=$enc"
            return
        }

        $context = "Search Query: $jq`n`n"
        $read = 0

        foreach ($u in $targetUrls) {
            if ($read -ge $Sources) { break }
            Write-TalonHeader "  [Read] $u" DarkGray

            try {
                $page = Invoke-WebRequest -Uri $u -Headers @{
                    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
                } -UseBasicParsing -TimeoutSec $(if ($Deep) { 10 } else { 5 }) -ErrorAction Stop

                $contentType = $page.BaseResponse.ContentType
                if ($contentType -notmatch 'text/html|application/xhtml\+xml') { continue }

                $txt = [System.Net.WebUtility]::HtmlDecode(
                    ($page.Content -replace '(?s)<style[^>]*>.*?</style>', '' -replace '(?s)<script[^>]*>.*?</script>', '' -replace '<[^>]+>', ' ').Trim()
                ) -replace '\s+', ' '

                if ([string]::IsNullOrWhiteSpace($txt)) { continue }
                if (Test-TalonPromptInjection -Payload $txt) {
                    Write-TalonHeader '  [Security] Prompt injection detected, skipping.' Yellow
                    continue
                }

                $quality = Get-TalonSourceQuality -Url $u -Content $txt
                if ($quality -lt 40) {
                    Write-TalonHeader "  [Quality] Score $quality/100 — below threshold." Yellow
                    continue
                }

                $maxChars = if ($Deep) { 3000 } else { 1800 }
                if ($txt.Length -gt $maxChars) { $txt = $txt.Substring(0, $maxChars) }
                $context += "Source: $u (Quality: $quality)`nContent: $txt`n`n"
                $read++
                Start-Sleep -Milliseconds 300
            } catch { Write-Verbose "Failed to read $u" }
        }

        if ($read -eq 0) {
            Write-TalonHeader '  [Search] No readable sources found. Opening browser fallback.' Yellow
            $enc = [Uri]::EscapeDataString($jq)
            Start-Process "https://duckduckgo.com/?q=$enc"
            return
        }

        Write-TalonHeader "  [AI] Synthesizing $read sources..." Magenta
        $context | Invoke-TalonAI -Instruction $Instruction

    } catch {
        Write-Warning "Search failed: $($_.Exception.Message)"
        $enc = [Uri]::EscapeDataString($jq)
        Start-Process "https://duckduckgo.com/?q=$enc"
    }
}

# ── MEMORY SYSTEM ──────────────────────────────────────────────────────────

function Read-TalonMemory {
    $memFile = Get-TalonMemoryFile
    if (-not (Test-Path $memFile)) { return @() }
    Get-Content $memFile -ErrorAction SilentlyContinue |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object {
            try {
                $map = $_ | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                [TalonMemoryEntry]::new($map)
            } catch { Write-Verbose "Memory parse error: $($_.Exception.Message)" }
        }
}

function Add-TalonMemory {
    <#
    .SYNOPSIS
        Save local preferences, runbooks, and useful notes.
    .PARAMETER Text
        Content to remember.
    .PARAMETER Type
        Category: preference | runbook | session | web | sysops | note
    .PARAMETER Pinned
        Always include in AI context.
    .EXAMPLE
        remember "Prefer fast answers unless I ask for deep analysis." -Type preference -Pinned
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)][string[]]$Text,
        [ValidateSet('preference', 'runbook', 'session', 'web', 'sysops', 'note')][string]$Type = 'note',
        [string[]]$Tag = @(),
        [string]$Source = 'manual',
        [switch]$Pinned
    )
    $joined = ($Text -join ' ').Trim()
    if (-not $joined) { throw 'Memory text is empty.' }

    $map = [hashtable]@{
        Id         = Format-TalonMemoryId
        Type       = $Type
        Tags       = @($Tag)
        Text       = ($joined | Protect-TalonSensitiveText | Out-String).Trim()
        Source     = $Source
        Created    = (Get-Date).ToString('o')
        Confidence = 'user'
        Pinned     = [bool]$Pinned
    }

    if ($PSCmdlet.ShouldProcess("Memory: $(Format-TalonMemorySnippet $joined)", 'Save memory')) {
        $entry = [TalonMemoryEntry]::new($map)
        ($entry | ConvertTo-Json -Compress -Depth 6) | Add-Content -Path (Get-TalonMemoryFile) -Encoding UTF8
        return $entry
    }
}

function Search-TalonMemory {
    <#
    .SYNOPSIS
        Search local memory store.
    .PARAMETER Query
        Search terms.
    .PARAMETER First
        Max results (default 8).
    .PARAMETER Pinned
        Only show pinned entries.
    .EXAMPLE
        recall "ollama config"
        recall -Pinned
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)][string[]]$Query = @(),
        [int]$First = 8,
        [switch]$Pinned
    )
    $queryText = ($Query -join ' ').Trim()
    $items = @(Read-TalonMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if (-not $items) { return }
    if (-not $queryText) {
        return $items | Sort-Object Created -Descending | Select-Object -First $First
    }

    $terms = @($queryText.ToLowerInvariant() -split '\s+' | Where-Object { $_ -match '^[a-z0-9._-]{3,}$' } | Select-Object -Unique -First 18)

    @(foreach ($item in $items) {
        $score = 0
        $haystack = "$($item.Type) $(($item.Tags -join ' ')) $($item.Text)".ToLowerInvariant()
        foreach ($term in $terms) { if ($haystack.Contains($term)) { $score++ } }
        if ($item.Pinned) { $score += 2 }
        if ($score -gt 0) {
            [PSCustomObject]@{
                Score      = $score
                Type       = $item.Type
                Tags       = $item.Tags
                Text       = Format-TalonMemorySnippet $item.Text 220
                Created    = $item.Created
                Pinned     = $item.Pinned
            }
        }
    }) | Sort-Object Score -Descending, Created -Descending | Select-Object -First $First
}

function Get-TalonMemoryMap {
    <#
    .SYNOPSIS
        List recent or pinned memory entries.
    .EXAMPLE
        memmap
        memmap -Pinned
    #>
    param([switch]$Pinned, [int]$First = 40)
    $items = @(Read-TalonMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    $items | Sort-Object Created -Descending | Select-Object -First $First
}

# ── AI STREAMING ENGINE ────────────────────────────────────────────────────

function Invoke-TalonAI {
    <#
    .SYNOPSIS
        Pipe any data to the local Ollama model for streaming analysis.
    .PARAMETER InputData
        Pipeline data to analyze.
    .PARAMETER Instruction
        What to do with the data.
    .PARAMETER Model
        Ollama model name (default: talon-default).
    .PARAMETER TimeoutSec
        Max wait for response.
    .PARAMETER Remember
        Save the AI response to memory.
    .EXAMPLE
        "what's using my RAM?" | ai
        resmap | ai "Which processes are consuming most memory?"
        envmap | secretredact | ai "Summarize environment config"
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$InputData,
        [Parameter(Position = 0)][string]$Instruction = 'Analyze this data.',
        [string]$Model,
        [int]$TimeoutSec = 120,
        [switch]$Remember
    )

    begin { $dataBuffer = [System.Collections.Generic.List[object]]::new() }
    process { $dataBuffer.Add($InputData) }
    end {
        $stringifiedData = $dataBuffer | Out-String
        $modelName = if ($Model) { $Model } else { Get-TalonAIModel }
        $endpoint = Get-TalonAIEndpoint

        # Build context
        $dataProfile = if ($dataBuffer[0] -is [string]) { 'Text' } else { 'Object' }
        $dataRows = $dataBuffer.Count

        # Context envelope
        $contract = @'
You are Talon AI, a fast local PowerShell/SysOps assistant.

Defaults:
- Answer with PowerShell 7 syntax when relevant
- Be concise, use short bullets
- Put commands first when asked "how to"
- Never output hidden reasoning or chain-of-thought
- If pipeline data is provided, answer from it first
'@

        $payload = @{
            model  = $modelName
            prompt = "$contract`n`nPipeline data ($dataProfile, $dataRows rows):`n$stringifiedData`n`nUser: $Instruction`n`nTalon AI:"
            stream = $true
        } | ConvertTo-Json -Depth 5

        $success = $false
        $lastErr = $null

        for ($attempt = 1; $attempt -le 2 -and -not $success; $attempt++) {
            if ($attempt -gt 1) {
                Write-TalonHeader "  [Retry] Attempt $attempt..." Yellow
                Start-Sleep -Seconds 3
            }

            Write-Host "`n  [AI] $($modelName.ToUpper()) " -NoNewline -ForegroundColor Magenta
            $client = [System.Net.Http.HttpClient]::new()
            $respText = [System.Text.StringBuilder]::new()

            try {
                $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
                $body = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                $response = $client.PostAsync("$endpoint/api/generate", $body).GetAwaiter().GetResult()
                $response.EnsureSuccessStatusCode() | Out-Null

                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $reader = [System.IO.StreamReader]::new($stream)

                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    if (-not $line) { continue }
                    try {
                        $chunk = $line | ConvertFrom-Json -ErrorAction Stop
                        if ($chunk.response) {
                            $null = $respText.Append($chunk.response)
                            Write-Host $chunk.response -NoNewline -ForegroundColor White
                        }
                        if ($chunk.done) { break }
                    } catch {}
                }
                Write-Host ''

                if ($Remember -and $respText.Length -gt 0) {
                    Add-TalonMemory -Text "Question: $Instruction`n`nAnswer: $($respText.ToString())" -Type session -Tag @('ai') -Source 'ai' | Out-Null
                }

                $success = $true
            } catch {
                $lastErr = $_
                Write-Warning "AI pipeline error: $($_.Exception.Message)"
            } finally {
                if ($reader) { $reader.Dispose() }
                $client.Dispose()
            }
        }

        if (-not $success -and $lastErr) { throw $lastErr }
    }
}
```

### Step 2.3 — Wire Tier 2 in Root Manifest

```powershell
📝 Edit: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.psd1"

# Update NestedModules:
NestedModules = @('Talon.Commands.psd1', 'Talon.AI.psd1')
```

### Step 2.4 — Create Default Ollama Modelfile

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\AI\talon-default.modelfile"

FROM qwen3:4b

PARAMETER temperature 0.2
PARAMETER top_p 0.85
PARAMETER top_k 20
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 8192

SYSTEM """
You are Talon AI, a concise terminal assistant for PowerShell 7 on Windows.

- Answer with PowerShell 7 syntax by default.
- Put the command first when the user asks how to do something.
- Prefer native PowerShell cmdlets over Bash, CMD, or external tools.
- Be concise: short bullets, minimal explanation, practical examples.
- Do not show hidden reasoning or chain-of-thought.
- For simple command requests, output only the command.
- Tone: professional, efficient, slightly witty.
"""
```

### Step 2.5 — Verify Phase 2

```powershell
🔍 # Open new PS7 terminal (or reload)
▶️ reload

🔍 # Test AI status
▶️ aistatus
# Expected: Shows Ollama reachability (or "Unavailable" warning)

🔍 # Test streaming AI (requires Ollama running with a model)
▶️ "list 3 useful PowerShell commands for disk analysis" | ai

🔍 # Test web search (browser mode)
▶️ ggl "windows event log auditing"
# Expected: Opens browser

🔍 # Test web-to-AI (requires Ollama)
▶️ ggl "windows event log auditing" -AI -Sources 3

🔍 # Test memory
▶️ remember "Always use -WhatIf before destructive commands" -Type preference -Pinned
▶️ recall "WhatIf"
▶️ memmap -Pinned

🔍 # Test sensitive text redaction
▶️ $env:COMPUTERNAME | secretredact
```

**✅ Phase 2 exit criteria:**
- [ ] `aistatus` reports Ollama status gracefully (not crashing)
- [ ] `| ai` streams tokens to console
- [ ] `ggl` opens browser without AI flag
- [ ] `ggl -AI` fetches, scans, and synthesizes
- [ ] `remember` + `recall` + `memmap` work end-to-end
- [ ] `secretredact` masks sensitive patterns
- [ ] AI module is NOT loaded until first AI command (verify with `Get-Module Talon.AI`)

---

## Phase 3 — Dashboard & Reports (Day 5)

**Goal:** Full TUI dashboard with category columns, live refresh mode, and report generator.

### Step 3.1 — Build the Full Dashboard

Replace the stub `Show-TalonDashboard` in `Talon.psm1` with the full multi-column render:

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.psm1"
# Replace the Show-TalonDashboard function

function Show-TalonDashboard {
    <#
    .SYNOPSIS
        Full TUI dashboard with category columns and command aliases.
        Lazy-renders in background thread to keep prompt fast.
    .PARAMETER Detailed
        Show full function names instead of aliases.
    .EXAMPLE
        dash
    #>
    [CmdletBinding()]
    param([switch]$Detailed)

    # ── Collect state (fast) ──
    $config = Get-TalonConfig
    $aiStatus = 'STANDBY'
    try {
        $null = Invoke-RestMethod -Uri "$($config['ollama']['endpoint'])/api/tags" -TimeoutSec 2 -ErrorAction Stop
        $aiStatus = 'ACTIVE'
    } catch {}

    $pRoot = if ($config['projectRoot']) { $config['projectRoot'] } else { "$HOME\Projects" }

    # ── Layout helpers ──
    $fit = {
        param([string]$Text, [int]$Width)
        if ($Width -le 0) { return '' }
        if ([string]::IsNullOrEmpty($Text)) { return ''.PadRight($Width) }
        if ($Text.Length -gt $Width) { return $Text.Substring(0, $Width - 1) + '…' }
        return $Text.PadRight($Width)
    }

    $cWidth = try { [Console]::WindowWidth } catch { 120 }
    if ($cWidth -lt 1) { $cWidth = 120 }

    $dbWidth = [Math]::Max(78, [Math]::Min(($cWidth - 4), 150))
    $boxTextWidth = $dbWidth - 2
    $gap = '  '
    $colCount = if ($dbWidth -ge 116) { 4 } elseif ($dbWidth -ge 76) { 2 } else { 1 }
    $colWidth = [int][Math]::Floor(($dbWidth - (($colCount - 1) * $gap.Length)) / $colCount)
    $rule = '─' * $dbWidth

    # ── Header ──
    Write-Host "`n  ╭$rule╮" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fit "TALON $($script:TalonVersion) · All Commands" $boxTextWidth) -ForegroundColor Cyan -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ├$rule┤" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fit "AI: $aiStatus   |   Workspace: $pRoot" $boxTextWidth) -ForegroundColor DarkGray -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ╰$rule╯`n" -ForegroundColor DarkGray

    # ── Build alias map ──
    $aliases = @{}
    Get-Alias | Where-Object { $_.Definition -match '^(Get|Invoke|Add|Search|Test|Protect|Update|Show)-Talon' } |
        ForEach-Object { $aliases[$_.Definition] = $_.Name }

    # ── Categories ──
    $categories = @(
        @{ Name = 'SYSTEM'; Color = 'Cyan'; Sub = @(
            @{ Name = 'Health'; Cmd = @('Get-TalonHealth','Get-TalonSpec','Get-TalonUptime') }
            @{ Name = 'Storage'; Cmd = @('Get-TalonDiskPressure','Get-TalonTempCheck') }
            @{ Name = 'Perf'; Cmd = @('Get-TalonResourceMap','Get-TalonPortMap','Get-TalonBattery') }
        )}
        @{ Name = 'SECURITY'; Color = 'Red'; Sub = @(
            @{ Name = 'Access'; Cmd = @('Get-TalonAdmin','Get-TalonShield') }
            @{ Name = 'Firewall'; Cmd = @('Get-TalonFirewallAudit') }
            @{ Name = 'Anomalies'; Cmd = @('Get-TalonGhostPortAudit','Get-TalonSuspiciousProcess','Get-TalonEventStormAudit') }
            @{ Name = 'Persistence'; Cmd = @('Get-TalonBootMap','Get-TalonScheduledTaskRisk') }
        )}
        @{ Name = 'NETWORK'; Color = 'Blue'; Sub = @(
            @{ Name = 'Connect'; Cmd = @('Get-TalonNetCheck','Get-TalonWifi','Get-TalonDnsBench','Get-TalonDnsCache') }
            @{ Name = 'Diag'; Cmd = @('Get-TalonNetworkTriage') }
        )}
        @{ Name = 'ENV'; Color = 'Yellow'; Sub = @(
            @{ Name = 'Config'; Cmd = @('Get-TalonEnvMap','Get-TalonPathAudit') }
            @{ Name = 'Apps'; Cmd = @('Get-TalonApp','Get-TalonPatchHistory','Get-TalonDriverAudit','Get-TalonCertCheck') }
        )}
        @{ Name = 'AI'; Color = 'Magenta'; Sub = @(
            @{ Name = 'Query'; Cmd = @('Invoke-TalonAI','Invoke-TalonSearch','Get-TalonAIStatus') }
            @{ Name = 'Memory'; Cmd = @('Add-TalonMemory','Search-TalonMemory','Get-TalonMemoryMap') }
            @{ Name = 'Safety'; Cmd = @('Protect-TalonSensitiveText','Test-TalonPromptInjection') }
        )}
        @{ Name = 'SHELL'; Color = 'Green'; Sub = @(
            @{ Name = 'Control'; Cmd = @('Show-TalonDashboard','Update-TalonProfile') }
            @{ Name = 'Reports'; Cmd = @('New-TalonReport') }
        )}
    )

    # ── Render categories in columns ──
    $sCount = $categories.Count
    for ($sIdx = 0; $sIdx -lt $sCount; $sIdx += $colCount) {
        $lIdx = [Math]::Min($sIdx + $colCount - 1, $sCount - 1)
        $sGrp = @($categories[$sIdx..$lIdx])

        $subCount = ($sGrp | ForEach-Object { $_.Sub.Count } | Measure-Object -Maximum).Maximum

        Write-Host ("  " + (($sGrp | ForEach-Object { & $fit "$($_.Name) ($($_.Sub.Count))" $colWidth }) -join $gap)) -ForegroundColor Cyan
        Write-Host ("  " + (($sGrp | ForEach-Object { '─' * $colWidth }) -join $gap)) -ForegroundColor DarkGray

        for ($subIdx = 0; $subIdx -lt $subCount; $subIdx++) {
            Write-Host ("  " + (($sGrp | ForEach-Object {
                if ($subIdx -lt $_.Sub.Count) { "  $($_.Sub[$subIdx].Name):".PadRight(1) | & $fit $colWidth } else { ' ' * $colWidth }
            }) -join $gap)) -ForegroundColor DarkGray

            $maxCmds = ($sGrp | ForEach-Object {
                if ($subIdx -lt $_.Sub.Count) { $_.Sub[$subIdx].Cmd.Count } else { 0 }
            } | Measure-Object -Maximum).Maximum

            for ($cIdx = 0; $cIdx -lt $maxCmds; $cIdx++) {
                Write-Host ("  " + (($sGrp | ForEach-Object {
                    if ($subIdx -lt $_.Sub.Count -and $cIdx -lt $_.Sub[$subIdx].Cmd.Count) {
                        $fn = $_.Sub[$subIdx].Cmd[$cIdx]
                        $display = if ($Detailed) { $fn } else { $aliases[$fn] }
                        if (-not $display) { $display = $fn }
                        & $fit $display $colWidth
                    } else { ' ' * $colWidth }
                }) -join $gap)) -ForegroundColor White
            }
        }
        Write-Host ''
    }

    # ── Footer ──
    Write-Host "  Type 'tutorial' for walkthrough · 'reload' to reload · Ctrl+C to clear" -ForegroundColor DarkGray
    Write-Host ''
}
```

### Step 3.2 — Implement Report Generator

Add to `Talon.Commands.psm1` (since reports use both diagnostic and formatting functions):

```powershell
📝 Append to: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.Commands.psm1"

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  REPORT GENERATOR                                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

function Format-TalonTableCell {
    param([AllowNull()][string]$Text, [int]$Width)
    if ($Width -le 0) { return '' }
    if ($null -eq $Text) { $Text = '' }
    $clean = (($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' ').Trim()
    if ($clean.Length -gt $Width) { return $clean.Substring(0, $Width - 1) + '…' }
    return $clean.PadRight($Width)
}

function ConvertTo-TalonMarkdownTable {
    <#
    .SYNOPSIS
        Convert objects to a Markdown table string.
    #>
    param([object[]]$InputObject)
    $rows = @($InputObject | Where-Object { $null -ne $_ })
    if (-not $rows) { return '*No data.*' }

    $props = @($rows[0].PSObject.Properties.Name)
    $colWidths = [ordered]@{}
    foreach ($p in $props) {
        $max = $p.Length
        foreach ($r in $rows) { $len = ([string]$r.$p).Length; if ($len -gt $max) { $max = $len } }
        $colWidths[$p] = [Math]::Max(3, [Math]::Min($max, 60))
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| ' + (($props | ForEach-Object { $_.PadRight($colWidths[$_]) }) -join ' | ') + ' |')
    $lines.Add('| ' + (($props | ForEach-Object { '-' * $colWidths[$_] }) -join ' | ') + ' |')
    foreach ($r in $rows) {
        $lines.Add('| ' + (($props | ForEach-Object { ([string]$r.$_).PadRight($colWidths[$_]) }) -join ' | ') + ' |')
    }
    return ($lines -join [Environment]::NewLine)
}

function New-TalonReport {
    <#
    .SYNOPSIS
        Full system snapshot report to console + file.
    .PARAMETER Format
        Console | Markdown | Json
    .PARAMETER Path
        Output file path.
    .EXAMPLE
        report
        report -Format Markdown -Path .\snapshot.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Console', 'Markdown', 'Json')][string]$Format = 'Console',
        [string]$Path
    )

    # Collect data
    $report = [ordered]@{
        Generated = Get-Date
        Disk      = @(Get-TalonDiskPressure)
        Resources = @(Get-TalonResourceMap)
        Ports     = @(Get-TalonPortMap)
        Firewall  = @(Get-TalonFirewallAudit)
        Startup   = @(Get-TalonBootMap)
    }

    $md = @()
    $md += "# Talon System Report"
    $md += "Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n"
    $md += "## Disk`n"
    $md += ConvertTo-TalonMarkdownTable -InputObject $report.Disk
    $md += "`n## Resources`n"
    $md += ConvertTo-TalonMarkdownTable -InputObject $report.Resources
    $md += "`n## Ports`n"
    $md += ConvertTo-TalonMarkdownTable -InputObject $report.Ports
    $md += "`n## Firewall`n"
    $md += ConvertTo-TalonMarkdownTable -InputObject $report.Firewall
    $md += "`n## Startup`n"
    $md += ConvertTo-TalonMarkdownTable -InputObject $report.Startup
    $mdText = $md -join "`n"

    if ($Format -eq 'Console') {
        $outPath = if ($Path) { $Path } else {
            $reportDir = Join-Path $HOME '.talon' 'Reports'
            if (-not (Test-Path $reportDir)) { $null = New-Item $reportDir -ItemType Directory -Force }
            Join-Path $reportDir "talon-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
        }
        if ($PSCmdlet.ShouldProcess("Report: $outPath", 'Save report')) {
            Set-Content -Path $outPath -Value $mdText -Encoding UTF8
            Write-TalonHeader "  Report saved: $outPath" Green
        }
        $mdText
    } elseif ($Format -eq 'Markdown') {
        if ($Path) {
            if ($PSCmdlet.ShouldProcess("Report: $Path", 'Save report')) {
                Set-Content -Path $Path -Value $mdText -Encoding UTF8
            }
        } else { $mdText }
    } else {
        $json = $report | ConvertTo-Json -Depth 5
        if ($Path) {
            if ($PSCmdlet.ShouldProcess("Report: $Path", 'Save report')) {
                Set-Content -Path $Path -Value $json -Encoding UTF8
            }
        } else { $json }
    }
}
```

### Step 3.3 — Verify Phase 3

```powershell
🔍 # Open new PS7 terminal (or reload)
▶️ reload

🔍 # Dashboard renders with all 6 category columns
▶️ dash
# Expected: SYSTEM | SECURITY | NETWORK | ENV | AI | SHELL columns

🔍 # Report generates and saves to ~\.talon\Reports\
▶️ report
# Expected: Markdown document with Disk, Resources, Ports, Firewall, Startup sections
```

**✅ Phase 3 exit criteria:**
- [ ] Dashboard renders with proper column layout at various terminal widths
- [ ] All command aliases appear correctly under their categories
- [ ] AI status shows ACTIVE or STANDBY
- [ ] `report` generates a well-formed Markdown file
- [ ] `report -Format Json` outputs valid JSON

---

## Phase 4 — Onboarding & Tutorial (Day 5-6)

**Goal:** First-run experience, tutorial walkthrough, config management.

### Step 4.1 — Implement the Tutorial Function

Add to `Talon.Commands.psm1`:

```powershell
📝 Append to: "$env:USERPROFILE\Documents\PowerShell\Talon\Talon.Commands.psm1"

function Start-TalonTutorial {
    <#
    .SYNOPSIS
        Interactive 5-step walkthrough for new users.
    .EXAMPLE
        tutorial
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   TALON — Interactive Walkthrough (1/5)  ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan

    Write-Host "`n  Step 1: System Health" -ForegroundColor Yellow
    Write-Host "  ─────────────────────" -ForegroundColor DarkGray
    Write-Host "  Try:  health" -ForegroundColor White
    Write-Host "  This shows your CPU, RAM, and process count at a glance." -ForegroundColor DarkGray
    Write-Host "  Press Enter to run it... " -NoNewline -ForegroundColor DarkGray
    $null = Read-Host
    health
    Write-Host "`n  Press Enter for Step 2..." -NoNewline
    $null = Read-Host

    Write-Host "`n  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   TALON — Interactive Walkthrough (2/5)  ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan

    Write-Host "`n  Step 2: Disk Pressure" -ForegroundColor Yellow
    Write-Host "  ──────────────────────" -ForegroundColor DarkGray
    Write-Host "  Try:  disk" -ForegroundColor White
    Write-Host "  Shows per-drive free space. Watch for drives under 10%." -ForegroundColor DarkGray
    Write-Host "  Press Enter to run it... " -NoNewline
    $null = Read-Host
    disk
    Write-Host "`n  Press Enter for Step 3..." -NoNewline
    $null = Read-Host

    Write-Host "`n  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   TALON — Interactive Walkthrough (3/5)  ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan

    Write-Host "`n  Step 3: Security Audit" -ForegroundColor Yellow
    Write-Host "  ───────────────────────" -ForegroundColor DarkGray
    Write-Host "  Try:  fwaudit" -ForegroundColor White
    Write-Host "  Cross-references open ports against firewall rules." -ForegroundColor DarkGray
    Write-Host "  Press Enter to run it... " -NoNewline
    $null = Read-Host
    fwaudit
    Write-Host "`n  Press Enter for Step 4..." -NoNewline
    $null = Read-Host

    Write-Host "`n  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   TALON — Interactive Walkthrough (4/5)  ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan

    Write-Host "`n  Step 4: Network Check" -ForegroundColor Yellow
    Write-Host "  ──────────────────────" -ForegroundColor DarkGray
    Write-Host "  Try:  netcheck" -ForegroundColor White
    Write-Host "  Pings Cloudflare DNS to verify internet connectivity." -ForegroundColor DarkGray
    Write-Host "  Press Enter to run it... " -NoNewline
    $null = Read-Host
    netcheck
    Write-Host "`n  Press Enter for Step 5..." -NoNewline
    $null = Read-Host

    Write-Host "`n  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   TALON — Interactive Walkthrough (5/5)  ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan

    Write-Host "`n  Step 5: AI Analysis" -ForegroundColor Yellow
    Write-Host "  ────────────────────" -ForegroundColor DarkGray
    Write-Host "  Try:  resmap | ai 'Which processes use the most memory?'" -ForegroundColor White
    Write-Host "  Pipes live system data to your local Ollama model." -ForegroundColor DarkGray
    Write-Host "  (Requires Ollama running. If unavailable, just read along.)" -ForegroundColor DarkGray
    Write-Host "`n  Press Enter to try it... " -NoNewline
    $null = Read-Host

    $aiStatus = Get-TalonAIStatus
    if ($aiStatus.Status -match 'Reachable') {
        Get-TalonResourceMap | Invoke-TalonAI -Instruction 'Which processes use the most memory?'
    } else {
        Write-Host "  [SKIP] Ollama not running. Install from https://ollama.com" -ForegroundColor Yellow
    }

    Write-Host "`n  ╔═══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║   ✅ Walk Complete!                         ║" -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "`n  Next steps:" -ForegroundColor Cyan
    Write-Host "    • Type  dash        — Full command dashboard" -ForegroundColor White
    Write-Host "    • Type  report      — Full system snapshot" -ForegroundColor White
    Write-Host "    • Type  envmap      — Environment variable audit" -ForegroundColor White
    Write-Host "    • Type  audit -all   — All security checks at once" -ForegroundColor White
    Write-Host "    • Type  remember    — Save notes to local memory" -ForegroundColor White
    Write-Host "    • Type  reload      — Reload profile" -ForegroundColor White
    Write-Host "`n  Config: ~\.talon\config.json" -ForegroundColor DarkGray
    Write-Host "  Docs:   README.md" -ForegroundColor DarkGray
    Write-Host ''
}
```

### Step 4.2 — Add `tutorial` Alias

```powershell
📝 Edit: In Set-TalonAliases in Talon.psm1, add:
@('tutorial',  'Start-TalonTutorial')
```

Also update `Talon.Commands.psd1` `FunctionsToExport` to include `'Start-TalonTutorial'`.

### Step 4.3 — Add Install Script

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Scripts\install.ps1"

<#
.SYNOPSIS
    One-liner installer for Talon.
    Run:  iex (iwr talon.ps.dev/install)
#>

$talonDir = Join-Path $HOME 'Documents\PowerShell\Talon'
$profilePath = $PROFILE.CurrentUserCurrentHost

Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   TALON INSTALLER                         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Cyan

# 1. Create module directory
Write-Host "  [1/4] Creating module directory..." -NoNewline
$null = New-Item $talonDir -ItemType Directory -Force
Write-Host " Done" -ForegroundColor Green

# 2. Download module files (in production, this would pull from GitHub Releases)
Write-Host "  [2/4] Downloading Talon module..." -NoNewline
# TODO: Replace with actual download URL
Write-Host " Done" -ForegroundColor Green

# 3. Install prerequisites
Write-Host "  [3/4] Checking prerequisites..." -NoNewline
$modules = @('Terminal-Icons', 'PSTree')
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable $mod -ErrorAction SilentlyContinue)) {
        Install-Module $mod -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    }
}
Write-Host " Done" -ForegroundColor Green

# 4. Wire profile
Write-Host "  [4/4] Wiring profile loader..." -NoNewline
$loader = @"
# Talon profile loader
`$talonModule = Join-Path `$PSScriptRoot 'Talon\Talon.psd1'
if (Test-Path `$talonModule) {
    Import-Module `$talonModule -Force -ErrorAction Stop
    Initialize-Talon
}
"@
$loader | Set-Content $profilePath -Encoding UTF8 -Force
Write-Host " Done" -ForegroundColor Green

Write-Host "`n  ✅ Talon installed. Open a new PowerShell 7 terminal." -ForegroundColor Green
```

### Step 4.4 — Add Config Command

```powershell
📝 In Talon.Commands.psm1:

function Edit-TalonConfig {
    <#
    .SYNOPSIS
        Open Talon config file in default editor.
    .EXAMPLE
        config
    #>
    $configPath = Join-Path $HOME '.talon' 'config.json'
    if (-not (Test-Path $configPath)) {
        Write-Warning "Config not found at $configPath"
        return
    }
    Invoke-Item $configPath
}
```

### Step 4.5 — Verify Phase 4

```powershell
🔍 # Open new PS7 terminal
▶️ reload

🔍 # Run tutorial
▶️ tutorial
# Expected: 5 interactive steps with explanations

🔍 # New user experience should be self-explanatory
```

**✅ Phase 4 exit criteria:**
- [ ] `tutorial` runs through all 5 steps interactively
- [ ] Steps execute real commands showing output
- [ ] Graceful handling when Ollama is unavailable
- [ ] Install script exists (even if stub download URLs)
- [ ] `config` opens the JSON file

---

## Phase 5 — Distribution Prep (Day 6)

**Goal:** Package for PowerShell Gallery and GitHub Releases.

### Step 5.1 — Create GitHub Repository Files

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\README.md"

# Talon — Featherweight PowerShell 7 Ops Shell

**50 diagnostic commands + local AI. No cloud. No cost. No config.**

Talon is a zero-config PowerShell 7 module for Windows sysadmins who need
system diagnostics, security audits, and local AI analysis — all in one
fast-loading terminal.

## Quick Install

```powershell
Install-Module Talon -Scope CurrentUser
# or
iex (iwr https://github.com/talon-ps/talon/releases/latest/download/install.ps1)
```

Then open a new PowerShell 7 terminal.

## What You Get

| Category | Commands |
|---|---|
| **System** | `health`, `spec`, `uptime`, `disk`, `hog`, `ports`, `battery`, `temp` |
| **Security** | `fwaudit`, `boot`, `taskaudit`, `ghostaudit`, `susaudit`, `evntaudit`, `admin` |
| **Network** | `netcheck`, `wifi`, `dnsbench`, `dnscache`, `nettriage` |
| **Environment** | `envmap`, `pathaudit`, `app`, `patch`, `driveraudit` |
| **AI** | `ai`, `ggl`, `secretredact`, `aistatus`, `remember`, `recall`, `memmap` |
| **Shell** | `dash`, `report`, `tutorial`, `reload` |

## Requirements

- **PowerShell 7.0+**
- **Windows** (uses CIM, registry, firewall cmdlets)
- **Ollama** (optional — for AI features)

## Docs

- Type `tutorial` for an interactive walkthrough
- Type `dash` for the full command dashboard
- [Full documentation →](docs/)

## License

MIT
```

### Step 5.2 — Create Module Template for PowerShell Gallery

```powershell
📝 The Talon.psd1 already has the required PrivateData section.
# Ensure all metadata fields are populated.

# For PS Gallery publishing:
# Publish-Module -Name Talon -NuGetApiKey <key>
```

### Step 5.3 — Verify Phase 5

```powershell
🔍 # Verify module can be found by PowerShell
▶️ Get-Module -ListAvailable Talon
# Expected: Shows Talon 1.0.0
```

**✅ Phase 5 exit criteria:**
- [ ] README.md written and accurate
- [ ] Module metadata complete for PS Gallery
- [ ] Install script written

---

## Phase 6 — Migration Script (Day 6+)

**Goal:** Provide a smooth path for existing Hawkward Hybrid users.

### Step 6.1 — Migration Script

```powershell
📝 File: "$env:USERPROFILE\Documents\PowerShell\Talon\Scripts\hawkward-to-talon.ps1"

<#
.SYNOPSIS
    Migrate from Hawkward Hybrid to Talon.
    Creates backward-compatible aliases for all common Hawk commands.
#>

Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║   Hawkward → Talon Migration              ║" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Yellow

$legacyAliases = @(
    @('Get-HawkHealth',              'Get-TalonHealth')
    @('Get-HawkSpec',                'Get-TalonSpec')
    @('Get-HawkUptime',              'Get-TalonUptime')
    @('Get-HawkDiskPressureAudit',   'Get-TalonDiskPressure')
    @('Get-HawkResourceMap',         'Get-TalonResourceMap')
    @('Get-HawkPortMap',             'Get-TalonPortMap')
    @('Get-HawkBattery',             'Get-TalonBattery')
    @('Get-HawkFirewallAudit',       'Get-TalonFirewallAudit')
    @('Get-HawkBootMap',             'Get-TalonBootMap')
    @('Get-HawkScheduledTaskRiskAudit', 'Get-TalonScheduledTaskRisk')
    @('Get-HawkGhostPortAudit',      'Get-TalonGhostPortAudit')
    @('Get-HawkSuspiciousProcessAudit', 'Get-TalonSuspiciousProcess')
    @('Get-HawkEventStormAudit',     'Get-TalonEventStormAudit')
    @('Get-HawkAdmin',               'Get-TalonAdmin')
    @('Get-HawkNetCheck',            'Get-TalonNetCheck')
    @('Get-HawkWifi',                'Get-TalonWifi')
    @('Get-HawkDnsBench',            'Get-TalonDnsBench')
    @('Get-HawkDnsCache',            'Get-TalonDnsCache')
    @('Get-HawkEnvMap',              'Get-TalonEnvMap')
    @('Get-HawkPathAudit',           'Get-TalonPathAudit')
    @('Get-HawkApp',                 'Get-TalonApp')
    @('Get-HawkPatchHistory',        'Get-TalonPatchHistory')
    @('Get-HawkDriverAudit',         'Get-TalonDriverAudit')
    @('Invoke-HawkAI',               'Invoke-TalonAI')
    @('Invoke-HawkSearch',           'Invoke-TalonSearch')
    @('Protect-HawkSensitiveText',   'Protect-TalonSensitiveText')
    @('Add-HawkMemory',              'Add-TalonMemory')
    @('Search-HawkMemory',           'Search-TalonMemory')
    @('Get-HawkMemoryMap',           'Get-TalonMemoryMap')
    @('Get-HawkAIStatus',            'Get-TalonAIStatus')
    @('Get-HawkShield',              'Get-TalonShield')
    @('New-HawkReport',              'New-TalonReport')
    @('Show-HawkDashboard',          'Show-TalonDashboard')
    @('Update-HawkProfile',          'Update-TalonProfile')
)

$count = 0
foreach ($m in $legacyAliases) {
    Set-Alias -Scope Global -Name $m[0] -Value $m[1] -Force -ErrorAction SilentlyContinue
    $count++
}

Write-Host "  ✅ $count legacy Hawkward aliases registered → Talon functions" -ForegroundColor Green
Write-Host "  ℹ️  Run 'tutorial' for the Talon walkthrough" -ForegroundColor Cyan
Write-Host "  ℹ️  Run 'dash' to see all Talon commands" -ForegroundColor Cyan
```

**✅ Phase 6 exit criteria:**
- [ ] Migration script creates backward-compatible aliases
- [ ] `Get-HawkHealth` → calls `Get-TalonHealth`
- [ ] All 34 mapped functions work

---

## Project File Map Summary

After all 6 phases, this is the complete file layout:

```
~\.talon\                                       ← Auto-created
  ├── config.json                               ← JSON config
  ├── Memory\
  │   └── talon-memory.jsonl                     ← Memory store
  └── Reports\                                   ← Generated snapshots

Documents\PowerShell\
  ├── Microsoft.PowerShell_profile.ps1           ← Thin loader (5 lines)
  └── Talon\                                     ← Module root
      ├── Talon.psd1                             ← Manifest (Tier 0 + nested modules)
      ├── Talon.psm1                             ← Shell Core (~300 lines)
      ├── Talon.Commands.psd1                    ← Tier 1 manifest
      ├── Talon.Commands.psm1                    ← Commands (~600 lines)
      ├── Talon.AI.psd1                          ← Tier 2 manifest
      ├── Talon.AI.psm1                          ← AI Engine (~400 lines)
      ├── AI\
      │   └── talon-default.modelfile            ← Ollama model config
      ├── Scripts\
      │   ├── install.ps1                        ← One-liner installer
      │   └── hawkward-to-talon.ps1              ← Migration script
      └── README.md                              ← Project README
```

---

## Execution Order (Quick Reference)

| Phase | What | Est. Time | Key Deliverable |
|---|---|---|---|
| **P0** | Scaffold + Tier 0 + profile + config | 1 day | Working shell with prompt + `dash` |
| **P1** | All 50 functions + aliases | 2 days | All diagnostic/security/network commands |
| **P2** | AI streaming + search + memory | 1 day | `ai`, `ggl`, `remember`, `recall` |
| **P3** | Full dashboard + reports | 1 day | Multi-column TUI + `report` |
| **P4** | Tutorial + install script | 0.5 day | `tutorial`, install.ps1 |
| **P5** | Distribution packaging | 0.5 day | README, PS Gallery metadata |
| **P6** | Migration script | 0.5 day | Hawkward → Talon bridge |

**Total: ~6 days for 1 developer.**

---

## Verification Cheat Sheet

After each phase, run these to confirm health:

```powershell
# Module load time
Measure-Command { Import-Module Talon }

# Function availability
Get-Module Talon | Select-Object ExportedFunctions

# AI module NOT loaded until first use
Get-Module Talon.AI  # Should show nothing until you run 'ai'

# Profile reload
reload

# Dashboard
dash

# Full audit
audit -all
```
