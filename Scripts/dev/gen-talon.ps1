# ── Talon v1 — Phase 0 Generator ──────────────────────────────────────────
# Creates: Talon.psd1, Talon.psm1, config.json, profile loader, modelfile
# Run: pwsh -NoProfile -File gen-talon.ps1

$talonDir   = "$HOME\Documents\PowerShell\Talon"
$configDir  = "$HOME\.talon"
$profileDir = "$HOME\Documents\PowerShell"

# Ensure directories
foreach ($d in @($talonDir, (Join-Path $talonDir 'AI'), (Join-Path $talonDir 'Scripts'), $configDir)) {
    $null = New-Item $d -ItemType Directory -Force
}

# ═══════════════════════════════════════════════════════════════════════════
# 1. Talon.psd1 — Root Module Manifest (written as text)
# ═══════════════════════════════════════════════════════════════════════════
$manifest = @'
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
        'Initialize-Talon',
        'Set-TalonPrompt',
        'Set-TalonAliases',
        'Update-TalonProfile',
        'Test-InteractiveSession',
        'Show-TalonDashboard',
        'Invoke-TalonCachedData',
        'Write-TalonHeader'
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
Set-Content -Path (Join-Path $talonDir 'Talon.psd1') -Value $manifest -Encoding UTF8
Write-Host '✓ Talon.psd1'

# ═══════════════════════════════════════════════════════════════════════════
# 2. Talon.psm1 — Shell Core (Tier 0)
# ═══════════════════════════════════════════════════════════════════════════
$core = @'
# ── Talon v1 — Shell Core (Tier 0) ──────────────────────────────────────────
# Loads on every session. Must complete in <200ms.
# Everything else — commands, AI — is lazy-loaded via nested modules.

# Script-scoped state (not global)
$script:TalonVersion = '1.0.0'
$script:TalonConfigPath = Join-Path $HOME '.talon' 'config.json'
$script:TalonCacheStore = [hashtable]::Synchronized(@{})
$script:TalonSuppressHeaders = $false
$script:TalonConfig = $null

# ── CONFIGURATION ────────────────────────────────────────────────────────────

function Get-TalonConfig {
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
                    foreach ($subKey in $userConfig[$key].Keys) { $defaults[$key][$subKey] = $userConfig[$key][$subKey] }
                } else { $defaults[$key] = $userConfig[$key] }
            }
        } catch { Write-Verbose "Talon config parse failed: $($_.Exception.Message)" }
    }
    if ($env:TALON_PROJECT_ROOT)    { $defaults['projectRoot'] = $env:TALON_PROJECT_ROOT }
    if ($env:TALON_NO_DASH)         { $defaults['dashboardEnabled'] = $false }
    if ($env:TALON_OLLAMA_ENDPOINT) { $defaults['ollama']['endpoint'] = $env:TALON_OLLAMA_ENDPOINT }
    $script:TalonConfig = $defaults
    return $defaults
}

# ── CACHE ENGINE ────────────────────────────────────────────────────────────

function Invoke-TalonCachedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][int]$ExpirySeconds,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )
    $now = Get-Date
    if ($script:TalonCacheStore.ContainsKey($Key)) {
        $entry = $script:TalonCacheStore[$Key]
        if (($now - $entry.Timestamp).TotalSeconds -lt $ExpirySeconds) { return $entry.Value }
    }
    $computedValue = &$ScriptBlock
    $script:TalonCacheStore[$Key] = @{ Timestamp = $now; Value = $computedValue }
    return $computedValue
}

# ── OUTPUT HELPERS ──────────────────────────────────────────────────────────

function Write-TalonHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message, [ConsoleColor]$Color = 'Cyan')
    if (-not $script:TalonSuppressHeaders) { Write-Host $Message -ForegroundColor $Color }
}

# ── INTERACTIVITY DETECTION ────────────────────────────────────────────────

function Test-InteractiveSession {
    if ($env:TALON_CI -or $env:CI) { return $false }
    try { return [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected } catch { return $false }
}

# ── PROMPT SYSTEM ──────────────────────────────────────────────────────────

function Get-TalonPromptGitSegment {
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
    param([bool]$LastSuccess = $true)
    $esc = [char]27; $reset = "${esc}[0m"
    $path = (Get-Location).Path -replace "^$([Regex]::Escape([Environment]::GetFolderPath('UserProfile')))", '~'
    $pathSegment = "${esc}[38;5;239m${esc}[38;5;255m $path ${reset}"
    $timeSegment = "${esc}[38;5;24m${esc}[38;5;117m $(Get-Date -Format 'HH:mm:ss') ${reset}"
    $gitSegment = Get-TalonPromptGitSegment -Reset $reset
    $statusColor = if ($LastSuccess) { "${esc}[38;5;121m" } else { "${esc}[38;5;196m}" }
    return "`n${pathSegment}${timeSegment}${gitSegment}`n${statusColor}> ${reset}"
}

function Set-TalonPrompt {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('global:prompt', 'Set custom prompt function')) {
        if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
            Set-Item -Path Function:\global:Prompt -Value { Get-TalonPromptText -LastSuccess:$? }
        }
    }
}

