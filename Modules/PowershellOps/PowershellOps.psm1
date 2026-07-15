# ==============================================================================
# PowershellOps 11.3 - Integrated Operational Core Engine (Production Refactored)
# ==============================================================================
# Private helpers + Public functions are dot-sourced from Private/*.ps1 and Public/*.ps1

$script:OpsVersion = '11.3'
$script:OpsAppName = 'PowershellOps'
$script:OpsVibe    = 'Modern'
$script:OpsRequiredModules = @('Terminal-Icons', 'PSReadLine', 'PSTree')
$script:OpsTrustedModulePublishers = @{
    'Terminal-Icons' = @{ Author = 'Brandon Olin'; CompanyName = 'devblackops' }
    'PSReadLine'     = @{ Author = 'Microsoft Corporation'; CompanyName = 'PowerShellTeam' }
    'PSTree'         = @{ Author = 'Santiago Squarzon'; CompanyName = 'santisq' }
}
$script:OpsWorkspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:OpsDefaultProjectRoot = if ($env:Ops_PROJECT_ROOT) { $env:Ops_PROJECT_ROOT } elseif ($script:OpsWorkspaceRoot) { $script:OpsWorkspaceRoot } elseif ($PROFILE -and $PROFILE.CurrentUserCurrentHost) { Split-Path -Parent $PROFILE.CurrentUserCurrentHost } else { Join-Path $HOME 'Projects' }
$script:OpsSuppressHeaders = $false
$script:OpsSensitiveNamePattern = '(?i)(secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)'
$script:OpsLastFirewallFilterError = $null
$script:OpsReportRoot = Join-Path $script:OpsWorkspaceRoot 'Reports'
$script:OpsMemoryRoot = Join-Path $script:OpsWorkspaceRoot 'Memory'
$script:OpsMemoryFile = Join-Path $script:OpsMemoryRoot 'ops-memory.jsonl'
$script:OpsFirstRunSentinel = Join-Path $script:OpsWorkspaceRoot '.Ops_first_run'

# Initialize thread-safe data store cache allocation
if (-not $script:OpsCacheStore) {
    $script:OpsCacheStore = [hashtable]::Synchronized(@{})
}

# Initialize search rate-limiting tracker
$script:OpsLastSearchTime = $null

# -- DOT-SOURCE PRIVATE HELPERS ------------------------------------------------
$privatePath = Join-Path $PSScriptRoot 'Private'
Get-ChildItem "$privatePath\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

# -- DOT-SOURCE PUBLIC FUNCTIONS ----------------------------------------------
$publicPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem "$publicPath\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

# -- MODULE EXPORT -------------------------------------------------------------
Export-ModuleMember -Function @(
    'Add-OpsMemory',
    'Build-OpsAIContextPacket',
    'Build-OpsAIMemoryContext',
    'ConvertTo-OpsMarkdownTable',
    'ConvertTo-OpsReportMarkdown',
    'Format-OpsMarkdownCell',
    'Format-OpsMemoryId',
    'Format-OpsMemorySnippet',
    'Format-OpsReportCell',
    'Get-OpsAdmin',
    'Get-OpsAIDataProfile',
    'Get-OpsAIIntent',
    'Get-OpsAIStatus',
    'Get-OpsApp',
    'Get-OpsAppLocation',
    'Get-OpsAudit',
    'Get-OpsBadFile',
    'Get-OpsBattery',
    'Get-OpsBootMap',
    'Get-OpsCert',
    'Get-OpsClipCheck',
    'Get-OpsCompressedDir',
    'Get-OpsDiskPressureAudit',
    'Get-OpsDisplay',
    'Get-OpsDnsBench',
    'Get-OpsDnsCache',
    'Get-OpsDriveHealth',
    'Get-OpsDriverAudit',
    'Get-OpsDump',
    'Get-OpsEnv',
    'Get-OpsEnvMap',
    'Get-OpsEstablished',
    'Get-OpsEventStormAudit',
    'Get-OpsFirewallAudit',
    'Get-OpsGhostPortAudit',
    'Get-OpsHealth',
    'Get-OpsHostsCheck',
    'Get-OpsHypervisor',
    'Get-OpsLicense',
    'Get-OpsLink',
    'Get-OpsLinkSpeed',
    'Get-OpsLock',
    'Get-OpsMemoryFile',
    'Get-OpsMemoryMap',
    'Get-OpsMemorySearchTerm',
    'Get-OpsNetCheck',
    'Get-OpsNetwork',
    'Get-OpsNetworkTriage',
    'Get-OpsPatchHistory',
    'Get-OpsPathAudit',
    'Get-OpsPortMap',
    'Get-OpsPower',
    'Get-OpsProject',
    'Get-OpsPromptGitSegment',
    'Get-OpsPromptText',
    'Get-OpsRamInfo',
    'Get-OpsRecent',
    'Get-OpsReportPath',
    'Get-OpsResourceMap',
    'Get-OpsScheduledTaskRiskAudit',
    'Get-OpsShare',
    'Get-OpsShield',
    'Get-OpsSourceQualityScore',
    'Get-OpsSparseFile',
    'Get-OpsSpec',
    'Get-OpsSuspiciousProcessAudit',
    'Get-OpsSystem',
    'Get-OpsTempCheck',
    'Get-OpsUptime',
    'Get-OpsWifi',
    'Import-OpsPrerequisite',
    'Initialize-OpsProfile',
    'Install-OpsPrerequisite',
    'Invoke-ExplorerHere',
    'Invoke-OpsAI',
    'Invoke-OpsCachedData',
    'Invoke-OpsChangeAudit',
    'Invoke-OpsComplianceCheck',
    'Invoke-OpsDailyOps',
    'Invoke-OpsNetworkDiagnostics',
    'Invoke-OpsProject',
    'Invoke-OpsSearch',
    'Invoke-OpsSecurityAudit',
    'Invoke-OpsSystemReview',
    'Invoke-OpsThreatHunt',
    'New-OpsReport',
    'Protect-OpsSensitiveText',
    'Read-OpsMemory',
    'Resolve-OpsDuckDuckGoHref',
    'Search-OpsMemory',
    'Set-OpsAliases',
    'Set-OpsPrompt',
    'Set-OpsReadLine',
    'Show-OpsDashboard',
    'Show-OpsManual',
    'Test-OpsInteractiveSession',
    'Test-OpsModulePublisher',
    'Test-OpsPromptInjection',
    'Update-OpsModule',
    'Update-OpsProfile',
    'Watch-OpsDashboard',
    'Write-OpsHeader',
    'Write-OpsReportTable'
) -Alias *


