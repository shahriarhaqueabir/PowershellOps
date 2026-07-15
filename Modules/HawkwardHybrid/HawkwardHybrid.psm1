# ==============================================================================
# PowershellOps 11.3 - Integrated Operational Core Engine (Production Refactored)
# ==============================================================================
# Private helpers + Public functions are dot-sourced from Private/*.ps1 and Public/*.ps1

$script:HawkVersion = '11.3'
$script:HawkAppName = 'PowershellOps'
$script:HawkVibe    = 'Modern'
$script:HawkRequiredModules = @('Terminal-Icons', 'PSReadLine', 'PSTree')
$script:HawkTrustedModulePublishers = @{
    'Terminal-Icons' = @{ Author = 'Brandon Olin'; CompanyName = 'devblackops' }
    'PSReadLine'     = @{ Author = 'Microsoft Corporation'; CompanyName = 'PowerShellTeam' }
    'PSTree'         = @{ Author = 'Santiago Squarzon'; CompanyName = 'santisq' }
}
$script:HawkWorkspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:HawkDefaultProjectRoot = if ($env:HAWK_PROJECT_ROOT) { $env:HAWK_PROJECT_ROOT } elseif ($script:HawkWorkspaceRoot) { $script:HawkWorkspaceRoot } elseif ($PROFILE -and $PROFILE.CurrentUserCurrentHost) { Split-Path -Parent $PROFILE.CurrentUserCurrentHost } else { Join-Path $HOME 'Projects' }
$script:HawkSuppressHeaders = $false
$script:HawkSensitiveNamePattern = '(?i)(secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)'
$script:HawkLastFirewallFilterError = $null
$script:HawkReportRoot = Join-Path $script:HawkWorkspaceRoot 'Reports'
$script:HawkMemoryRoot = Join-Path $script:HawkWorkspaceRoot 'Memory'
$script:HawkMemoryFile = Join-Path $script:HawkMemoryRoot 'hawk-memory.jsonl'
$script:HawkFirstRunSentinel = Join-Path $script:HawkWorkspaceRoot '.hawk_first_run'

# Initialize thread-safe data store cache allocation
if (-not $script:HawkCacheStore) {
    $script:HawkCacheStore = [hashtable]::Synchronized(@{})
}

# Initialize search rate-limiting tracker
$script:HawkLastSearchTime = $null

# ── DOT-SOURCE PRIVATE HELPERS ────────────────────────────────────────────────
$privatePath = Join-Path $PSScriptRoot 'Private'
Get-ChildItem "$privatePath\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

# ── DOT-SOURCE PUBLIC FUNCTIONS ──────────────────────────────────────────────
$publicPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem "$publicPath\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

# ── MODULE EXPORT ─────────────────────────────────────────────────────────────
Export-ModuleMember -Function @(
    'Add-HawkMemory',
    'Build-HawkAIContextPacket',
    'Build-HawkAIMemoryContext',
    'ConvertTo-HawkMarkdownTable',
    'ConvertTo-HawkReportMarkdown',
    'Format-HawkMarkdownCell',
    'Format-HawkMemoryId',
    'Format-HawkMemorySnippet',
    'Format-HawkReportCell',
    'Get-HawkAdmin',
    'Get-HawkAIDataProfile',
    'Get-HawkAIIntent',
    'Get-HawkAIStatus',
    'Get-HawkApp',
    'Get-HawkAppLocation',
    'Get-HawkAudit',
    'Get-HawkBadFile',
    'Get-HawkBattery',
    'Get-HawkBootMap',
    'Get-HawkCert',
    'Get-HawkClipCheck',
    'Get-HawkCompressedDir',
    'Get-HawkDiskPressureAudit',
    'Get-HawkDisplay',
    'Get-HawkDnsBench',
    'Get-HawkDnsCache',
    'Get-HawkDriveHealth',
    'Get-HawkDriverAudit',
    'Get-HawkDump',
    'Get-HawkEnv',
    'Get-HawkEnvMap',
    'Get-HawkEstablished',
    'Get-HawkEventStormAudit',
    'Get-HawkFirewallAudit',
    'Get-HawkGhostPortAudit',
    'Get-HawkHealth',
    'Get-HawkHostsCheck',
    'Get-HawkHypervisor',
    'Get-HawkLicense',
    'Get-HawkLink',
    'Get-HawkLinkSpeed',
    'Get-HawkLock',
    'Get-HawkMemoryFile',
    'Get-HawkMemoryMap',
    'Get-HawkMemorySearchTerm',
    'Get-HawkNetCheck',
    'Get-HawkNetwork',
    'Get-HawkNetworkTriage',
    'Get-HawkPatchHistory',
    'Get-HawkPathAudit',
    'Get-HawkPortMap',
    'Get-HawkPower',
    'Get-HawkProject',
    'Get-HawkPromptGitSegment',
    'Get-HawkPromptText',
    'Get-HawkRamInfo',
    'Get-HawkRecent',
    'Get-HawkReportPath',
    'Get-HawkResourceMap',
    'Get-HawkScheduledTaskRiskAudit',
    'Get-HawkShare',
    'Get-HawkShield',
    'Get-HawkSourceQualityScore',
    'Get-HawkSparseFile',
    'Get-HawkSpec',
    'Get-HawkSuspiciousProcessAudit',
    'Get-HawkSystem',
    'Get-HawkTempCheck',
    'Get-HawkUptime',
    'Get-HawkWifi',
    'Import-HawkPrerequisite',
    'Initialize-HawkProfile',
    'Install-HawkPrerequisite',
    'Invoke-ExplorerHere',
    'Invoke-HawkAI',
    'Invoke-HawkCachedData',
    'Invoke-HawkChangeAudit',
    'Invoke-HawkComplianceCheck',
    'Invoke-HawkDailyOps',
    'Invoke-HawkNetworkDiagnostics',
    'Invoke-HawkProject',
    'Invoke-HawkSearch',
    'Invoke-HawkSecurityAudit',
    'Invoke-HawkSystemReview',
    'Invoke-HawkThreatHunt',
    'New-HawkReport',
    'Protect-HawkSensitiveText',
    'Read-HawkMemory',
    'Resolve-HawkDuckDuckGoHref',
    'Search-HawkMemory',
    'Set-HawkAliases',
    'Set-HawkPrompt',
    'Set-HawkReadLine',
    'Show-HawkDashboard',
    'Show-HawkManual',
    'Test-HawkInteractiveSession',
    'Test-HawkModulePublisher',
    'Test-HawkPromptInjection',
    'Update-HawkModule',
    'Update-HawkProfile',
    'Watch-HawkDashboard',
    'Write-HawkHeader',
    'Write-HawkReportTable'
) -Alias *