# ── READLINE ───────────────────────────────────────────────────────────────

function Set-TalonReadLine {
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
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Global aliases', 'Set all Talon aliases')) { return }
    $mappings = @(
        @('health','Get-TalonHealth'), @('spec','Get-TalonSpec'), @('uptime','Get-TalonUptime'),
        @('disk','Get-TalonDiskPressure'), @('hog','Get-TalonResourceMap'), @('ports','Get-TalonPortMap'),
        @('battery','Get-TalonBattery'), @('temp','Get-TalonTempCheck'),
        @('fwaudit','Get-TalonFirewallAudit'), @('boot','Get-TalonBootMap'),
        @('taskaudit','Get-TalonScheduledTaskRisk'), @('ghostaudit','Get-TalonGhostPortAudit'),
        @('susaudit','Get-TalonSuspiciousProcess'), @('evntaudit','Get-TalonEventStormAudit'),
        @('admin','Get-TalonAdmin'),
        @('netcheck','Get-TalonNetCheck'), @('wifi','Get-TalonWifi'),
        @('dnsbench','Get-TalonDnsBench'), @('dnscache','Get-TalonDnsCache'),
        @('nettriage','Get-TalonNetworkTriage'),
        @('envmap','Get-TalonEnvMap'), @('pathaudit','Get-TalonPathAudit'),
        @('app','Get-TalonApp'), @('patch','Get-TalonPatchHistory'), @('driveraudit','Get-TalonDriverAudit'),
        @('ai','Invoke-TalonAI'), @('ggl','Invoke-TalonSearch'),
        @('secretredact','Protect-TalonSensitiveText'), @('aistatus','Get-TalonAIStatus'),
        @('injecttest','Test-TalonPromptInjection'), @('quality','Get-TalonSourceQuality'),
        @('remember','Add-TalonMemory'), @('recall','Search-TalonMemory'), @('memmap','Get-TalonMemoryMap'),
        @('report','New-TalonReport'), @('dash','Show-TalonDashboard'), @('reload','Update-TalonProfile'),
        @('shield','Get-TalonShield'), @('certs','Get-TalonCertCheck'),
        @('tutorial','Start-TalonTutorial'), @('config','Edit-TalonConfig'),
        @('sys','Get-TalonSystem'), @('audit','Get-TalonAudit'), @('net','Get-TalonNetwork'), @('env','Get-TalonEnv')
    )
    foreach ($m in $mappings) { Set-Alias -Scope Global -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force }
}

# ── PROFILE RELOAD ─────────────────────────────────────────────────────────

function Update-TalonProfile {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('$PROFILE', 'Dot-source profile')) { . $PROFILE }
}

# ── DASHBOARD ─────────────────────────────────────────────────────────────

function Show-TalonDashboard {
    [CmdletBinding()]
    param()
    $config = Get-TalonConfig
    $aiStatus = 'STANDBY'
    try { $null = Invoke-RestMethod -Uri "$($config['ollama']['endpoint'])/api/tags" -TimeoutSec 2 -ErrorAction Stop; $aiStatus = 'ACTIVE' } catch {}
    $cWidth = try { [Console]::WindowWidth } catch { 120 }
    $rule = '─' * [Math]::Max(78, [Math]::Min(($cWidth - 2), 150))
    Write-Host "`n  ╭$rule╮" -ForegroundColor DarkGray
    Write-Host "  │  TALON $($script:TalonVersion) — All Commands" -ForegroundColor Cyan
    Write-Host "  │  AI: $aiStatus" -ForegroundColor DarkGray
    Write-Host "  ╰$rule╯" -ForegroundColor DarkGray
    Write-Host "  Type 'tutorial' for a walkthrough. Type 'dash' to redraw." -ForegroundColor DarkGray
    Write-Host ''
}

# ── INITIALIZATION ────────────────────────────────────────────────────────

