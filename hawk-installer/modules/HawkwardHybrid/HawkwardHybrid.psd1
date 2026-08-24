@{
    RootModule        = 'HawkwardHybrid.psm1'
    ModuleVersion     = '12.0.0'
    GUID              = '9f0235b3-6a75-4f62-9bbd-3fc479a9b2bc'
    Author            = 'shahr'
    CompanyName       = 'PowershellOps'
    Copyright         = '(c) 2026 shahr. All rights reserved.'
    Description       = 'PowershellOps Hawk profile: local PowerShell ops, diagnostics, AI, and security audit toolkit.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Get-HawkConfig'
        'Test-HawkNerdFont'
        'Write-HawkHeader'
        'Test-HawkInteractiveSession'
        'Install-HawkPrerequisites'
        'Import-HawkPrerequisites'
        'Set-HawkReadLine'
        'Set-HawkPrompt'
        'Initialize-HawkProfile'
        'Set-HawkAliases'
        'Update-HawkProfile'
        'Get-HawkAIIntent'
        'Get-HawkAIDataProfile'
        'New-HawkAIContextPacket'
        'Invoke-HawkAI'
        'Invoke-HawkChat'
        'Get-HawkModel'
        'Invoke-HawkDaily'
        'Watch-HawkDashboard'
        'Start-HawkLlamaServer'
        'Stop-HawkLlamaServer'
        'Get-HawkLlamaStatus'
        'Invoke-HawkLlamaDoctor'
        'Invoke-HawkProject'
        'Protect-HawkSensitiveText'
        'Get-HawkGhostPortAudit'
        'Get-HawkFirewallAudit'
        'Get-HawkSuspiciousProcessAudit'
        'Get-HawkDefenderAudit'
        'Get-HawkDiskPressureAudit'
        'Get-HawkScheduledTaskRiskAudit'
        'Get-HawkEventStormAudit'
        'Get-HawkFirewallMap'
        'Get-HawkTcpListeners'
        'Get-HawkPortMap'
        'Get-HawkResourceMap'
        'Get-HawkBootMap'
        'Get-HawkRegAudit'
        'Get-HawkIfeoAudit'
        'Save-HawkRegistrySnapshot'
        'Get-HawkEventMap'
        'Get-HawkEnvMap'
        'Get-HawkPathAudit'
        'Get-HawkNetworkTriage'
        'Get-HawkProjectAudit'
        'Get-HawkDoctor'
        'Get-HawkSysView'
        'Test-HawkSetup'
        'Show-HawkDashboard'
        'Show-HawkManual'
        'Invoke-HawkHelp'
        'Invoke-HawkSearch'
        'ConvertTo-HawkMarkdownTable'
        'ConvertTo-HawkReportMarkdown'
        'New-HawkReportPath'
        'Write-HawkReportTable'
        'Write-HawkReportConsole'
        'New-HawkReport'
        'Get-HawkSpecs'
        'Get-HawkUptime'
        'Get-HawkRamInfo'
        'Get-HawkBattery'
        'Get-HawkDisplays'
        'Get-HawkHypervisor'
        'Get-HawkPower'
        'Get-HawkThermals'
        'Get-HawkFans'
        'Get-HawkLicense'
        'Get-HawkWifi'
        'Get-HawkDnsBench'
        'Get-HawkLinkSpeed'
        'Get-HawkShares'
        'Get-HawkHostsCheck'
        'Get-HawkDnsCache'
        'Get-HawkShield'
        'Get-HawkAdmins'
        'Get-HawkApps'
        'Get-HawkPatchHistory'
        'Get-HawkDriverAudit'
        'Get-HawkCerts'
        'Get-HawkClipCheck'
        'Get-HawkRecent'
        'Get-HawkDriveHealth'
        'Get-HawkDumps'
        'Get-HawkBadFiles'
        'Get-HawkLinks'
        'Get-HawkLocked'
        'Get-HawkSparse'
        'Get-HawkCompress'
        'Get-HawkAppLocation'
        'Invoke-ExplorerHere'
        # Hawk surface wave v12.0
        'Get-HawkSettings'
        'Set-HawkSetting'
        'Get-HawkMemoryFile'
        'Add-HawkMemory'
        'Read-HawkMemory'
        'Search-HawkMemory'
        'Get-HawkMemoryMap'
        'Get-HawkNetCheck'
        'New-HawkCheckResult'
        'Complete-HawkWorkflow'
        'Show-HawkWorkflowResult'
        'Invoke-HawkSystemReview'
        'Invoke-HawkSecurityAudit'
        'Invoke-HawkNetworkDiagnostics'
        'Invoke-HawkThreatHunt'
        'Invoke-HawkChangeAudit'
        'Invoke-HawkComplianceCheck'
        'Get-HawkSystem'
        'Get-HawkAudit'
        'Get-HawkNetwork'
        'Get-HawkEnv'
        'Invoke-HawkCompanion'
        'Invoke-HawkShortFix'
        'Invoke-HawkShortStat'
        'Invoke-HawkShortAsk'
        'Invoke-HawkShortMem'
        'Invoke-HawkOnboard'
        'Invoke-HawkOnboardStep1'
        'Invoke-HawkOnboardStep2'
        'Invoke-HawkOnboardStep3'
        'Invoke-HawkOnboardStep4'
        'Invoke-HawkOnboardStep5'
        'Invoke-HawkOnboardStep6'
        'Get-HawkSourceQualityScore'
        'Test-HawkPromptInjection'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @(
        # Core
        'ai','proj','reload','dash','hawkman','hawkhelp','ggl',
        'hawkchat','hawkmodel','hawkdaily','hawkwatch','hawkdoctor','hawkcheck',
        'sysview','secretredact','projaudit','hawkreport',
        # Audits & maps
        'ghostaudit','fwaudit','susaudit','diskaudit','taskaudit','evntaudit',
        'evntmap','fwmap','envmap','pathaudit','portmap','nettriage','resmap',
        'bootmap','defendermap','regaudit','ifeoaudit','regsnap',
        # Llama engine
        'llamastart','llamastop','aidoctor','llamadoctor',
        # Hawk surface (v12.0)
        'fix','stat','ask','mem','hub','remember','recall','memmap','readmem',
        'sysdiag','auditdiag','netview','envdiag','sysreview','secaudit',
        'netdiag','threathunt','onboard',
        # System matrix (short daily names)
        'specs','uptime','raminfo','battery','temps','fans','displays',
        'hypervisor','power','license',
        # Network intel (short daily names)
        'wifi','dnsbench','linkspeed','shares','hostscheck','dnscache',
        # Security scan (short daily names)
        'shield','admins','apps','patchhistory','driveraudit','certs',
        # Storage (short daily names)
        'clipcheck','recent','drivehealth','dumps','badfiles','links',
        'locked','sparse','compress',
        # Workspace extras
        'locate','open'
    )
    PrivateData       = @{
        PSData = @{
            Tags       = @('PowerShell', 'Diagnostics', 'Security', 'AI', 'Llama', 'Windows', 'Automation', 'System-Information', 'LocalLLM')
            ProjectUri = 'https://github.com/shahriarhaqueabir/PowershellOps'
            IconUri    = 'https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/icon.png'
        }
    }
}
