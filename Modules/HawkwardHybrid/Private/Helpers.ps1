# ── PRIVATE HELPERS ──────────────────────────────────────────────────────────

# ── 1. CENTRALIZED PLATFORM DATA CACHE SUITE ──────────────────────────────
function Invoke-HawkCachedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][int]$ExpirySeconds,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock
    )
    $now = Get-Date

    if ($script:HawkCacheStore.ContainsKey($Key)) {
        $entry = $script:HawkCacheStore[$Key]
        if (($now - $entry.Timestamp).TotalSeconds -lt $ExpirySeconds) {
            return $entry.Value
        }
    }

    $computedValue = &$ScriptBlock
    $script:HawkCacheStore[$Key] = [hashtable]::Synchronized(@{ Timestamp = $now; Value = $computedValue })
    return $computedValue
}

# ── 2. TYPED ARCHITECTURE CORE MEMORY SCHEMA ─────────────────────────────────────
class HawkMemoryEntry {
    [string] $Id
    [string] $Type
    [string[]]$Tags
    [string] $Text
    [string] $Source
    [string] $Created
    [string] $Confidence
    [bool]   $Pinned

    HawkMemoryEntry() {}

    HawkMemoryEntry([hashtable]$map) {
        $this.Id         = $map.Id
        $this.Type       = $map.Type
        $this.Tags       = $map.Tags
        $this.Text       = $map.Text
        $this.Source     = $map.Source
        $this.Created    = $map.Created
        $this.Confidence = $map.Confidence
        $this.Pinned     = [bool]$map.Pinned
    }
}

# ── 3. BASELINE ENVIRONMENT LOGIC ────────────────────────────────────────────────
function Write-HawkHeader {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Accept parameter for API consistency')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = 'Cyan'
    )
    if (-not $script:HawkSuppressHeaders) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-HawkInteractiveSession {
    if ($env:HAWK_NO_DASH -or $env:CI) { return $false }
    try {
        return [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected
    } catch {
        return $false
    }
}

function Test-HawkModulePublisher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ModuleName
    )

    $policy = $script:HawkTrustedModulePublishers[$ModuleName]
    if (-not $policy) {
        return [PSCustomObject]@{
            Module          = $ModuleName
            Trusted         = $true
            Status          = 'NoPolicy'
            Author          = ''
            CompanyName     = ''
            ExpectedAuthor  = ''
            ExpectedCompany = ''
            Message         = ''
        }
    }

    $module = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        return [PSCustomObject]@{
            Module          = $ModuleName
            Trusted         = $false
            Status          = 'Missing'
            Author          = ''
            CompanyName     = ''
            ExpectedAuthor  = $policy.Author
            ExpectedCompany = $policy.CompanyName
            Message         = 'Module is not installed.'
        }
    }

    $manifestPath = Join-Path $module.ModuleBase ($ModuleName + '.psd1')
    if (-not (Test-Path $manifestPath)) {
        return [PSCustomObject]@{
            Module          = $ModuleName
            Trusted         = $false
            Status          = 'Unverified'
            Author          = ''
            CompanyName     = ''
            ExpectedAuthor  = $policy.Author
            ExpectedCompany = $policy.CompanyName
            Message         = "Module manifest not found at $manifestPath."
        }
    }

    try {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $authorOk = $manifest.Author -eq $policy.Author
        $companyOk = $null -eq $policy.CompanyName -or @($manifest.CompanyName) -contains $policy.CompanyName
        $trusted = $authorOk -and $companyOk

        return [PSCustomObject]@{
            Module          = $ModuleName
            Trusted         = $trusted
            Status          = if ($trusted) { 'Trusted' } else { 'Untrusted' }
            Author          = $manifest.Author
            CompanyName     = $manifest.CompanyName
            ExpectedAuthor  = $policy.Author
            ExpectedCompany = $policy.CompanyName
            Message         = if ($trusted) { '' } else { 'Installed module metadata did not match the expected publisher profile.' }
        }
    } catch {
        return [PSCustomObject]@{
            Module          = $ModuleName
            Trusted         = $false
            Status          = 'VerificationFailed'
            Author          = ''
            CompanyName     = ''
            ExpectedAuthor  = $policy.Author
            ExpectedCompany = $policy.CompanyName
            Message         = $_.Exception.Message
        }
    }
}

function Get-HawkSafeAliasName {
    param([Parameter(Mandatory = $true)][string]$Name)
    if ($Name -like 'hawk-*') { return $Name }
    return "hawk-$Name"
}

function Format-HawkMemoryId {
    param()
    "mem_{0}_{1}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), ([Guid]::NewGuid().ToString('N').Substring(0, 6))
}

function Get-HawkMemorySearchTerm {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $stopWords = @('the','and','for','with','that','this','from','into','what','when','where','which','how','why','are','you','your','about','using','use')
    [regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9][a-z0-9._-]{2,}') | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stopWords } | Select-Object -Unique -First 18
}

function Format-HawkMemorySnippet {
    param([AllowNull()][string]$Text, [int]$MaxLength = 220)
    if ($null -eq $Text) { return '' }
    $clean = (($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' ').Trim()
    if ($clean.Length -le $MaxLength) { return $clean }
    return $clean.Substring(0, $MaxLength - 1) + '…'
}

function Format-HawkMarkdownCell {
    param([AllowNull()][string]$Text, [int]$MaxWidth = 0)
    if ($null -eq $Text) { $Text = '' }
    $clean = ($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' '
    $clean = $clean.Trim().Replace('|', '\|')
    if ($MaxWidth -gt 0 -and $clean.Length -gt $MaxWidth) { return $clean.Substring(0, $MaxWidth - 1) + '…' }
    return $clean
}

function Format-HawkReportCell {
    param([AllowNull()][string]$Text, [int]$Width)
    if ($Width -le 0) { return '' }; if ($null -eq $Text) { $Text = '' }
    $clean = (($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' ').Trim()
    if ($clean.Length -gt $Width) { return $clean.Substring(0, $Width - 1) + '…' }
    return $clean.PadRight($Width)
}

function Get-HawkReportPath {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', 'Internal helper called from New-HawkReport which has ShouldProcess')]
    param([string]$Ext = 'md')
    if (-not (Test-Path $script:HawkReportRoot)) { $null = New-Item -Path $script:HawkReportRoot -ItemType Directory -Force }
    return Join-Path $script:HawkReportRoot ("hawkreport-{0}.{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Ext)
}
