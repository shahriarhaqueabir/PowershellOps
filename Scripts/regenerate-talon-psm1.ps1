# ── Regenerate Talon.psm1 cleanly (fix ShouldProcess issue) ────
$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"

$content = @'
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

# ── INTERACTIVITY DETECTION ─────────────────────────────────────────────────

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
    [CmdletBinding()]
    param()
    if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
        Set-Item -Path Function:\global:Prompt -Value {
            Get-TalonPromptText -LastSuccess:$?
        }
    }
}

# ── READLINE ───────────────────────────────────────────────────────────────

function Set-TalonReadLine {
    <#
    .SYNOPSIS
        Configure PSReadLine for history prediction.
    #>
    [CmdletBinding()]
    param()
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) { return }
    try {
        Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
    } catch { Write-Warning "PSReadLine configuration failed: $($_.Exception.Message)" }
}

# ── ALIAS SYSTEM ───────────────────────────────────────────────────────────

function Set-TalonAliases {
    <#
    .SYNOPSIS
        Register all short aliases. Called once at startup.
    #>
    [CmdletBinding()]
    param()

    $mappings = @(
        @('health',    'Get-TalonHealth')
        @('spec',      'Get-TalonSpec')
        @('uptime',    'Get-TalonUptime')
        @('disk',      'Get-TalonDiskPressure')
        @('hog',       'Get-TalonResourceMap')
        @('ports',     'Get-TalonPortMap')
        @('battery',   'Get-TalonBattery')
        @('temp',      'Get-TalonTempCheck')
        @('fwaudit',   'Get-TalonFirewallAudit')
        @('boot',      'Get-TalonBootMap')
        @('taskaudit', 'Get-TalonScheduledTaskRisk')
        @('ghostaudit','Get-TalonGhostPortAudit')
        @('susaudit',  'Get-TalonSuspiciousProcess')
        @('evntaudit', 'Get-TalonEventStormAudit')
        @('admin',     'Get-TalonAdmin')
        @('netcheck',  'Get-TalonNetCheck')
        @('wifi',      'Get-TalonWifi')
        @('dnsbench',  'Get-TalonDnsBench')
        @('dnscache',  'Get-TalonDnsCache')
        @('nettriage', 'Get-TalonNetworkTriage')
        @('envmap',    'Get-TalonEnvMap')
        @('pathaudit', 'Get-TalonPathAudit')
        @('app',       'Get-TalonApp')
        @('patch',     'Get-TalonPatchHistory')
        @('driveraudit','Get-TalonDriverAudit')
        @('ai',         'Invoke-TalonAI')
        @('ggl',        'Invoke-TalonSearch')
        @('secretredact','Protect-TalonSensitiveText')
        @('aistatus',   'Get-TalonAIStatus')
        @('injecttest', 'Test-TalonPromptInjection')
        @('quality',    'Get-TalonSourceQuality')
        @('remember',  'Add-TalonMemory')
        @('recall',    'Search-TalonMemory')
        @('memmap',    'Get-TalonMemoryMap')
        @('report',    'New-TalonReport')
        @('dash',      'Show-TalonDashboard')
        @('reload',    'Update-TalonProfile')
        @('shield',    'Get-TalonShield')
        @('certs',     'Get-TalonCertCheck')
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
    [CmdletBinding()]
    param()
    . $PROFILE
}

# ── DASHBOARD ──────────────────────────────────────────────────────────────

function Show-TalonDashboard {
    <#
    .SYNOPSIS
        TUI dashboard with category columns, lazy-rendered.
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
    Write-Host "  │  TALON $($script:TalonVersion)" -ForegroundColor Cyan
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
    .PARAMETER ProjectRoot
        Default project workspace root.
    .PARAMETER DashboardEnabled
        Show dashboard on startup (respects $env:TALON_NO_DASH).
    #>
    [CmdletBinding()]
    param(
        [string]$ProjectRoot,
        [switch]$DashboardEnabled
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $config = Get-TalonConfig
    if ($ProjectRoot) { $config['projectRoot'] = $ProjectRoot }

    Set-TalonReadLine
    Set-TalonAliases
    Set-TalonPrompt

    $showDash = if ($PSBoundParameters.ContainsKey('DashboardEnabled')) { $DashboardEnabled } else { $config['dashboardEnabled'] }
    if ($showDash -and (Test-InteractiveSession)) {
        Show-TalonDashboard
        if ($config['dashboardDismissSec'] -gt 0 -and -not $env:TALON_NO_DASH) {
            Start-Sleep -Seconds $config['dashboardDismissSec']
        }
    }
}
'@

$content | Set-Content (Join-Path $talonDir 'Talon.psm1') -Encoding UTF8 -Force
Write-Host "Regenerated Talon.psm1 cleanly."
