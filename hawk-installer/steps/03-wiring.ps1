# Step 03 — Hawk wiring: modules, profile, dependencies. Idempotent.
# Copies bundled files into the PS7 home, backs up an existing profile,
# installs missing user-scope dependencies.
# Depends on vars.ps1 + lib/common.ps1.

$bundle = Split-Path $PSScriptRoot -Parent   # hawk-installer root
$hawkHome = Get-HawkHome

# --- module: HawkwardHybrid ---
$hybridDir    = Get-HawkTargetPath -Kind 'HybridModuleDir'
$hybridSource = Join-Path $bundle 'modules\HawkwardHybrid'

$moduleOk = $true
try {
    New-Item -ItemType Directory -Path $hybridDir -Force | Out-Null
    # Module is multi-file since v12: entry psm1 + manifest + dot-sourced domain files.
    Copy-Item -Path (Join-Path $hybridSource '*') -Destination $hybridDir -Recurse -Force
    Write-HawkLog "Hybrid module copied to $hybridDir" 'INFO'
} catch {
    $moduleOk = $false
    Write-HawkLog "Module copy failed: $($_.Exception.Message)" 'ERROR'
}
if ($moduleOk) {
    Write-HawkStepStatus 'wiring-modules' 'ok' "Modules installed under $hawkHome"
} else {
    Write-HawkStepStatus 'wiring-modules' 'failed' 'Module copy failed (see log)'
}

# --- profile: timestamped backup of existing, then template ---
$profileTarget = Get-HawkTargetPath -Kind 'Profile'
$profileSource = Join-Path $bundle 'profile\Microsoft.PowerShell_profile.ps1'
$profileOk = $true
try {
    if (Test-Path -LiteralPath $profileTarget) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$profileTarget.bak-$stamp"
        Copy-Item -LiteralPath $profileTarget -Destination $backup
        Write-HawkLog "Existing profile backed up to $backup" 'INFO'
    }
    Copy-Item -LiteralPath $profileSource -Destination $profileTarget -Force
    Write-HawkLog "Profile template installed to $profileTarget" 'INFO'
} catch {
    $profileOk = $false
    Write-HawkLog "Profile install failed: $($_.Exception.Message)" 'ERROR'
}
if ($profileOk) {
    Write-HawkStepStatus 'wiring-profile' 'ok' "Profile installed (existing backed up)"
} else {
    Write-HawkStepStatus 'wiring-profile' 'failed' 'Profile install failed (see log)'
}

# --- dependencies: Terminal-Icons + PSTree, CurrentUser scope ---
$missing = @('Terminal-Icons', 'PSTree') | Where-Object { -not (Get-Module -ListAvailable -Name $_) }
if ($script:HawkStagingRoot) {
    # Staging mode is a test run: never mutate the real user module path.
    if ($missing) {
        Write-HawkStepStatus 'wiring-deps' 'skip' "Staging mode - deps not installed here (missing: $($missing -join ', '))"
    } else {
        Write-HawkStepStatus 'wiring-deps' 'skip' 'Terminal-Icons + PSTree already available'
    }
} elseif (-not $missing) {
    Write-HawkStepStatus 'wiring-deps' 'skip' 'Terminal-Icons + PSTree already available'
} else {
    try {
        # Non-interactive bootstrap: PowerShellGet needs the NuGet provider and
        # a trusted PSGallery to install without prompting.
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop
        }
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module -Name $missing -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-HawkLog "Installed: $($missing -join ', ')" 'INFO'
        Write-HawkStepStatus 'wiring-deps' 'ok' "Installed $($missing -join ', ')"
    } catch {
        Write-HawkStepStatus 'wiring-deps' 'failed' "Dependency install failed: $($_.Exception.Message)"
    }
}

# --- font: JetBrainsMono Nerd Font (dashboard/prompt glyph icons) ---
# Any Nerd Font enables the glyphs; this pinned default is fetched via winget
# when none is registered. Non-fatal: UI falls back to plain Unicode glyphs.
if ($script:HawkStagingRoot) {
    # Staging mode is a test run: never mutate the real user environment.
    Write-HawkStepStatus 'wiring-font' 'skip' 'Staging mode - font not installed here'
} elseif (Test-HawkNerdFontPresent) {
    Write-HawkStepStatus 'wiring-font' 'skip' 'Nerd Font already installed'
} else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-HawkStepStatus 'wiring-font' 'skip' 'winget unavailable - install a Nerd Font manually for icon glyphs'
    } else {
        try {
            Write-HawkLog 'Installing JetBrainsMono Nerd Font via winget...' 'INFO'
            $wingetOut = & winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-HawkStepStatus 'wiring-font' 'ok' 'JetBrainsMono Nerd Font installed'
            } else {
                $tail = (@($wingetOut) | Select-Object -Last 3) -join ' | '
                Write-HawkLog "winget output tail: $tail" 'WARN'
                Write-HawkStepStatus 'wiring-font' 'failed' "winget exit code $LASTEXITCODE - dashboard uses Unicode fallback"
            }
        } catch {
            Write-HawkStepStatus 'wiring-font' 'failed' "Font install failed: $($_.Exception.Message)"
        }
    }
}
