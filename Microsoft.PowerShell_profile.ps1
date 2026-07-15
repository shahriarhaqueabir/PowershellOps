# ==============================================================================
# HAWK : CORE : v11.3
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Path Resolution
$hawkProfileRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PROFILE.CurrentUserCurrentHost }
$hawkModuleManifest = Join-Path $hawkProfileRoot 'Modules\PowershellOps\PowershellOps.psd1'

# Module Verification
if (-not (Test-Path $hawkModuleManifest)) {
    # Silence warning during standard shell startup if module is missing
    return
}

# Core Initialization
try {
    Import-Module $hawkModuleManifest -Force -ErrorAction Stop
    $hawkProjectRoot = if ($env:HAWK_PROJECT_ROOT) { $env:HAWK_PROJECT_ROOT } else { $hawkProfileRoot }
    Initialize-HawkProfile -ProjectRoot $hawkProjectRoot -ShowDashboard
}
catch {
    Write-Warning "[ HAWK ] Core initialization failure: $($_.Exception.Message)"
}

# Integrate external tools if present
if (Get-Command scoop-search -ErrorAction SilentlyContinue) {
    . ([ScriptBlock]::Create((& scoop-search --hook | Out-String))) | Out-Null
}

