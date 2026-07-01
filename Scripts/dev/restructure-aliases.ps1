$psm1 = "$HOME\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw

# Replace: the function Set-TalonAliases becomes a module-level alias creator + wrapper function
$oldFunction = @'
function Set-TalonAliases {
    <#
    .SYNOPSIS
        Register all short aliases. Called once at startup.
    #>
    [CmdletBinding()]
    param()

    $mappings = @(
        @('health',    'Get-TalonHealth')
        @('spec',      'Get-TalonSpec')
        @('uptime',    'Get-TalonUptime')
        @('disk',      'Get-TalonDiskPressure')
        @('hog',       'Get-TalonResourceMap')
        @('ports',     'Get-TalonPortMap')
        @('battery',   'Get-TalonBattery')
        @('temp',      'Get-TalonTempCheck')
        @('fwaudit',   'Get-TalonFirewallAudit')
        @('boot',      'Get-TalonBootMap')
        @('taskaudit', 'Get-TalonScheduledTaskRisk')
        @('ghostaudit','Get-TalonGhostPortAudit')
        @('susaudit',  'Get-TalonSuspiciousProcess')
        @('evntaudit', 'Get-TalonEventStormAudit')
        @('admin',     'Get-TalonAdmin')
        @('netcheck',  'Get-TalonNetCheck')
        @('wifi',      'Get-TalonWifi')
        @('dnsbench',  'Get-TalonDnsBench')
        @('dnscache',  'Get-TalonDnsCache')
        @('nettriage', 'Get-TalonNetworkTriage')
        @('envmap',    'Get-TalonEnvMap')
        @('pathaudit', 'Get-TalonPathAudit')
        @('app',       'Get-TalonApp')
        @('patch',     'Get-TalonPatchHistory')
        @('driveraudit','Get-TalonDriverAudit')
        @('ai',         'Invoke-TalonAI')
        @('ggl',        'Invoke-TalonSearch')
        @('secretredact','Protect-TalonSensitiveText')
        @('aistatus',   'Get-TalonAIStatus')
        @('injecttest', 'Test-TalonPromptInjection')
        @('quality',    'Get-TalonSourceQuality')
        @('remember',  'Add-TalonMemory')
        @('recall',    'Search-TalonMemory')
        @('memmap',    'Get-TalonMemoryMap')
        @('report',    'New-TalonReport')
        @('dash',      'Show-TalonDashboard')
        @('reload',    'Update-TalonProfile')
        @('shield',    'Get-TalonShield')
        @('certs',     'Get-TalonCertCheck')
        @('sys',       'Get-TalonSystem')
        @('audit',     'Get-TalonAudit')
        @('net',       'Get-TalonNetwork')
        @('env',       'Get-TalonEnv')
    )

    foreach ($m in $mappings) {
        Set-Alias -Scope Global -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force
    }
}
'@

$newFunction = @'
# ── ALIASES (created at module scope on import, exported via AliasesToExport) ─

# Define alias mappings once — used both at module load and in Set-TalonAliases
$script:TalonAliasMappings = @(
    @('health',    'Get-TalonHealth')
    @('spec',      'Get-TalonSpec')
    @('uptime',    'Get-TalonUptime')
    @('disk',      'Get-TalonDiskPressure')
    @('hog',       'Get-TalonResourceMap')
    @('ports',     'Get-TalonPortMap')
    @('battery',   'Get-TalonBattery')
    @('temp',      'Get-TalonTempCheck')
    @('fwaudit',   'Get-TalonFirewallAudit')
    @('boot',      'Get-TalonBootMap')
    @('taskaudit', 'Get-TalonScheduledTaskRisk')
    @('ghostaudit','Get-TalonGhostPortAudit')
    @('susaudit',  'Get-TalonSuspiciousProcess')
    @('evntaudit', 'Get-TalonEventStormAudit')
    @('admin',     'Get-TalonAdmin')
    @('netcheck',  'Get-TalonNetCheck')
    @('wifi',      'Get-TalonWifi')
    @('dnsbench',  'Get-TalonDnsBench')
    @('dnscache',  'Get-TalonDnsCache')
    @('nettriage', 'Get-TalonNetworkTriage')
    @('envmap',    'Get-TalonEnvMap')
    @('pathaudit', 'Get-TalonPathAudit')
    @('app',       'Get-TalonApp')
    @('patch',     'Get-TalonPatchHistory')
    @('driveraudit','Get-TalonDriverAudit')
    @('ai',         'Invoke-TalonAI')
    @('ggl',        'Invoke-TalonSearch')
    @('secretredact','Protect-TalonSensitiveText')
    @('aistatus',   'Get-TalonAIStatus')
    @('injecttest', 'Test-TalonPromptInjection')
    @('quality',    'Get-TalonSourceQuality')
    @('remember',  'Add-TalonMemory')
    @('recall',    'Search-TalonMemory')
    @('memmap',    'Get-TalonMemoryMap')
    @('report',    'New-TalonReport')
    @('dash',      'Show-TalonDashboard')
    @('reload',    'Update-TalonProfile')
    @('shield',    'Get-TalonShield')
    @('certs',     'Get-TalonCertCheck')
    @('sys',       'Get-TalonSystem')
    @('audit',     'Get-TalonAudit')
    @('net',       'Get-TalonNetwork')
    @('env',       'Get-TalonEnv')
)

# Create aliases at module scope — runs during Import-Module
foreach ($m in $script:TalonAliasMappings) {
    Set-Alias -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force
}

function Set-TalonAliases {
    <#
    .SYNOPSIS
        Re-register all short aliases in global scope.
        (Aliases are already exported by the module; this is for explicit re-creation.)
    #>
    [CmdletBinding()]
    param()
    foreach ($m in $script:TalonAliasMappings) {
        Set-Alias -Scope Global -Name $m[0] -Value $m[1] -ErrorAction SilentlyContinue -Force
    }
}
'@

$newContent = $content -replace [regex]::Escape($oldFunction), $newFunction

# Also remove the now-redundant module-load call
$newContent = $newContent -replace "`n# ── CREATE ALIASES AT MODULE LOAD ──────────────────────`nSet-TalonAliases`n", ''

Set-Content -Path $psm1 -Value $newContent -Encoding UTF8 -Force
Write-Host "Talon.psm1 restructured: aliases created at module scope, Set-TalonAliases preserved for backward compat."
