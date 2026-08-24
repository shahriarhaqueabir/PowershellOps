# install.ps1 — Hawk portable installer entry point.
#
# Runs from Windows PowerShell 5.1 (the only shell guaranteed on a bare
# Windows box), bootstraps PowerShell 7 if needed, then relaunches itself
# under pwsh with all arguments passed through. The pwsh main body loads the
# step scripts and orchestrates the install.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1            # guided
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Auto      # unattended
#   powershell -ExecutionPolicy Bypass -File install.ps1 -StagingRoot C:\tmp\stage -Auto   # test run
#   irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/hawk-installer/install.ps1 | iex
#
# Piped (irm | iex) invocations have no file on disk, so the script downloads
# the repository bundle to %TEMP%, extracts it, and relaunches itself with
# -File so sibling scripts resolve normally.

param(
    [switch]$Auto,
    [switch]$Uninstall,
    [switch]$Update,
    [switch]$RemoveEngines,
    [switch]$RemoveModel,
    [switch]$Force,
    [string]$StagingRoot,
    [string]$HfHome,
    [string]$ProjectRoot,
    [int]$LlamaPort = 8081
)

# Process-scope execution policy bypass so the script and everything it
# invokes runs regardless of machine/user policy (Restricted, RemoteSigned
# blocking downloaded files, etc.).
Set-ExecutionPolicy -Scope Process Bypass -Force -ErrorAction SilentlyContinue

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue

# ============================================================================
# Piped-invocation guard (irm ... | iex): there is no file on disk, so
# $MyInvocation.MyCommand.Path is null and sibling scripts cannot be resolved.
# Materialize the repository bundle to %TEMP% and relaunch with -File.
# ============================================================================
if (-not $scriptDir) {
    $ErrorActionPreference = 'Stop'
    Write-Host "Piped invocation detected (irm ... | iex). Downloading installer bundle..." -ForegroundColor Cyan
    $tmpRoot   = Join-Path ([System.IO.Path]::GetTempPath()) "hawk-install-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $bundleZip = "$tmpRoot.zip"
    $bundleUrl = 'https://github.com/shahriarhaqueabir/PowershellOps/archive/refs/heads/main.zip'
    Invoke-WebRequest -Uri $bundleUrl -OutFile $bundleZip -UseBasicParsing
    Expand-Archive -LiteralPath $bundleZip -DestinationPath $tmpRoot -Force
    Remove-Item -LiteralPath $bundleZip -Force
    # GitHub archives extract to a single top-level folder (e.g. PowershellOps-main).
    $repoRoot  = Get-ChildItem -LiteralPath $tmpRoot -Directory | Select-Object -First 1
    $scriptDir = Join-Path $repoRoot.FullName 'hawk-installer'
    if (-not (Test-Path -LiteralPath (Join-Path $scriptDir 'install.ps1'))) {
        throw "Materialized bundle is missing hawk-installer\install.ps1 (extracted to '$tmpRoot')."
    }
    Write-Host "Bundle ready: $scriptDir" -ForegroundColor Green

    # Relaunch as a real file so param binding + sibling resolution work,
    # preserving the current engine (powershell.exe bootstrap vs pwsh main body).
    $engine = if ($PSVersionTable.PSVersion.Major -ge 7) { 'pwsh' } else { 'powershell' }
    & $engine -NoLogo -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'install.ps1')
    exit $LASTEXITCODE
}

# ============================================================================
# PS 5.1 bootstrap: ensure pwsh exists, then hand off.
# ============================================================================
if ($PSVersionTable.PSVersion.Major -lt 7) {
    . (Join-Path $scriptDir 'vars.ps1')
    . (Join-Path $scriptDir 'lib\common.ps1')

    Write-Host "PowershellOps installer bootstrap (Windows PowerShell $($PSVersionTable.PSVersion))" -ForegroundColor Cyan

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        Write-Host "PowerShell 7 not found. Installing $($script:HawkPs7Version)..." -ForegroundColor Yellow
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Host "  Trying winget ($($script:HawkPs7WingetId))..."
            & $winget.Source install --id $script:HawkPs7WingetId --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        }
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if (-not $pwsh) {
            Write-Host "  winget unavailable or failed. Falling back to MSI: $($script:HawkPs7MsiUrl)" -ForegroundColor Yellow
            $msi = Join-Path $env:TEMP "PowerShell-$($script:HawkPs7Version)-win-x64.msi"
            try {
                Invoke-WebRequest -Uri $script:HawkPs7MsiUrl -OutFile $msi -UseBasicParsing
                # PS7 MSI installs per-machine; elevation is required. The fresh
                # install also won't be visible via Get-Command in this process
                # (stale PATH), so fall back to the known install location.
                Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -Verb RunAs
                $msiPwsh = Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"
                if (Test-Path -LiteralPath $msiPwsh) { $pwsh = Get-Item -LiteralPath $msiPwsh }
            } catch {
                Write-Host "  PowerShell 7 installation failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "  Install PowerShell 7 manually from https://github.com/PowerShell/PowerShell/releases and re-run this installer." -ForegroundColor Yellow
                exit 1
            }
        }
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if (-not $pwsh) {
            Write-Host "PowerShell 7 still not available after install. Aborting." -ForegroundColor Red
            exit 1
        }
        Write-Host "PowerShell 7 installed." -ForegroundColor Green
    }

    # Relaunch under pwsh, passing every argument through. -ExecutionPolicy
    # Bypass on the command line lets the script load under Restricted policy.
    $relaunch = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
    if ($Auto) { $relaunch += '-Auto' }
    if ($Uninstall) { $relaunch += '-Uninstall' }
    if ($Update) { $relaunch += '-Update' }
    if ($RemoveEngines) { $relaunch += '-RemoveEngines' }
    if ($RemoveModel) { $relaunch += '-RemoveModel' }
    if ($Force) { $relaunch += '-Force' }
    if ($StagingRoot) { $relaunch += '-StagingRoot', $StagingRoot }
    if ($HfHome) { $relaunch += '-HfHome', $HfHome }
    if ($ProjectRoot) { $relaunch += '-ProjectRoot', $ProjectRoot }
    if ($LlamaPort -ne 8081) { $relaunch += '-LlamaPort', "$LlamaPort" }

    Write-Host "Handing off to PowerShell 7..." -ForegroundColor Cyan
    & $pwsh.Source @relaunch
    exit $LASTEXITCODE
}

