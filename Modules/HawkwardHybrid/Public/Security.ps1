# ── PUBLIC: SECURITY AUDIT ────────────────────────────────────────────────

function Get-HawkFirewallAudit {
    return Invoke-HawkCachedData -Key 'sys_fwaudit' -ExpirySeconds 60 -ScriptBlock {
        if (-not (Get-Command Get-NetFirewallRule -ErrorAction SilentlyContinue)) {
            return [PSCustomObject]@{ Port = 'ALL'; PID = '0'; Process = 'N/A'; Status = 'NetSecurity Module Missing' }
        }
        $listeners = Get-HawkPortMap
        $allowPorts = Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue |
            Select-Object -First 200 |
            Get-NetFirewallPortFilter -ErrorAction SilentlyContinue |
            ForEach-Object { $_.LocalPort } | Where-Object { $_ -match '^\d+$' } | Select-Object -Unique
        $listeners | ForEach-Object {
            $matched = if ($_.Port -in $allowPorts) { 'Allowed' } else { 'NO_MATCHING_INBOUND_ALLOW_RULE' }
            [PSCustomObject]@{
                Port    = $_.Port
                PID     = $_.PID
                Process = $_.Process
                Status  = $matched
            }
        }
    }
}

function Get-HawkBootMap {
    return Invoke-HawkCachedData -Key 'sys_bootmap' -ExpirySeconds 300 -ScriptBlock {
        $paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
        foreach ($p in $paths) {
            if (Test-Path $p) {
                $val = Get-ItemProperty -Path $p
                $val.PSObject.Properties |
                    Where-Object { $_.Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') } |
                    ForEach-Object { [PSCustomObject]@{ Hive = (Split-Path $p -Leaf); Name = $_.Name; Target = $_.Value } }
            }
        }
    }
}

function Get-HawkScheduledTaskRiskAudit {
    return Invoke-HawkCachedData -Key 'sys_taskaudit' -ExpirySeconds 300 -ScriptBlock {
        if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) { return @() }
        Get-ScheduledTask |
            Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '^\\\\Microsoft' } |
            Select-Object -First 10 |
            ForEach-Object { [PSCustomObject]@{ TaskName = $_.TaskName; Path = $_.TaskPath } }
    }
}

function Get-HawkGhostPortAudit { Get-HawkPortMap | Where-Object { $_.Process -in @('Unknown', 'System Listen Stack') } }

function Get-HawkSuspiciousProcessAudit {
    Get-Process | Where-Object { $_.Path -and $_.Path -match '(?i)(\\AppData\\|\\Temp\\|\\Windows\\Temp\\)' } |
        Select-Object Name, Id, @{N='Path';E={$_.Path}}, @{N='CPU';E={[Math]::Round($_.CPU, 1)}}, @{N='RAMMB';E={[Math]::Round($_.WorkingSet / 1MB, 1)}}
}

function Get-HawkEventStormAudit {
    return Invoke-HawkCachedData -Key 'sys_eventstorm' -ExpirySeconds 20 -ScriptBlock {
        try {
            $cutoff = (Get-Date).AddMinutes(-15)
            Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $cutoff } -MaxEvents 200 -ErrorAction SilentlyContinue |
                Group-Object ProviderName |
                Sort-Object Count -Descending |
                Select-Object -First 5 |
                ForEach-Object { [PSCustomObject]@{ Count = $_.Count; Name = $_.Name; Source = 'Application Log' } }
        } catch { return @() }
    }
}

function Get-HawkShield {
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Status = 'Defender cmdlets unavailable' }
    }
    Get-MpComputerStatus -ErrorAction SilentlyContinue |
        Select-Object AntivirusEnabled, RealTimeProtectionEnabled, LastQuickScanTime, AMServiceEnabled,
            @{N='LastQuickScanResult';E={$_.LastQuickScanResult -join ';'}}
}

function Get-HawkEnvMap { Get-ChildItem Env: | Select-Object Name, Value }

function Get-HawkPathAudit { $env:Path -split ';' | ForEach-Object { [PSCustomObject]@{ Path = $_; Exists = (Test-Path $_) } } }

function Protect-HawkSensitiveText {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $true)][AllowNull()]$InputObject)
    process {
        if ($null -eq $InputObject) { return }
        $text = if ($InputObject -is [string]) { $InputObject } else { $InputObject | Out-String }

        $cleanPattern = $script:HawkSensitiveNamePattern -replace '\(\?[a-z]+\)', ''
        $redacted = [regex]::Replace($text, ('(?im)^(\s*[^=\r\n]*(?:' + $cleanPattern + ')[^=\r\n]*\s*=\s*).+$'), '$1<REDACTED>')
        $jsonPattern = '(?i)("(?:[^"]*(?:' + $cleanPattern + ')[^"]*)"\s*:\s*")[^"]*(")'
        [regex]::Replace($redacted, $jsonPattern, '$1<REDACTED>$2')
    }
}

