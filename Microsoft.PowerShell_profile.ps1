# ==============================================================================
# PowerShell 7 - Hawkward Hybrid 11.2 (Workspace Profile Loader)
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hawkProfileRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PROFILE.CurrentUserCurrentHost }
$hawkModuleManifest = Join-Path $hawkProfileRoot 'Modules\HawkwardHybrid\HawkwardHybrid.psd1'

if (-not (Test-Path $hawkModuleManifest)) {
    Write-Warning "Hawkward Hybrid manifest target missing: $hawkModuleManifest"
    return
}

try {
    Import-Module $hawkModuleManifest -Force -ErrorAction Stop
    $hawkProjectRoot = if ($env:HAWK_PROJECT_ROOT) { $env:HAWK_PROJECT_ROOT } else { $hawkProfileRoot }
    Initialize-HawkProfile -ProjectRoot $hawkProjectRoot -ShowDashboard
}
catch {
    Write-Warning "Hawkward Hybrid module initialization crash: $($_.Exception.Message)"
}

# Integrate external tools if present
if (Get-Command scoop-search -ErrorAction SilentlyContinue) {
    . ([ScriptBlock]::Create((& scoop-search --hook | Out-String))) | Out-Null
}
