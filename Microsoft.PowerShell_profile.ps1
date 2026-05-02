# ============================================================
# PowerShell 7 - Hawkward Hybrid 11.2 (Module Loader)
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hawkProfileRoot = if ($PSScriptRoot) {
    $PSScriptRoot
}
else {
    Split-Path -Parent $PROFILE.CurrentUserCurrentHost
}

$hawkModuleManifest = Join-Path $hawkProfileRoot 'Modules\HawkwardHybrid\HawkwardHybrid.psd1'

if (-not (Test-Path $hawkModuleManifest)) {
    Write-Warning "Hawkward Hybrid module not found: $hawkModuleManifest"
    return
}

try {
    Import-Module $hawkModuleManifest -Force -ErrorAction Stop
    Initialize-HawkProfile -ProjectRoot 'E:\Projects' -ShowDashboard
}
catch {
    Write-Warning "Hawkward Hybrid failed to initialize: $($_.Exception.Message)"
}
