# Step 05 — uninstall Hawk installer artifacts. Idempotent.
# Removes modules, profile, and config. Optionally removes PS7, llama.cpp,
# and model files when -RemoveEngines / -RemoveModel are specified.
# Depends on vars.ps1 + lib/common.ps1.

param(
    [switch]$RemoveEngines,
    [switch]$RemoveModel,
    [switch]$Force
)

$hawkHome = Get-HawkHome

# --- Read config before any deletion (needed for model path) ---
$configTarget = Get-HawkTargetPath -Kind 'Config'
$preConfig = Read-HawkConfig -Path $configTarget

# --- Confirm unless -Force ---
if (-not $Force) {
    Write-Host "`nThis will remove PowershellOps (Hawk profile) installer artifacts from: $hawkHome" -ForegroundColor Yellow
    if ($RemoveEngines) { Write-Host "  + PowerShell 7 and llama.cpp will be removed" -ForegroundColor Yellow }
    if ($RemoveModel) { Write-Host "  + Model files will be removed" -ForegroundColor Yellow }
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -notin @('y', 'Y', 'yes', 'Yes')) {
        Write-HawkStepStatus 'uninstall' 'skip' 'User cancelled'
        return
    }
}

# --- Remove modules ---
$legacyModule = Get-HawkTargetPath -Kind 'LegacyModule'
$legacyDir = Split-Path $legacyModule -Parent
$hybridDir = Get-HawkTargetPath -Kind 'HybridModuleDir'

try {
    if (Test-Path -LiteralPath $legacyModule) {
        Remove-Item -LiteralPath $legacyModule -Force
        # Also remove .psd1 if present
        $legacyPsd1 = Join-Path $legacyDir 'HawkModules.psd1'
        if (Test-Path -LiteralPath $legacyPsd1) { Remove-Item -LiteralPath $legacyPsd1 -Force }
        Write-HawkLog "Removed legacy module from $legacyDir" 'INFO'
    }
    if (Test-Path -LiteralPath $hybridDir) {
        Remove-Item -LiteralPath $hybridDir -Recurse -Force
        Write-HawkLog "Removed hybrid module from $hybridDir" 'INFO'
    }
    # Remove HawkProfile directory if empty
    if (Test-Path -LiteralPath $legacyDir) {
        $remaining = Get-ChildItem -LiteralPath $legacyDir -Force
        if (-not $remaining) {
            Remove-Item -LiteralPath $legacyDir -Force
            Write-HawkLog "Removed empty HawkProfile directory" 'INFO'
        }
    }
    Write-HawkStepStatus 'uninstall-modules' 'ok' 'Modules removed'
} catch {
    Write-HawkStepStatus 'uninstall-modules' 'failed' "Module removal failed: $($_.Exception.Message)"
}

# --- Remove profile ---
$profileTarget = Get-HawkTargetPath -Kind 'Profile'
try {
    if (Test-Path -LiteralPath $profileTarget) {
        Remove-Item -LiteralPath $profileTarget -Force
        Write-HawkLog "Removed profile from $profileTarget" 'INFO'
    }
    # Also remove .bak-* backups
    $profileDir = Split-Path $profileTarget -Parent
    Get-ChildItem -LiteralPath $profileDir -Filter 'Microsoft.PowerShell_profile.ps1.bak-*' -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-HawkStepStatus 'uninstall-profile' 'ok' 'Profile removed'
} catch {
    Write-HawkStepStatus 'uninstall-profile' 'failed' "Profile removal failed: $($_.Exception.Message)"
}

# --- Remove config ---
try {
    if (Test-Path -LiteralPath $configTarget) {
        Remove-Item -LiteralPath $configTarget -Force
        Write-HawkLog "Removed config from $configTarget" 'INFO'
    }
    Write-HawkStepStatus 'uninstall-config' 'ok' 'Config removed'
} catch {
    Write-HawkStepStatus 'uninstall-config' 'failed' "Config removal failed: $($_.Exception.Message)"
}

# --- Optionally remove engines ---
if ($RemoveEngines) {
    # llama.cpp — uninstall via winget if available, else manual removal
    $llama = Get-Command llama -ErrorAction SilentlyContinue
    if ($llama) {
        try {
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if ($winget) {
                & $winget.Source uninstall --id ggml.llamacpp --exact --silent --accept-source-agreements 2>&1 | ForEach-Object { Write-HawkLog $_ 'INFO' }
            } else {
                # Manual removal: delete the binary and its parent directory if it's a standalone install
                $llamaPath = $llama.Source
                $llamaDir = Split-Path $llamaPath -Parent
                # Only remove if it looks like a llama install dir (not System32 etc.)
                if ($llamaDir -match 'llama|WindowsApps' -and (Test-Path -LiteralPath $llamaDir)) {
                    Remove-Item -LiteralPath $llamaDir -Recurse -Force
                    Write-HawkLog "Removed llama directory: $llamaDir" 'INFO'
                }
            }
            Write-HawkStepStatus 'uninstall-llama' 'ok' 'llama.cpp removed'
        } catch {
            Write-HawkStepStatus 'uninstall-llama' 'failed' "llama.cpp removal failed: $($_.Exception.Message)"
        }
    } else {
        Write-HawkStepStatus 'uninstall-llama' 'skip' 'llama.cpp not installed'
    }
}

# --- Optionally remove model ---
if ($RemoveModel) {
    $hfHome = if ($preConfig -and $preConfig.hfHome) { $preConfig.hfHome } else { $script:HawkDefaultHfHome }
    $snapshots = Join-Path $hfHome "hub\models--$($script:HawkModelRepo -replace '/', '--')\snapshots"
    try {
        if (Test-Path -LiteralPath $snapshots) {
            Remove-Item -LiteralPath $snapshots -Recurse -Force
            Write-HawkLog "Removed model cache from $snapshots" 'INFO'
        }
        Write-HawkStepStatus 'uninstall-model' 'ok' 'Model files removed'
    } catch {
        Write-HawkStepStatus 'uninstall-model' 'failed' "Model removal failed: $($_.Exception.Message)"
    }
}
