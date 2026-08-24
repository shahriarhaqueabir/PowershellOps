function Initialize-HawkProfile {
    <#
    .SYNOPSIS
    Full profile bootstrap for PowershellOps.
    .DESCRIPTION
    Imports prerequisite modules, configures PSReadLine, sets the custom prompt,
    registers all aliases, and optionally shows the dashboard. This is the main
    entry point called from $PROFILE.
    .PARAMETER ProjectRoot
    Root directory for the Hawk project. Defaults to the configured path.
    .PARAMETER ShowDashboard
    Show the Hawk dashboard after initialization.
    .PARAMETER SkipModules
    Skip importing prerequisite modules (Terminal-Icons, PSReadLine, PSTree).
    #>
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $script:HawkDefaultProjectRoot,
        [switch]$ShowDashboard,
        [switch]$SkipModules
    )

    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    $global:HawkProjectRoot = $ProjectRoot

    if (-not $SkipModules) {
        Import-HawkPrerequisites -Quiet | Out-Null
    }

    Set-HawkReadLine
    Set-HawkAliases
    Set-HawkPrompt

    if ($ShowDashboard -and (Test-HawkInteractiveSession)) {
        Show-HawkDashboard
    }
}

# ── Dispatch verbs ─────────────────────────────────────────────────