function Test-HawkPromptInjection {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Payload,
        [switch]$UseAIHeuristic,
        [int]$MaxContentLength = 51200
    )
    if ([string]::IsNullOrWhiteSpace($Payload)) { return $false }
    if ($Payload.Length -gt $MaxContentLength) {
        Write-Verbose 'PromptInjection: Payload exceeds max content length threshold'
        return $true
    }

    $score = 0

    $dangerousPatterns = @(
        '(?i)\bignore\s+(?:(?:previous|above|all)\s+)*instructions\b',
        '(?i)\byou\s+are\s+now\b',
        '(?i)\bsystem\s*prompt\b',
        '(?i)\bDAN\b',
        '(?i)\bdo\s+not\s+output\b',
        '(?i)\bforget\s+(?:all\s+)?(?:previous|above)\s+instructions\b',
        '(?i)\bnew\s+instructions?\s*:\s*ignore\b',
        '(?i)\boverride\s+(?:all\s+)?(?:previous|above\s+)?instructions\b',
        '(?i)\boutput\s+(?:only|just|exactly)\b'
    )
    foreach ($pat in $dangerousPatterns) {
        if ($Payload -match $pat) { $score += 25 }
    }

    $hasBase64 = $Payload -match '(?i)(?:[A-Za-z0-9+/]{40,}={0,2})' -or $Payload -match '(?i)(?:[A-Za-z0-9_-]{40,})'
    $hasHex = $Payload -match '(?i)(?:0x[0-9A-Fa-f]{8,}|\\x[0-9A-Fa-f]{2})'
    $hasPercentEncoding = $Payload -match '(?:%[0-9A-Fa-f]{2}){10,}'
    $hasUnicodeEscape = $Payload -match '(?:\\u[0-9A-Fa-f]{4}){3,}'
    $hasRepeatedEncoding = ($Payload -match '(?i)(?:base64|hex\s*encode|rot13|atob|btoa|unescape)')
    if ($hasBase64) { $score += 15 }
    if ($hasHex) { $score += 15 }
    if ($hasPercentEncoding) { $score += 10 }
    if ($hasUnicodeEscape) { $score += 10 }
    if ($hasRepeatedEncoding) { $score += 15 }

    $excessiveNewlines = ([regex]::Matches($Payload, '\n').Count -gt 50)
    $nullTokenInjection = $Payload -match '\x00|\\x00|\\0'
    if ($excessiveNewlines) { $score += 5 }
    if ($nullTokenInjection) { $score += 20 }

    if ($UseAIHeuristic -and $score -ge 10 -and $score -lt 40) {
        try {
            $null = Get-HawkAIStatus -Endpoint 'http://127.0.0.1:11434' -ErrorAction SilentlyContinue
        } catch { Write-Verbose 'PromptInjection: Ollama unavailable for AI heuristic, skipping'; return ($score -ge 25) }

        try {
            $probePrompt = "Classify the following text as 'safe' or 'injection' (respond with one word only):`n`n$($Payload.Substring(0, [Math]::Min(500, $Payload.Length)))"
            $aiPayload = @{ model = 'HawkPowershell'; prompt = $probePrompt; stream = $false } | ConvertTo-Json -Depth 3
            $aiResp = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/generate' -Method Post -Body $aiPayload -ContentType 'application/json' -TimeoutSec 10 -ErrorAction Stop
            if ($aiResp.response -match '(?i)\binjection\b') { $score += 30 }
            Write-Verbose "PromptInjection: AI heuristic returned score adjustment"
        } catch { Write-Verbose 'PromptInjection: AI heuristic unavailable, skipping layer 4' }
    }

    return ($score -ge 25)
}

function Get-HawkSourceQualityScore {
    param([string]$Url, [AllowNull()][string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return 0 }
    $score = 50
    if ($Content.Length -gt 200)  { $score += 20 }
    if ($Content.Length -gt 800)  { $score += 15 }
    if ($Url -match '\.(gov|edu|org)(/|$)') { $score += 15 }
    return [Math]::Min(100, $score)
}

function Get-HawkAudit {
    [CmdletBinding()]
    param([ValidateSet('Firewall','Boot','ScheduledTask','GhostPort','SuspiciousProcess','EventStorm','Patch','Temp','Clip')][string]$Type = 'Firewall')
    switch ($Type) {
        'Firewall'          { Get-HawkFirewallAudit }
        'Boot'              { Get-HawkBootMap }
        'ScheduledTask'     { Get-HawkScheduledTaskRiskAudit }
        'GhostPort'         { Get-HawkGhostPortAudit }
        'SuspiciousProcess' { Get-HawkSuspiciousProcessAudit }
        'EventStorm'        { Get-HawkEventStormAudit }
        'Patch'             { Get-HawkPatchHistory }
        'Temp'              { Get-HawkTempCheck }
        'Clip'              { Get-HawkClipCheck }
    }
}
