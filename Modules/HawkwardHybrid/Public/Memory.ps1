# ── PUBLIC: MEMORY FUNCTIONS ───────────────────────────────────────────────

function Get-HawkMemoryFile {
    if (-not (Test-Path $script:HawkMemoryRoot)) { $null = New-Item -Path $script:HawkMemoryRoot -ItemType Directory -Force }
    return $script:HawkMemoryFile
}

function Read-HawkMemory {
    if (-not (Test-Path $script:HawkMemoryFile)) { return @() }
    Get-Content -Path $script:HawkMemoryFile -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        try {
            $untypedMap = $_ | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            [HawkMemoryEntry]::new($untypedMap)
        } catch { Write-Verbose "Memory entry parse skipped: $($_.Exception.Message)" }
    }
}

function Add-HawkMemory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Text,
        [ValidateSet('preference', 'runbook', 'session', 'web', 'sysops', 'note')][string]$Type = 'note',
        [string[]]$Tag = @(),
        [string]$Source = 'manual',
        [ValidateSet('low', 'medium', 'high', 'user')][string]$Confidence = 'user',
        [switch]$Pinned
    )
    $joined = ($Text -join ' ').Trim()
    if (-not $joined) { throw 'Payload buffer verification empty.' }

    $map = [hashtable]@{
        Id         = Format-HawkMemoryId
        Type       = $Type
        Tags       = @($Tag)
        Text       = ($joined | Protect-HawkSensitiveText | Out-String).Trim()
        Source     = $Source
        Created    = (Get-Date).ToString('o')
        Confidence = $Confidence
        Pinned     = [bool]$Pinned
    }

    if ($PSCmdlet.ShouldProcess("Memory entry: $(Format-HawkMemorySnippet -Text $joined)", 'Save memory')) {
        $typedInstance = [HawkMemoryEntry]::new($map)
        ($typedInstance | ConvertTo-Json -Compress -Depth 6) | Add-Content -Path (Get-HawkMemoryFile) -Encoding UTF8
        return $typedInstance
    }
}

function Search-HawkMemory {
    [CmdletBinding()] param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Query = @(), [int]$First = 8, [switch]$Pinned)
    $queryText = ($Query -join ' ').Trim()
    $items = @(Read-HawkMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if (-not $items) { return }
    if (-not $queryText) { $items | Sort-Object Created -Descending | Select-Object -First $First; return }

    $terms = @(Get-HawkMemorySearchTerm -Text $queryText)
    if (-not $terms) { $items | Sort-Object Created -Descending | Select-Object -First $First; return }

    @(foreach ($item in $items) {
        $score = 0
        $haystack = "$($item.Type) $((@($item.Tags) -join ' ')) $($item.Text)".ToLowerInvariant()
        foreach ($term in $terms) { if ($haystack.Contains($term)) { $score++ } }
        if ($item.Pinned) { $score += 2 }
        if ($score -gt 0) {
            [PSCustomObject]@{
                Score      = $score
                Id         = $item.Id
                Type       = $item.Type
                Tags       = $item.Tags
                Text       = $item.Text
                Source     = $item.Source
                Created    = $item.Created
                Confidence = $item.Confidence
                Pinned     = $item.Pinned
            }
        }
    }) | Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Created'; Descending = $true } | Select-Object -First $First
}

function Get-HawkMemoryMap {
    param([string]$Tag, [switch]$Pinned, [int]$First = 40)
    $items = @(Read-HawkMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if ($Tag) { $items = @($items | Where-Object { $_.Tags -and @($_.Tags) -contains $Tag }) }
    $items | Sort-Object Created -Descending | Select-Object -First $First
}
