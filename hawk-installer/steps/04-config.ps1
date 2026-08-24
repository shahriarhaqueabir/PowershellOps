# Step 04 — write machine config (hawk.config.json). Idempotent.
# Expects (set by install.ps1 orchestration): $script:HawkHfHome,
# $script:HawkProjectRoot, $script:HawkLlamaPort.
# Resolves modelPath from the hfHome snapshots scan (no hardcoded sha).

$configPath = Get-HawkTargetPath -Kind 'Config'
$existing = Read-HawkConfig -Path $configPath

$values = @{
    projectRoot = $script:HawkProjectRoot
    hfHome      = $script:HawkHfHome
    llamaPort   = $script:HawkLlamaPort
    modelPath   = $null
}

# Resolve model path: reuse existing config value if still valid, else scan hfHome snapshots.
if ($existing -and $existing.modelPath -and (Test-Path -LiteralPath $existing.modelPath)) {
    $values.modelPath = [string]$existing.modelPath
} else {
    $snapshots = Join-Path $script:HawkHfHome "hub\models--$($script:HawkModelRepo -replace '/', '--')\snapshots"
    if (Test-Path -LiteralPath $snapshots) {
        $gguf = Get-ChildItem -LiteralPath $snapshots -Recurse -Filter $script:HawkModelFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gguf) { $values.modelPath = $gguf.FullName }
    }
}

Write-HawkConfig -Path $configPath -Values $values
Write-HawkStepStatus 'config' 'ok' "hawk.config.json written (projectRoot=$($values.projectRoot), hfHome=$($values.hfHome), llamaPort=$($values.llamaPort), modelPath=$($values.modelPath))"