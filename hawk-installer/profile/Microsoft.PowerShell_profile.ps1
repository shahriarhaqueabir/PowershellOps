# ============================================================
#  POWERSHELLOPS · HAWK PS7 PROFILE — merged system (installer-managed template)
#  Engine : PowerShell 7 (pwsh) — default shell
#  Core   : HawkwardHybrid (single-module profile)
# ============================================================

# UTF-8 console output. Only touch [Console] in a real console host —
# SSH remoting, services, and CI runners have no console handle and this throws.
if ($Host.Name -eq 'ConsoleHost') {
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
}

# projectRoot comes from hawk.config.json (read at module import with
# fallback to the module default); no explicit -ProjectRoot needed here.
# --- HawkwardHybrid — primary system ---
if (Get-Module -ListAvailable -Name HawkwardHybrid) {
    try {
        Import-Module -Name HawkwardHybrid -Force
        Initialize-HawkProfile -ShowDashboard
    }
    catch {
        Write-Warning "HawkwardHybrid failed to initialize: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "PowershellOps core module HawkwardHybrid not found — re-run install.ps1 (wiring step). Toolkit commands (ai, hawkcheck, dash...) are unavailable."
}
