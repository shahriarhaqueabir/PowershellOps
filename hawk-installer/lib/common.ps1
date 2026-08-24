# common.ps1 — logging, staging-root resolution, and step-status helpers.
# Dot-sourced by install.ps1 and the step scripts. Every target path must be
# resolved through Get-HawkTargetPath so a staging run never touches the real
# install.

# --- State ---
$script:HawkScriptRoot   = Split-Path -Parent $PSScriptRoot          # hawk-installer/
$script:HawkStagingRoot  = $null                                     # set via -StagingRoot
$script:HawkLogPath      = $null
$script:HawkStepResults  = [System.Collections.Generic.List[object]]::new()

# --- Logging ---

function Write-HawkLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP')][string]$Level = 'INFO'
    )
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$stamp] [$Level] $Message"
    if ($script:HawkLogPath) {
        Add-Content -LiteralPath $script:HawkLogPath -Value $line -Encoding UTF8
    }
    switch ($Level) {
        'OK'    { Write-Host "  $Message" -ForegroundColor Green }
        'WARN'  { Write-Host "  $Message" -ForegroundColor Yellow }
        'ERROR' { Write-Host "  $Message" -ForegroundColor Red }
        'STEP'  { Write-Host "`n== $Message" -ForegroundColor Cyan }
        default { Write-Host "  $Message" }
    }
}

function Initialize-HawkLog {
    param([string]$Path)
    if (-not $Path) {
        $Path = if ($script:HawkStagingRoot) {
            Join-Path $script:HawkStagingRoot 'hawk-install.log'
        } else {
            Join-Path $env:TEMP "hawk-install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        }
    }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $script:HawkLogPath = $Path
    Write-HawkLog "Hawk installer log started" 'INFO'
    return $Path
}

# --- Staging root ---

function Set-HawkStagingRoot {
    param([string]$Path)
    if ($Path) {
        $script:HawkStagingRoot = [System.IO.Path]::GetFullPath($Path)
        New-Item -ItemType Directory -Path $script:HawkStagingRoot -Force | Out-Null
        $env:HAWK_CONFIG_PATH = Join-Path (Get-HawkHome) 'hawk.config.json'
    } else {
        Remove-Item Env:\HAWK_CONFIG_PATH -ErrorAction SilentlyContinue
    }
}

# The PS7 home directory: Documents\PowerShell normally, or <staging>\PowerShell
# when a staging root is active.
function Get-HawkHome {
    if ($script:HawkStagingRoot) {
        return Join-Path $script:HawkStagingRoot 'PowerShell'
    }
    return Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
}

# Resolve a logical target path against the staging root when one is active.
function Get-HawkTargetPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ModulesDir', 'LegacyModule', 'HybridModuleDir', 'Profile', 'Config', 'Log')]
        [string]$Kind
    )
    $hawkHome = Get-HawkHome
    switch ($Kind) {
        'ModulesDir'      { return Join-Path $hawkHome 'Modules' }
        'LegacyModule'    { return Join-Path $hawkHome 'HawkProfile\HawkModules.psm1' }
        'HybridModuleDir' { return Join-Path $hawkHome 'Modules\HawkwardHybrid' }
        'Profile'         { return Join-Path $hawkHome 'Microsoft.PowerShell_profile.ps1' }
        'Config'          { return Join-Path $hawkHome 'hawk.config.json' }
        'Log'             { return $script:HawkLogPath }
    }
}

# --- Step status ---

# Returns $true when any Nerd Font family is registered (HKLM or HKCU).
# Used by the wiring + update-check steps. The installed module keeps its own
# self-contained copy (Test-HawkNerdFont) because it must work without the
# installer present.
function Test-HawkNerdFontPresent {
    foreach ($root in @(
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    )) {
        try {
            $props = Get-ItemProperty -LiteralPath $root -ErrorAction Stop
            # Matches full names ("... Nerd Font") and the common
            # abbreviated registry families ("JetBrainsMono NF", "...NL NF").
            if ($props.PSObject.Properties.Name -match 'Nerd ?Font|JetBrainsMono(NL)? NF\b') { return $true }
        } catch { }
    }
    return $false
}

function Write-HawkStepStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Step,
        [ValidateSet('skip', 'ok', 'failed')][string]$Status,
        [string]$Detail = ''
    )
    $entry = [pscustomobject]@{ Step = $Step; Status = $Status; Detail = $Detail; Time = Get-Date -Format 'HH:mm:ss' }
    $script:HawkStepResults.Add($entry)
    $icon = switch ($Status) { 'skip' { 'SKIP' } 'ok' { 'OK' } 'failed' { 'FAILED' } }
    Write-HawkLog "Step $Step : $icon $Detail" ($(if ($Status -eq 'failed') { 'ERROR' } elseif ($Status -eq 'ok') { 'OK' } else { 'WARN' }))
}

function Get-HawkStepSummary {
    Write-Host "`n========== INSTALL SUMMARY ==========" -ForegroundColor Cyan
    $script:HawkStepResults | ForEach-Object {
        $color = switch ($_.Status) { 'ok' { 'Green' } 'skip' { 'DarkGray' } 'failed' { 'Red' } }
        Write-Host ("  {0,-12} {1,-7} {2}" -f $_.Step, $_.Status.ToUpper(), $_.Detail) -ForegroundColor $color
    }
    $failed = @($script:HawkStepResults | Where-Object { $_.Status -eq 'failed' })
    if ($failed.Count) {
        Write-Host "`n  FAILED steps: $($failed.Step -join ', ')" -ForegroundColor Red
        Write-Host "  Re-run the installer to retry failed steps (completed steps are skipped)." -ForegroundColor Yellow
    } else {
        Write-Host "`n  All steps completed." -ForegroundColor Green
    }
    if ($script:HawkLogPath) { Write-Host "  Full log: $($script:HawkLogPath)" }
}
