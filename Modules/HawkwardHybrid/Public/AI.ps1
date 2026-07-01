# ── PUBLIC: AI FUNCTIONS ───────────────────────────────────────────────────

function Get-HawkAIStatus {
    param([string]$Endpoint = 'http://127.0.0.1:11434')
    return Invoke-HawkCachedData -Key "ai_status_$Endpoint" -ExpirySeconds 15 -ScriptBlock {
        try {
            $models = (Invoke-RestMethod -Uri "$Endpoint/api/tags" -TimeoutSec 5 -ErrorAction Stop).models
            if (-not $models) { return @() }
            foreach ($model in $models) {
                [PSCustomObject]@{ Endpoint = $Endpoint; Status = 'Reachable'; Model = $model.name; SizeGB = [Math]::Round($model.size / 1GB, 2); Modified = $model.modified_at }
            }
        } catch {
            [PSCustomObject]@{ Endpoint = $Endpoint; Status = 'Unavailable'; Model = ''; SizeGB = ''; Modified = $_.Exception.Message }
        }
    }
}

function Get-HawkAIIntent {
    param([AllowNull()][string]$Instruction)
    if ([string]::IsNullOrWhiteSpace($Instruction)) { return 'AnalyzeData' }
    $text = $Instruction.ToLowerInvariant()
    if ($text -match '\b(search|web|online|latest|current|look up|lookup|research)\b') { return 'Research' }
    if ($text -match '\b(command|script|cmdlet|syntax|powershell|how do i|how to|fix|change|install|remove|delete|start|stop|restart)\b') { return 'Shell' }
    if ($text -match '\b(compare|changed|since|history|previous|trend)\b') { return 'Compare' }
    if ($text -match '\b(summarize|summary|explain|why|what does)\b') { return 'Explain' }
    return 'AnalyzeData'
}

function Get-HawkAIDataProfile {
    param([object[]]$InputObject = @())
    $rows = @($InputObject | Where-Object { $null -ne $_ })
    if (-not $rows) { return [PSCustomObject]@{ Kind = 'Empty'; Rows = 0; Columns = '' } }
    if ($rows[0] -is [string]) { return [PSCustomObject]@{ Kind = 'Text'; Rows = $rows.Count; Columns = 'Text' } }
    $cols = @($rows[0].PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Select-Object -ExpandProperty Name -First 24)
    [PSCustomObject]@{ Kind = if ($cols.Count -gt 1) { 'Table' } else { 'Object' }; Rows = $rows.Count; Columns = ($cols -join ', ') }
}

function Build-HawkAIMemoryContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', 'Read-only data assembly from existing memory')]
    param([string]$Query, [int]$First = 5)
    $items = @(Search-HawkMemory -Pinned -First 3)
    if ($Query) { $items += @(Search-HawkMemory -Query $Query -First $First) }
    $selected = @(foreach ($item in $items) { if ($item.Id) { $item } }) | Select-Object -First $First
    if (-not $selected) { return '' }
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('Relevant local memory:')
    foreach ($item in $selected) { $lines.Add("- [$($item.Type)] $(Format-HawkMemorySnippet -Text $item.Text -MaxLength 220)") }
    return ($lines -join [Environment]::NewLine)
}

function Build-HawkAIContextPacket {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', 'Read-only data assembly, no system state change')]
    param([string]$Instruction, [object[]]$InputObject = @(), [int]$MemoryLimit = 5, [switch]$NoMemory)
    $intent = Get-HawkAIIntent -Instruction $Instruction; $dataProfile = Get-HawkAIDataProfile -InputObject $InputObject
    $mode = 'Fast'
    if ($Instruction -match '(?i)\b(deep|thorough|investigate|full|history|compare)\b') { $mode = 'Deep' }
    elseif ($intent -in @('Research', 'Compare')) { $mode = 'Balanced' }
    $lines = [System.Collections.Generic.List[string]]::new(); $lines.Add('Context envelope:')
    $lines.Add("- Mode: $mode"); $lines.Add("- Intent: $intent"); $lines.Add("- Data kind: $($dataProfile.Kind)"); $lines.Add("- Rows: $($dataProfile.Rows)")
    if ($dataProfile.Columns) { $lines.Add("- Columns: $($dataProfile.Columns)") }
    if (-not $NoMemory) { $mem = Build-HawkAIMemoryContext -Query $Instruction -First $MemoryLimit; if ($mem) { $lines.Add(''); $lines.Add($mem) } }
    [PSCustomObject]@{ Intent = $intent; Mode = $mode; Text = ($lines -join [Environment]::NewLine) }
}

