function Set-HawkAliases {
    <#
    .SYNOPSIS
    Registers all Hawkward global aliases.
    .DESCRIPTION
    Single source of truth for the daily-driver alias set: $script:HawkAliasMap
    below. The same map is registered in MODULE scope at dot-source time (so
    Export-ModuleMember -Alias exports a truthful surface to direct
    Import-Module consumers) and in GLOBAL scope by this function at profile
    load (so interactive sessions keep the shortcuts even before/without an
    explicit import). Every dashboard tile is backed by an entry here, so the
    menu is fully typeable: if it renders on `dash`, it resolves as a command.
    #>
    foreach ($name in $script:HawkAliasMap.Keys) {
        Set-Alias -Scope Global -Name $name -Value $script:HawkAliasMap[$name] -Force
    }
}

$script:HawkAliasMap = [ordered]@{
    # Core
    ai           = 'Invoke-HawkAI'
    proj         = 'Invoke-HawkProject'
    reload       = 'Update-HawkProfile'
    dash         = 'Show-HawkDashboard'
    hawkman      = 'Show-HawkManual'
    hawkhelp     = 'Invoke-HawkHelp'
    ggl          = 'Invoke-HawkSearch'
    hawkchat     = 'Invoke-HawkChat'
    hawkmodel    = 'Get-HawkModel'
    hawkdaily    = 'Invoke-HawkDaily'
    hawkwatch    = 'Watch-HawkDashboard'
    hawkdoctor   = 'Get-HawkDoctor'
    hawkcheck    = 'Test-HawkSetup'
    sysview      = 'Get-HawkSysView'
    secretredact = 'Protect-HawkSensitiveText'
    projaudit    = 'Get-HawkProjectAudit'
    hawkreport   = 'New-HawkReport'
    # Audits & maps
    ghostaudit   = 'Get-HawkGhostPortAudit'
    fwaudit      = 'Get-HawkFirewallAudit'
    susaudit     = 'Get-HawkSuspiciousProcessAudit'
    diskaudit    = 'Get-HawkDiskPressureAudit'
    taskaudit    = 'Get-HawkScheduledTaskRiskAudit'
    evntaudit    = 'Get-HawkEventStormAudit'
    evntmap      = 'Get-HawkEventMap'
    fwmap        = 'Get-HawkFirewallMap'
    envmap       = 'Get-HawkEnvMap'
    pathaudit    = 'Get-HawkPathAudit'
    portmap      = 'Get-HawkPortMap'
    nettriage    = 'Get-HawkNetworkTriage'
    resmap       = 'Get-HawkResourceMap'
    bootmap      = 'Get-HawkBootMap'
    defendermap  = 'Get-HawkDefenderAudit'
    regaudit     = 'Get-HawkRegAudit'
    ifeoaudit    = 'Get-HawkIfeoAudit'
    regsnap      = 'Save-HawkRegistrySnapshot'
    # Llama engine
    llamastart   = 'Start-HawkLlamaServer'
    llamastop    = 'Stop-HawkLlamaServer'
    aidoctor     = 'Get-HawkLlamaStatus'
    llamadoctor  = 'Invoke-HawkLlamaDoctor'
    # Hawk surface (v12.0)
    fix          = 'Invoke-HawkShortFix'
    stat         = 'Invoke-HawkShortStat'
    ask          = 'Invoke-HawkShortAsk'
    mem          = 'Invoke-HawkShortMem'
    hub          = 'Invoke-HawkCompanion'
    remember     = 'Add-HawkMemory'
    recall       = 'Search-HawkMemory'
    memmap       = 'Get-HawkMemoryMap'
    readmem      = 'Read-HawkMemory'
    sysdiag      = 'Get-HawkSystem'
    auditdiag    = 'Get-HawkAudit'
    netview      = 'Get-HawkNetwork'
    envdiag      = 'Get-HawkEnv'
    sysreview    = 'Invoke-HawkSystemReview'
    secaudit     = 'Invoke-HawkSecurityAudit'
    netdiag      = 'Invoke-HawkNetworkDiagnostics'
    threathunt   = 'Invoke-HawkThreatHunt'
    onboard      = 'Invoke-HawkOnboard'
    # System matrix (short daily names)
    specs        = 'Get-HawkSpecs'
    uptime       = 'Get-HawkUptime'
    raminfo      = 'Get-HawkRamInfo'
    battery      = 'Get-HawkBattery'
    temps        = 'Get-HawkThermals'
    fans         = 'Get-HawkFans'
    displays     = 'Get-HawkDisplays'
    hypervisor   = 'Get-HawkHypervisor'
    power        = 'Get-HawkPower'
    license      = 'Get-HawkLicense'
    # Network intel (short daily names)
    wifi         = 'Get-HawkWifi'
    dnsbench     = 'Get-HawkDnsBench'
    linkspeed    = 'Get-HawkLinkSpeed'
    shares       = 'Get-HawkShares'
    hostscheck   = 'Get-HawkHostsCheck'
    dnscache     = 'Get-HawkDnsCache'
    # Security scan (short daily names)
    shield       = 'Get-HawkShield'
    admins       = 'Get-HawkAdmins'
    apps         = 'Get-HawkApps'
    patchhistory = 'Get-HawkPatchHistory'
    driveraudit  = 'Get-HawkDriverAudit'
    certs        = 'Get-HawkCerts'
    # Storage (short daily names)
    clipcheck    = 'Get-HawkClipCheck'
    recent       = 'Get-HawkRecent'
    drivehealth  = 'Get-HawkDriveHealth'
    dumps        = 'Get-HawkDumps'
    badfiles     = 'Get-HawkBadFiles'
    links        = 'Get-HawkLinks'
    locked       = 'Get-HawkLocked'
    sparse       = 'Get-HawkSparse'
    compress     = 'Get-HawkCompress'
    # Workspace extras
    locate       = 'Get-HawkAppLocation'
    open         = 'Invoke-ExplorerHere'
}

# Module-scope registration at dot-source time: gives Export-ModuleMember
# -Alias real aliases to export, so the manifest's AliasesToExport is honest
# for direct Import-Module consumers. (Targets resolve lazily at invocation;
# definition order across part files does not matter.)
foreach ($name in $script:HawkAliasMap.Keys) {
    Set-Alias -Name $name -Value $script:HawkAliasMap[$name] -Force
}
