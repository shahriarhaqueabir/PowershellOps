# ==============================================================================
# 󰉏 PowershellOps - Magic One-Liner Installer
# ==============================================================================
# This script automates the full setup for a fresh PC.
# Run: irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$esc = [char]27
$reset = "${esc}[0m"
Write-Host "`n  ${esc}[48;5;158m${esc}[38;5;16m 󰉏 ${reset} Initializing PowershellOps Setup..."
Write-Host "  ${esc}[38;5;246m──────────────────────────────────────────${reset}"

# 1. Verification
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "  ${esc}[38;5;217m❌ PowerShell 7+ is required.${reset}"
    Write-Host "  Please download it from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Gray
    exit
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ${esc}[38;5;217m❌ Git is missing.${reset}"
    Write-Host "  Please install it from: https://git-scm.com" -ForegroundColor Gray
    exit
}

# 2. Destination Setup
$installDir = Join-Path $HOME "Documents\PowerShell"
if (-not (Test-Path $installDir)) {
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
}

# 3. Clone / Update
Write-Host "  ${esc}[38;5;158m󰚰${reset} Downloading PowershellOps core files..."
if (Test-Path (Join-Path $installDir ".git")) {
    Push-Location $installDir
    git pull
    Pop-Location
} else {
    git clone https://github.com/shahriarhaqueabir/PowershellOps.git $installDir
}

# 4. Profile Wiring
Write-Host "  ${esc}[38;5;158m󰒓${reset} Wiring your flight deck profile..."
$profilePath = $PROFILE.CurrentUserCurrentHost
$sourceProfile = Join-Path $installDir "Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path (Split-Path $profilePath))) {
    New-Item -Path (Split-Path $profilePath) -ItemType Directory -Force | Out-Null
}

Copy-Item $sourceProfile $profilePath -Force

# 5. Dependency Sync
Write-Host "  ${esc}[38;5;158m󰚝${reset} Syncing icons and history tools..."
pwsh -Command "Import-Module '$installDir\Modules\HawkwardHybrid\HawkwardHybrid.psd1' -Force; Install-HawkPrerequisite"

# 6. Success
Write-Host "`n  ${esc}[48;5;158m${esc}[38;5;16m ✅ ${reset} SUCCESS! PowershellOps is ready."
Write-Host "  ${esc}[38;5;246m──────────────────────────────────────────${reset}"
Write-Host "  Restart your terminal or type 'corereload' to begin."
Write-Host "  Type 'coreindex' for your new home screen.`n" -ForegroundColor Cyan
