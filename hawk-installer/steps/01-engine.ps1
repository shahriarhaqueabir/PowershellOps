# Step 01 — engine install: PowerShell 7 + llama.cpp. Idempotent.
# Both sub-steps are independent; failure in one does not block the other.
# Depends on vars.ps1 + lib/common.ps1 (dot-sourced by install.ps1).
#
# NOTE: PS7 install logic lives in the bootstrap (install.ps1 lines 36-93).
# By the time this step runs, pwsh is guaranteed available. This section only
# verifies and reports.

# --- PowerShell 7 ---
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
    Write-HawkStepStatus 'engine-ps7' 'skip' "PowerShell 7 present ($($pwsh.Source))"
} else {
    Write-HawkStepStatus 'engine-ps7' 'failed' 'PowerShell 7 not found - re-run install.ps1 from Windows PowerShell 5.1'
}

# --- llama.cpp ---
$llama = Get-Command llama -ErrorAction SilentlyContinue
if ($llama) {
    Write-HawkStepStatus 'engine-llama' 'skip' "llama.cpp present ($($llama.Source))"
} else {
    Write-HawkLog "llama.cpp not found - installing pinned $($script:HawkLlamaVersion)..." 'STEP'
    $installer = Join-Path $env:TEMP 'llama-install.ps1'
    try {
        Invoke-WebRequest -Uri $script:HawkLlamaInstallUrl -OutFile $installer -UseBasicParsing
        $size = (Get-Item -LiteralPath $installer).Length
        if ($size -lt 1000) { throw "installer suspiciously small ($size bytes)" }
        # Integrity: llama.app publishes no hash for install.ps1. Documented trust
        # decision: HTTPS transport + pinned LLAMA_VERSION + size sanity check.
        Write-HawkLog "llama.app installer downloaded ($size bytes). Integrity: HTTPS + pinned LLAMA_VERSION=$($script:HawkLlamaVersion) (no published hash - documented trust decision)." 'INFO'
        $env:LLAMA_VERSION = $script:HawkLlamaVersion
        & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $installer 2>&1 | ForEach-Object { Write-HawkLog $_ 'INFO' }
        $llama = Get-Command llama -ErrorAction SilentlyContinue
        if ($llama) {
            Write-HawkStepStatus 'engine-llama' 'ok' "llama.cpp installed ($($llama.Source))"
        } else {
            Write-HawkStepStatus 'engine-llama' 'failed' 'llama.app installer ran but llama not found in PATH'
        }
    } catch {
        Write-HawkStepStatus 'engine-llama' 'failed' "llama.cpp install failed: $($_.Exception.Message)"
    }
}
