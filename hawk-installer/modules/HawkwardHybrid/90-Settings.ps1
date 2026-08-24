function Get-HawkSettings {
    <#
    .SYNOPSIS
    Reads the Hawk settings store (hawk-settings.json), applying defaults.
    .DESCRIPTION
    Returns a pscustomobject with projectRoot, memoryRoot, llamaEndpoint,
    model and modelfile. Missing or unreadable files fall back to defaults.
    .EXAMPLE
    Get-HawkSettings | Select-Object projectRoot, memoryRoot
    #>
    [CmdletBinding()]
    param()

    $settingsPath = if ($env:HAWK_SETTINGS_PATH) { $env:HAWK_SETTINGS_PATH } else { $script:HawkSettingsPath }
    $settingsPath = & Resolve-HawkMigratedPath -Path $settingsPath -LegacyName 'ops-settings.json'
    $defaults = [ordered]@{
        projectRoot   = $script:HawkDefaultProjectRoot
        memoryRoot    = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Memory'
        llamaEndpoint = $script:HawkLlamaEndpoint
        model         = $null
        modelfile     = $null
    }
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            $stored = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            foreach ($prop in $stored.PSObject.Properties.Name) {
                if ($prop -in $defaults.Keys -and $null -ne $stored.$prop -and "$($stored.$prop)" -ne '') {
                    $defaults[$prop] = $stored.$prop
                }
            }
        }
        catch {
            Write-Host '  [!!] hawk-settings.json unreadable; using defaults.' -ForegroundColor Yellow
        }
    }
    [pscustomobject]$defaults
}

function Set-HawkSetting {
    <#
    .SYNOPSIS
    Merges a single key into the Hawk settings store.
    .PARAMETER Name
    Setting key (e.g. projectRoot, memoryRoot, llamaEndpoint, model, modelfile).
    .PARAMETER Value
    Value to persist. Use $null to clear.
    .EXAMPLE
    Set-HawkSetting -Name projectRoot -Value 'E:\Projects'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowNull()]$Value
    )

    $settings = @{}
    $settingsPath = if ($env:HAWK_SETTINGS_PATH) { $env:HAWK_SETTINGS_PATH } else { $script:HawkSettingsPath }
    $settingsPath = & Resolve-HawkMigratedPath -Path $settingsPath -LegacyName 'ops-settings.json'
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).PSObject.Properties |
                ForEach-Object { $settings[$_.Name] = $_.Value }
        }
        catch {
            # Never silently discard existing settings: quarantine the corrupt
            # file so this write starts clean but the old data stays recoverable.
            $quarantine = "$settingsPath.corrupt-$([datetime]::Now.ToString('yyyyMMdd-HHmmss'))"
            Move-Item -LiteralPath $settingsPath -Destination $quarantine -Force
            Write-Warning ("Settings file was corrupt; quarantined to '{0}'. Previous values were not merged into this write." -f $quarantine)
        }
    }
    $settings[$Name] = $Value

    $dir = Split-Path -Parent $settingsPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    Write-Host ('  [OK] Saved {0} to hawk-settings.json' -f $Name) -ForegroundColor Green
}

class HawkMemoryEntry {
    [string]$Id
    [string]$Type
    [string[]]$Tags
    [string]$Text
    [string]$Source
    [datetime]$Created
    [double]$Confidence
    [bool]$Pinned
    [int]$Score
}

function Get-HawkMemoryFile {
    <#
    .SYNOPSIS
    Returns the resolved path to hawk-memory.jsonl, creating the Memory dir.
    .DESCRIPTION
    Memory root comes from hawk-settings.json (memoryRoot) and defaults to
    Documents\PowerShell\Memory. The directory is created on demand.
    .EXAMPLE
    Get-HawkMemoryFile   # -> C:\Users\<you>\Documents\PowerShell\Memory\hawk-memory.jsonl
    Function: Get-HawkMemoryFile.
    #>
    [CmdletBinding()][OutputType([string])]
    param([switch]$NoCreate)

    $root = (Get-HawkSettings).memoryRoot
    if (-not (Test-Path -LiteralPath $root)) {
        if ($NoCreate) { return (& Resolve-HawkMigratedPath -Path (Join-Path $root 'hawk-memory.jsonl') -LegacyName 'ops-memory.jsonl') }
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return (& Resolve-HawkMigratedPath -Path (Join-Path $root 'hawk-memory.jsonl') -LegacyName 'ops-memory.jsonl')
}

function Add-HawkMemory {
    <#
    .SYNOPSIS
    Appends an operational note to semantic memory (JSONL).
    .DESCRIPTION
    Text is auto-redacted through Protect-HawkSensitiveText before storage.
    Each entry gets an Id, Type, Tags, Source, Created timestamp, Confidence
    score and Pinned flag.
    .PARAMETER Text
    The note body. Secrets in key=value or JSON form are redacted.
    .PARAMETER Type
    Entry kind: note, preference, fact, incident, command or link.
    .PARAMETER Tags
    One or more free-form tags for later filtering.
    .PARAMETER Source
    Where the note came from (manual, ai, ggl, ...).
    .PARAMETER Pinned
    Pin the entry; pinned entries get a relevance bonus during recall.
    .EXAMPLE
    remember "Prefer Q4_K_M for 1.7B models" -Tag preference -Pinned
    Alias: remember.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline = $true)][string]$Text,
        [ValidateSet('note', 'preference', 'fact', 'incident', 'command', 'link')][string]$Type = 'note',
        [string[]]$Tags = @(),
        [string]$Source = 'manual',
        [ValidateRange(0, 1)][double]$Confidence = 0.8,
        [switch]$Pinned
    )

    process {
        $entry = [HawkMemoryEntry]@{
            Id         = [guid]::NewGuid().ToString('N').Substring(0, 12)
            Type       = $Type
            Tags       = @($Tags)
            Text       = ($Text | Protect-HawkSensitiveText)
            Source     = $Source
            Created    = (Get-Date)
            Confidence = $Confidence
            Pinned     = [bool]$Pinned
            Score      = 0
        }

        $line = @{
            id         = $entry.Id
            type       = $entry.Type
            tags       = $entry.Tags
            text       = $entry.Text
            source     = $entry.Source
            created    = $entry.Created.ToString('o')
            confidence = $entry.Confidence
            pinned     = $entry.Pinned
        } | ConvertTo-Json -Compress

        Add-Content -LiteralPath (Get-HawkMemoryFile) -Value $line -Encoding UTF8
        Write-Host ('  [OK] Remembered [{0}] {1}' -f $entry.Id, ($entry.Tags -join ',')) -ForegroundColor Green
        return $entry
    }
}

