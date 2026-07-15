# ==============================================================================
# POWERSHELL OPS : CORE : PROVISIONING SCRIPT (Hardened v3)
# ==============================================================================

$ErrorActionPreference = 'Stop'

$esc = [char]27
$reset = "${esc}[0m"
Write-Host "`n  ${esc}[48;5;158m${esc}[38;5;16m SYSTEM ${reset} Initializing PowershellOps provisioning sequence..."
Write-Host "  ${esc}[38;5;246m────────────────────────────────────────────────────${reset}"

# 1. Path Resolution
$docsPath = [Environment]::GetFolderPath('MyDocuments')
$target = Join-Path $docsPath "PowerShell"
$currentScriptDir = $PSScriptRoot

# 2. Sync Logic
Write-Host "  ${esc}[38;5;158m[ CORE ]${reset} Syncing system files to: $target"
if ($currentScriptDir -ne $target) {
    if (-not (Test-Path $target)) { New-Item -Path $target -ItemType Directory -Force | Out-Null }
    # Copy all files from the current folder (dev) to the system folder (live)
    Copy-Item -Path "$currentScriptDir\*" -Destination $target -Recurse -Force -Exclude ".git"
} else {
    Write-Host "  ${esc}[38;5;246m[ CORE ] Already in target directory. Pulling latest...${reset}"
    if (Test-Path (Join-Path $target ".git")) {
        Push-Location $target; git pull --quiet; Pop-Location
    }
}

# 3. Profile Linkage
$profilePath = $PROFILE.CurrentUserCurrentHost
$sourceProfile = Join-Path $target "Microsoft.PowerShell_profile.ps1"

if ($sourceProfile -ne $profilePath) {
    Write-Host "  ${esc}[38;5;158m[ PROF ]${reset} Wiring system profile..."
    if (-not (Test-Path (Split-Path $profilePath))) { New-Item -Path (Split-Path $profilePath) -ItemType Directory -Force | Out-Null }
    Copy-Item $sourceProfile $profilePath -Force
}

# 4. Dependency Sync
Write-Host "  ${esc}[38;5;158m[ DEPS ]${reset} Syncing module dependencies..."
$modulePath = Join-Path $target "Modules\PowershellOps\PowershellOps.psd1"
if (Test-Path $modulePath) {
    # We run pwsh here to ensure a fresh environment for module installation
    pwsh -NoProfile -Command "Import-Module '$modulePath' -Force; Install-OpsPrerequisite"
}

# 5. Finalization
Write-Host "`n  ${esc}[48;5;158m${esc}[38;5;16m OK ${reset} Provisioning complete. PowershellOps active."
Write-Host "  ${esc}[38;5;246m────────────────────────────────────────────────────${reset}"
Write-Host "  Restart terminal to initialize core."
Write-Host "  Index command: 'coreindex'`n" -ForegroundColor Cyan


