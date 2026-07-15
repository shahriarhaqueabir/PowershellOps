# ── PUBLIC: MEMORY FUNCTIONS ───────────────────────────────────────────────

function Get-OpsMemoryFile {
    if (-not (Test-Path $script:OpsMemoryRoot)) { $null = New-Item -Path $script:OpsMemoryRoot -ItemType Directory -Force }
    return $script:OpsMemoryFile
}

function Read-OpsMemory {
    if (-not (Test-Path $script:OpsMemoryFile)) { return @() }
    Get-Content -Path $script:OpsMemoryFile -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        try {
            $untypedMap = $_ | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            [OpsMemoryEntry]::new($untypedMap)
        } catch { Write-Verbose "Memory entry parse skipped: $($_.Exception.Message)" }
    }
}

function Add-OpsMemory {
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
        Id         = Format-OpsMemoryId
        Type       = $Type
        Tags       = @($Tag)
        Text       = ($joined | Protect-OpsSensitiveText | Out-String).Trim()
        Source     = $Source
        Created    = (Get-Date).ToString('o')
        Confidence = $Confidence
        Pinned     = [bool]$Pinned
    }

    if ($PSCmdlet.ShouldProcess("Memory entry: $(Format-OpsMemorySnippet -Text $joined)", 'Save memory')) {
        $typedInstance = [OpsMemoryEntry]::new($map)
        ($typedInstance | ConvertTo-Json -Compress -Depth 6) | Add-Content -Path (Get-OpsMemoryFile) -Encoding UTF8
        return $typedInstance
    }
}

function Search-OpsMemory {
    [CmdletBinding()] param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Query = @(), [int]$First = 8, [switch]$Pinned)
    $queryText = ($Query -join ' ').Trim()
    $items = @(Read-OpsMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if (-not $items) { return }
    if (-not $queryText) { $items | Sort-Object Created -Descending | Select-Object -First $First; return }

    $terms = @(Get-OpsMemorySearchTerm -Text $queryText)
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

function Get-OpsMemoryMap {
    param([string]$Tag, [switch]$Pinned, [int]$First = 40)
    $items = @(Read-OpsMemory)
    if ($Pinned) { $items = @($items | Where-Object { $_.Pinned }) }
    if ($Tag) { $items = @($items | Where-Object { $_.Tags -and @($_.Tags) -contains $Tag }) }
    $items | Sort-Object Created -Descending | Select-Object -First $First
}