function Read-HawkMemory {
    <#
    .SYNOPSIS
    Returns all memory entries as typed HawkMemoryEntry objects.
    .DESCRIPTION
    Malformed lines are skipped with a verbose message rather than failing.
    .EXAMPLE
    readmem | Sort-Object Created -Descending | Select-Object -First 5
    Alias: readmem.
    #>
    [CmdletBinding()]
    param()

    $path = Get-HawkMemoryFile
    if (-not (Test-Path -LiteralPath $path)) { return @() }

    foreach ($line in (Get-Content -LiteralPath $path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $j = $line | ConvertFrom-Json
            [HawkMemoryEntry]@{
                Id         = [string]$j.id
                Type       = [string]$j.type
                Tags       = @($j.tags)
                Text       = [string]$j.text
                Source     = [string]$j.source
                Created    = [datetime]$j.created
                Confidence = $(if ($null -ne $j.confidence) { [double]$j.confidence } else { 1.0 })
                Pinned     = [bool]$j.pinned
                Score      = 0
            }
        }
        catch {
            Write-Verbose ('Skipping malformed memory line: {0}' -f $_.Exception.Message)
        }
    }
}

function Search-HawkMemory {
    <#
    .SYNOPSIS
    Term-scores memory entries and returns the best matches.
    .DESCRIPTION
    Each query term scores +2 when it hits entry text and +1 when it hits a
    tag; pinned entries get a flat +2 bonus. Zero-score entries are dropped.
    .PARAMETER Query
    Space-separated terms to match.
    .PARAMETER Pinned
    Restrict to pinned entries only.
    .PARAMETER First
    Maximum number of results (default 20).
    .EXAMPLE
    recall "quantization" -First 5
    Alias: recall.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Query,
        [switch]$Pinned,
        [ValidateRange(1, 1000)][int]$First = 20
    )

    $entries = @(Read-HawkMemory)
    if ($Pinned) { $entries = @($entries | Where-Object Pinned) }

    if ($Query) {
        $terms = @($Query -split '\s+' | Where-Object { $_ })
        foreach ($e in $entries) {
            $score = 0
            foreach ($t in $terms) {
                if ($e.Text -match [regex]::Escape($t)) { $score += 2 }
                if (($e.Tags -join ' ') -match [regex]::Escape($t)) { $score += 1 }
            }
            if ($e.Pinned) { $score += 2 }
            $e.Score = $score
        }
        $entries = @($entries | Where-Object Score -gt 0 | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Created'; Descending = $true })
    }
    else {
        $entries = @($entries | Sort-Object Created -Descending)
    }

    return @($entries | Select-Object -First $First)
}

function Get-HawkMemoryMap {
    <#
    .SYNOPSIS
    Lists memory entries newest-first with optional tag/pin filters.
    .PARAMETER Tag
    Only entries carrying this exact tag.
    .PARAMETER Pinned
    Only pinned entries.
    .PARAMETER First
    Maximum rows to render (default 25).
    .EXAMPLE
    memmap -Pinned
    Alias: memmap.
    #>
    [CmdletBinding()]
    param(
        [string]$Tag,
        [switch]$Pinned,
        [ValidateRange(1, 1000)][int]$First = 25
    )

    $entries = @(Read-HawkMemory)
    if ($Tag) { $entries = @($entries | Where-Object { $_.Tags -contains $Tag }) }
    if ($Pinned) { $entries = @($entries | Where-Object Pinned) }
    $entries = @($entries | Sort-Object Created -Descending | Select-Object -First $First)

    Write-Host ("`n  HAWK MEMORY MAP ({0} entries)" -f $entries.Count) -ForegroundColor Cyan
    foreach ($e in $entries) {
        $flag = if ($e.Pinned) { '*' } else { ' ' }
        Write-Host ('  [{0}] {1}{2} {3}' -f $e.Created.ToString('yyyy-MM-dd'), $flag, $e.Id, ($e.Tags -join ',')) -NoNewline
        Write-Host ('  ' + $e.Text.Substring(0, [Math]::Min(70, $e.Text.Length))) -ForegroundColor DarkGray
    }
    return $entries
}

