# Step 02 — model download + verify. Idempotent.
# Expects $script:HawkHfHome set by orchestration.
# Depends on vars.ps1 + lib/common.ps1.

$snapshots = Join-Path $script:HawkHfHome "hub\models--$($script:HawkModelRepo -replace '/', '--')\snapshots"
$existing = $null
if (Test-Path -LiteralPath $snapshots) {
    $existing = Get-ChildItem -LiteralPath $snapshots -Recurse -Filter $script:HawkModelFile -ErrorAction SilentlyContinue | Select-Object -First 1
}

if ($existing) {
    Write-HawkStepStatus 'model' 'skip' "Model present ($($existing.FullName))"
} else {
    Write-HawkLog "Model $($script:HawkModelSpec) not found under $($script:HawkHfHome) - downloading..." 'STEP'
    $llama = Get-Command llama -ErrorAction SilentlyContinue
    if (-not $llama) {
        Write-HawkStepStatus 'model' 'failed' 'llama not found - run the engine step first'
    } else {
        # Persist HF_HOME as a User-scope env var so later llama invocations
        # land in the same place. Never persist during staging/test installs.
        $env:HF_HOME = $script:HawkHfHome
        if (-not $script:HawkStagingRoot) {
            [Environment]::SetEnvironmentVariable('HF_HOME', $script:HawkHfHome, 'User')
            Write-HawkLog "HF_HOME persisted as User env var = $($script:HawkHfHome)" 'INFO'
        }
        & $llama.Source download -hf $script:HawkModelSpec 2>&1 | ForEach-Object { Write-HawkLog $_ 'INFO' }
        $found = $null
        if (Test-Path -LiteralPath $snapshots) {
            $found = Get-ChildItem -LiteralPath $snapshots -Recurse -Filter $script:HawkModelFile -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($found) {
            Write-HawkStepStatus 'model' 'ok' "Model downloaded + verified ($($found.FullName))"
        } else {
            Write-HawkStepStatus 'model' 'failed' "Download ran but GGUF not found under $($script:HawkHfHome) - re-run to resume"
        }
    }
}
