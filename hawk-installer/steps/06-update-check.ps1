# Step 06 — update check: compare installed versions against vars.ps1 pins.
# Reports what's outdated. Does NOT auto-update; re-run the installer to apply.
# Depends on vars.ps1 + lib/common.ps1.

$checks = @()

# --- PowerShell 7 ---
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
$installedPs7 = $null
if ($pwsh) {
    # We're already running under PS7 (install.ps1 ensures this), so read directly
    $installedPs7 = $PSVersionTable.PSVersion.ToString()
}
$ps7Current = $installedPs7 -eq $script:HawkPs7Version
$checks += [pscustomobject]@{
    Component = 'PowerShell 7'
    Installed = if ($installedPs7) { $installedPs7 } else { 'not installed' }
    Pinned    = $script:HawkPs7Version
    Current   = $ps7Current
}

# --- llama.cpp ---
$llama = Get-Command llama -ErrorAction SilentlyContinue
$installedLlama = $null
if ($llama) {
    try {
        $tag = & llama --version 2>$null | Select-Object -First 1
        if ($tag -match 'b\d+') { $installedLlama = $Matches[0] }
    } catch {}
}
$llamaCurrent = $installedLlama -eq $script:HawkLlamaVersion
$checks += [pscustomobject]@{
    Component = 'llama.cpp'
    Installed = if ($installedLlama) { $installedLlama } else { 'not installed' }
    Pinned    = $script:HawkLlamaVersion
    Current   = $llamaCurrent
}

# --- Module version ---
$moduleVersion = $null
$pinnedModuleVersion = $null
$liveModulePsd1 = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\HawkwardHybrid\HawkwardHybrid.psd1'
$bundledModulePsd1 = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\HawkwardHybrid\HawkwardHybrid.psd1'
if (Test-Path -LiteralPath $liveModulePsd1) {
    try {
        $manifest = Import-PowerShellDataFile -LiteralPath $liveModulePsd1 -ErrorAction Stop
        $moduleVersion = $manifest.ModuleVersion
    } catch {}
}
if (Test-Path -LiteralPath $bundledModulePsd1) {
    try {
        $bundled = Import-PowerShellDataFile -LiteralPath $bundledModulePsd1 -ErrorAction Stop
        $pinnedModuleVersion = $bundled.ModuleVersion
    } catch {}
}
if (-not $pinnedModuleVersion) { $pinnedModuleVersion = '12.0.0' }
$checks += [pscustomobject]@{
    Component = 'PowershellOps core module'
    Installed = if ($moduleVersion) { $moduleVersion } else { 'not installed' }
    Pinned    = $pinnedModuleVersion
    Current   = ($moduleVersion -eq $pinnedModuleVersion)
}

# --- Model ---
$hfHome = $script:HawkDefaultHfHome
$configPath = Get-HawkTargetPath -Kind 'Config'
$existingConfig = Read-HawkConfig -Path $configPath
if ($existingConfig -and $existingConfig.hfHome) { $hfHome = $existingConfig.hfHome }
$snapshots = Join-Path $hfHome "hub\models--$($script:HawkModelRepo -replace '/', '--')\snapshots"
$modelFound = $false
if (Test-Path -LiteralPath $snapshots) {
    $gguf = Get-ChildItem -LiteralPath $snapshots -Recurse -Filter $script:HawkModelFile -ErrorAction SilentlyContinue | Select-Object -First 1
    $modelFound = [bool]$gguf
}
$checks += [pscustomobject]@{
    Component = 'Model (Qwen3-1.7B)'
    Installed = if ($modelFound) { 'present' } else { 'not found' }
    Pinned    = $script:HawkModelSpec
    Current   = $modelFound
}

# --- Dependencies ---
$deps = @('Terminal-Icons', 'PSTree', 'PSReadLine')
$missingDeps = @($deps | Where-Object { -not (Get-Module -ListAvailable -Name $_) })
$depsCurrent = $missingDeps.Count -eq 0
$checks += [pscustomobject]@{
    Component = 'Dependencies'
    Installed = if ($depsCurrent) { 'all present' } else { "missing: $($missingDeps -join ', ')" }
    Pinned    = $deps -join ', '
    Current   = $depsCurrent
}

# --- Nerd Font (dashboard/prompt glyph icons) ---
$nfFound = Test-HawkNerdFontPresent
$checks += [pscustomobject]@{
    Component = 'Nerd Font'
    Installed = if ($nfFound) { 'present' } else { 'not found' }
    Pinned    = 'any Nerd Font'
    Current   = $nfFound
}

# --- Summary ---
$outdated = @($checks | Where-Object { -not $_.Current })
Write-Host "`n========== UPDATE CHECK ==========" -ForegroundColor Cyan
foreach ($c in $checks) {
    $color = if ($c.Current) { 'Green' } else { 'Yellow' }
    $icon = if ($c.Current) { 'OK' } else { 'UPDATE' }
    Write-Host ("  {0,-24} {1,-6} {2}" -f $c.Component, $icon, $c.Installed) -ForegroundColor $color
    if (-not $c.Current) {
        Write-Host ("  {0,-24} {1}" -f '', "Pinned: $($c.Pinned)") -ForegroundColor DarkGray
    }
}
if ($outdated.Count -eq 0) {
    Write-Host "`nAll components current." -ForegroundColor Green
} else {
    Write-Host "`n$($outdated.Count) component(s) outdated. Re-run the installer to update." -ForegroundColor Yellow
}

Write-HawkStepStatus 'update-check' 'ok' "$($outdated.Count) outdated of $($checks.Count) total"
