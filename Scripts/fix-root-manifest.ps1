# Fix root manifest to export ALL functions (Tier 0 + Tier 1)
$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"

$manifest = @'
@{
    RootModule        = 'Talon.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Copyright         = '(c) 2026 Talon Contributors. MIT License.'
    Description       = 'Talon - featherweight PowerShell 7 ops shell with 50 diagnostic + AI commands.'
    PowerShellVersion = '7.0'
    NestedModules     = @('Talon.Commands.psd1')
    FunctionsToExport = @(
        # Tier 0 - Shell Core
        'Initialize-Talon', 'Set-TalonPrompt', 'Set-TalonAliases',
        'Update-TalonProfile', 'Test-InteractiveSession', 'Show-TalonDashboard',
        'Invoke-TalonCachedData', 'Write-TalonHeader',
        # Tier 1 - System
        'Get-TalonHealth', 'Get-TalonSpec', 'Get-TalonUptime', 'Get-TalonDiskPressure',
        'Get-TalonResourceMap', 'Get-TalonPortMap', 'Get-TalonBattery', 'Get-TalonTempCheck',
        # Tier 1 - Security
        'Get-TalonFirewallAudit', 'Get-TalonBootMap', 'Get-TalonScheduledTaskRisk',
        'Get-TalonGhostPortAudit', 'Get-TalonSuspiciousProcess', 'Get-TalonEventStormAudit',
        'Get-TalonAdmin',
        # Tier 1 - Network
        'Get-TalonNetCheck', 'Get-TalonWifi', 'Get-TalonDnsBench', 'Get-TalonDnsCache',
        'Get-TalonNetworkTriage',
        # Tier 1 - Environment
        'Get-TalonEnvMap', 'Get-TalonPathAudit', 'Get-TalonApp', 'Get-TalonPatchHistory',
        'Get-TalonDriverAudit',
        # Tier 1 - Utility
        'Get-TalonShield', 'Get-TalonCertCheck',
        # Tier 1 - Dispatchers
        'Get-TalonSystem', 'Get-TalonAudit', 'Get-TalonNetwork', 'Get-TalonEnv'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('powershell', 'diagnostics', 'security', 'ollama', 'ai', 'windows')
            ProjectUri = 'https://github.com/talon-ps/talon'
            LicenseUri = 'https://github.com/talon-ps/talon/blob/main/LICENSE'
        }
    }
}
'@
$manifest | Set-Content (Join-Path $talonDir 'Talon.psd1') -Encoding UTF8
Write-Host "Updated Talon.psd1 with all 31 Tier 1 functions in FunctionsToExport"