# ============================================================================
# PS 7 main body.
# ============================================================================
. (Join-Path $scriptDir 'vars.ps1')
. (Join-Path $scriptDir 'lib\common.ps1')
. (Join-Path $scriptDir 'lib\config.ps1')

Set-HawkStagingRoot -Path $StagingRoot
$null = Initialize-HawkLog

Write-HawkLog "Hawk installer running under PowerShell $($PSVersionTable.PSVersion)" 'INFO'
Write-HawkLog "Args: Auto=$Auto Uninstall=$Uninstall Update=$Update Force=$Force RemoveEngines=$RemoveEngines RemoveModel=$RemoveModel StagingRoot=$StagingRoot HfHome=$HfHome ProjectRoot=$ProjectRoot LlamaPort=$LlamaPort" 'INFO'

# --- Uninstall path ---
if ($Uninstall) {
    . (Join-Path $scriptDir 'steps\05-uninstall.ps1') -Force:$Force -RemoveEngines:$RemoveEngines -RemoveModel:$RemoveModel
    Get-HawkStepSummary
    $failedSteps = @($script:HawkStepResults | Where-Object { $_.Status -eq 'failed' })
    exit $(if ($failedSteps.Count -gt 0) { 1 } else { 0 })
}

# --- Update check path ---
if ($Update) {
    . (Join-Path $scriptDir 'steps\06-update-check.ps1')
    Get-HawkStepSummary
    $failedSteps = @($script:HawkStepResults | Where-Object { $_.Status -eq 'failed' })
    exit $(if ($failedSteps.Count -gt 0) { 1 } else { 0 })
}

# --- Resolve machine settings: param > existing config > prompt/default ---
$existingConfig = Read-HawkConfig -Path (Get-HawkTargetPath -Kind 'Config')

$script:HawkHfHome = if ($HfHome) { $HfHome } elseif ($existingConfig.hfHome) { [string]$existingConfig.hfHome } else { $null }
$script:HawkProjectRoot = if ($ProjectRoot) { $ProjectRoot } elseif ($existingConfig.projectRoot) { [string]$existingConfig.projectRoot } else { $null }
$script:HawkLlamaPort = if ($LlamaPort -ne 8081) { $LlamaPort } elseif ($existingConfig.llamaPort) { [int]$existingConfig.llamaPort } else { 8081 }

if (-not $script:HawkHfHome) {
    if ($Auto) {
        $script:HawkHfHome = $script:HawkDefaultHfHome
    } else {
        $answer = Read-Host "Hugging Face home directory (model storage) [$($script:HawkDefaultHfHome)]"
        $script:HawkHfHome = if ($answer) { $answer.Trim() } else { $script:HawkDefaultHfHome }
    }
}
if (-not $script:HawkProjectRoot) {
    if ($Auto) {
        $script:HawkProjectRoot = $script:HawkDefaultProjectRoot
    } else {
        $answer = Read-Host "Default project root [$($script:HawkDefaultProjectRoot)]"
        $script:HawkProjectRoot = if ($answer) { $answer.Trim() } else { $script:HawkDefaultProjectRoot }
    }
}

Write-HawkLog "Resolved: HfHome=$($script:HawkHfHome) ProjectRoot=$($script:HawkProjectRoot) LlamaPort=$($script:HawkLlamaPort)" 'INFO'

# --- Step orchestration (continue-on-failure; each step independent) ---
Write-HawkStepStatus -Step 'bootstrap' -Status 'ok' -Detail "handed off to PowerShell $($PSVersionTable.PSVersion)"

. (Join-Path $scriptDir 'steps\01-engine.ps1')
. (Join-Path $scriptDir 'steps\02-model.ps1')
. (Join-Path $scriptDir 'steps\03-wiring.ps1')
. (Join-Path $scriptDir 'steps\04-config.ps1')

Get-HawkStepSummary

$failed = @($script:HawkStepResults | Where-Object { $_.Status -eq 'failed' })
if ($failed.Count -gt 0) {
    Write-HawkLog "$($failed.Count) step(s) failed - re-run the installer to retry (skipped steps are safe)." 'ERROR'
    exit 1
}
exit 0