function Invoke-HawkAI {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', 'Intentional streaming output to console')]
    [CmdletBinding()] param([Parameter(ValueFromPipeline = $true, Mandatory = $true)]$InputData, [Parameter(Position = 0)][string]$Instruction = 'Analyze this data.', [string]$Model = 'HawkPowershell', [int]$TimeoutSec = 120, [int]$MaxRetries = 0, [switch]$RedactSensitive, [switch]$Remember, [switch]$NoMemory, [int]$MemoryLimit = 5)
    begin { $dataBuffer = [System.Collections.Generic.List[object]]::new() }
    process { $dataBuffer.Add($InputData) }
    end {
        $stringifiedData = $dataBuffer | Out-String; if ($RedactSensitive) { $stringifiedData = $stringifiedData | Protect-HawkSensitiveText | Out-String }
        $ctx = Build-HawkAIContextPacket -Instruction $Instruction -InputObject $dataBuffer.ToArray() -MemoryLimit $MemoryLimit -NoMemory:$NoMemory
        $contract = "You are Hawkward AI, a fast local PowerShell/SysOps assistant.`nUse the context envelope, relevant memory, and pipeline data as evidence.`nDefault to a concise answer. Expand only when requested.`nIf pipeline data is present, answer from it first and preserve its units.`nDo not output commands unless specifically requested."
        $payload = @{ model = $Model; prompt = "$contract`n`n$($ctx.Text)`n`nUser question:`n$Instruction`n`nPowerShell pipeline data:`n$stringifiedData"; stream = $true } | ConvertTo-Json -Depth 5
        $success = $false; $lastErr = $null
        for ($attempt = 1; $attempt -le (1 + $MaxRetries) -and -not $success; $attempt++) {
            if ($attempt -gt 1) { Write-HawkHeader "  [Retry] $attempt / $((1 + $MaxRetries))..." Yellow; Start-Sleep -Seconds 3 }
            Write-Host "`n  [AI] [$($Model.ToUpper())] " -NoNewline -ForegroundColor Magenta
            $client = [System.Net.Http.HttpClient]::new()
            try {
                $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
                $body = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                $response = $client.PostAsync('http://127.0.0.1:11434/api/generate', $body).GetAwaiter().GetResult()
                $response.EnsureSuccessStatusCode() | Out-Null
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult(); $reader = [System.IO.StreamReader]::new($stream)
                $respText = [System.Text.StringBuilder]::new()
                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine(); if (-not $line) { continue }
                    try {
                        $chunk = $line | ConvertFrom-Json -ErrorAction Stop
                        if ($chunk.response) { $null = $respText.Append($chunk.response); Write-Host $chunk.response -NoNewline -ForegroundColor White }
                        if ($chunk.done) { break }
                    } catch { Write-Verbose "AI stream chunk parse warning: $($_.Exception.Message)" }
                }
                Write-Host ''; if ($Remember -and $respText.Length -gt 0) { Add-HawkMemory -Text "Question: $Instruction`n`nAnswer: $($respText.ToString())" -Type session -Tag @('ai', $ctx.Intent.ToLowerInvariant()) -Source 'ai' | Out-Null }
                $success = $true
            } catch { $lastErr = $_; Write-Warning "AI pipeline failure: $($_.Exception.Message)" } finally { if ($reader) {$reader.Dispose()}; $client.Dispose() }
        }
        if (-not $success -and $lastErr) { throw $lastErr }
    }
}