function Initialize-Talon {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$ProjectRoot, [switch]$DashboardEnabled)
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $config = Get-TalonConfig
    if ($ProjectRoot) { $config['projectRoot'] = $ProjectRoot }
    Set-TalonReadLine; Set-TalonAliases; Set-TalonPrompt
    $showDash = if ($PSBoundParameters.ContainsKey('DashboardEnabled')) { $DashboardEnabled } else { $config['dashboardEnabled'] }
    if ($showDash -and (Test-InteractiveSession)) {
        Show-TalonDashboard
        if ($config['dashboardDismissSec'] -gt 0 -and -not $env:TALON_NO_DASH) { Start-Sleep -Seconds $config['dashboardDismissSec'] }
    }
}
'@
Set-Content -Path (Join-Path $talonDir 'Talon.psm1') -Value $core -Encoding UTF8
Write-Host '✓ Talon.psm1'

# ═══════════════════════════════════════════════════════════════════════════
# 3. config.json — Default Configuration
# ═══════════════════════════════════════════════════════════════════════════
$defaultConfig = @{
    version              = '1'
    theme                = 'auto'
    dashboardEnabled     = $true
    dashboardDismissSec  = 2
    ollama = @{ endpoint = 'http://127.0.0.1:11434'; model = 'talon-default'; contextSize = 8192; timeoutSec = 120 }
    modules = @{ system = $true; security = $true; network = $true; ai = $true }
    gitPromptCacheMs = 2000; suppressBranding = $false
}
$defaultConfig | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $configDir 'config.json') -Encoding UTF8
Write-Host '✓ config.json'

# ═══════════════════════════════════════════════════════════════════════════
# 4. Profile Loader
# ═══════════════════════════════════════════════════════════════════════════
$loader = @'
# Talon v1 — Profile Loader
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$talonModule = Join-Path $PSScriptRoot 'Talon\Talon.psd1'
if (Test-Path $talonModule) { Import-Module $talonModule -Force -ErrorAction Stop; Initialize-Talon }
else { Write-Warning "Talon module not found at: $talonModule" }
'@
Set-Content -Path (Join-Path $profileDir 'Microsoft.PowerShell_profile.ps1') -Value $loader -Encoding UTF8
Write-Host '✓ profile loader'

# ═══════════════════════════════════════════════════════════════════════════
# 5. Modelfile
# ═══════════════════════════════════════════════════════════════════════════
$model = @'
FROM qwen3:4b
PARAMETER temperature 0.2
PARAMETER top_p 0.85
PARAMETER top_k 20
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 8192
SYSTEM """You are Talon AI, a concise terminal assistant for PowerShell 7 on Windows. Answer with PowerShell 7 syntax by default. Put the command first when the user asks how to do something. Prefer native PowerShell cmdlets over Bash, CMD, or external tools. Be concise: short bullets, minimal explanation, practical examples. Do not show hidden reasoning or chain-of-thought. For simple command requests, output only the command. Tone: professional, efficient, slightly witty."""
'@
Set-Content -Path (Join-Path $talonDir 'AI\talon-default.modelfile') -Value $model -Encoding UTF8
Write-Host '✓ modelfile'

# ═══════════════════════════════════════════════════════════════════════════
# 6. Install Script (stub)
# ═══════════════════════════════════════════════════════════════════════════
$install = @'
param([switch]$Force)
$talonDir = Join-Path $HOME 'Documents\PowerShell\Talon'
$profilePath = $PROFILE.CurrentUserCurrentHost
Write-Host "Talon Installer" -ForegroundColor Cyan
$null = New-Item $talonDir -ItemType Directory -Force
# TODO: download from GitHub Releases
Write-Host "Installing prerequisites..."
foreach ($mod in @('Terminal-Icons','PSTree')) {
    if (-not (Get-Module -ListAvailable $mod -ErrorAction SilentlyContinue)) { Install-Module $mod -Scope CurrentUser -Force -ErrorAction SilentlyContinue }
}
# Wire profile loader
$loader = "# Talon`n`$talonModule = Join-Path `$PSScriptRoot 'Talon\Talon.psd1'`nif (Test-Path `$talonModule) { Import-Module `$talonModule -Force -ErrorAction Stop; Initialize-Talon }"
$loader | Set-Content $profilePath -Encoding UTF8 -Force
Write-Host "Done. Open new PowerShell 7 terminal." -ForegroundColor Green
'@
Set-Content -Path (Join-Path $talonDir 'Scripts\install.ps1') -Value $install -Encoding UTF8
Write-Host '✓ install.ps1'
Write-Host "`n✅ Phase 0 complete."
