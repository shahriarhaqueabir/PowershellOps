function Invoke-HawkAI {
    <#
    .SYNOPSIS
    Sends data and/or a question to the local llama.cpp server for AI analysis.
    .DESCRIPTION
    Pipes data through a local LLM with streaming output. Supports auto-start
    of the llama server, retry logic, and sensitive text redaction. Use the
    alias 'ai' for quick access: Get-Process | ai "what's using the most memory?"
    .PARAMETER InputData
    Pipeline data to send to the LLM (files, processes, etc.).
    .PARAMETER Instruction
    The question or instruction for the AI.
    .PARAMETER Model
    Model file path. Defaults to the configured Hawk model.
    .PARAMETER TimeoutSec
    Request timeout in seconds. Default: 300.
    .PARAMETER MaxRetries
    Number of retries on failure. Default: 0.
    .PARAMETER RedactSensitive
    Redact tokens/keys from input before sending.
    .PARAMETER PassThru
    Returns the full assistant reply as a string instead of discarding it.
    Streaming console output is unchanged.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputData,
        [Parameter(Position = 0)]
        [string]$Instruction,
        [string]$Model = $script:HawkLlamaModelPath,
        [int]$TimeoutSec = 300,
        [int]$MaxRetries = 0,
        [switch]$RedactSensitive,
        [switch]$PassThru
    )

    begin {
        $dataBuffer = [System.Collections.Generic.List[object]]::new()
    }
    process {
        $dataBuffer.Add($InputData)
    }
    end {
        $rawInput = @($dataBuffer | Where-Object { $null -ne $_ })
        $isPlainText = $rawInput.Count -eq 1 -and $rawInput[0] -is [string]
        $hasInstruction = -not [string]::IsNullOrWhiteSpace($Instruction)

        if (-not $rawInput.Count -and -not $hasInstruction) {
            $Instruction = Read-Host '  [AI] Ask a question or pipe data to analyze'
            $hasInstruction = -not [string]::IsNullOrWhiteSpace($Instruction)
        }

        $chatMode = ($isPlainText -and -not $hasInstruction) -or (-not $rawInput.Count -and $hasInstruction)
        $effectiveInstruction = if ($hasInstruction) { $Instruction } else { 'Analyze this data.' }

        $stringifiedData = $dataBuffer | Out-String
        if ($RedactSensitive) {
            $stringifiedData = $stringifiedData | Protect-HawkSensitiveText | Out-String
        }

        $contextPacket = New-HawkAIContextPacket -Instruction $effectiveInstruction -InputObject $rawInput

        $assistantContract = if ($chatMode) {
            @'
You are Hawk AI, the local assistant of the PowershellOps profile, a fast PowerShell/SysOps assistant running on llama.cpp.
Answer the user's question directly and concisely.
Do not output commands unless the user asks how to do something or asks for a command, script, fix, or change.
If you do not know, say so and suggest the smallest useful next check.
'@
        }
        else {
            @'
You are Hawk AI, the local assistant of the PowershellOps profile, a fast PowerShell/SysOps assistant.
Use the context envelope and pipeline data as evidence.
Default to a concise answer. Expand only when the user asks for deep analysis.
If pipeline data is present, answer from it first and preserve its units.
Do not output commands unless the user asks how to do something or asks for a command, script, fix, or change.
If the answer is not in the data or context, say what is missing and suggest the smallest useful next check.
'@
        }

        $userContent = if ($chatMode) {
            if ($isPlainText) { $rawInput[0] } else { $effectiveInstruction }
        }
        else {
            "$($contextPacket.Text)`n`nUser question:`n$effectiveInstruction`n`nPowerShell pipeline data:`n$stringifiedData"
        }

        $payload = @{
            model    = $Model
            messages = @(
                @{ role = 'system'; content = $assistantContract },
                @{ role = 'user'; content = $userContent }
            )
            stream   = $true
            chat_template_kwargs = @{ enable_thinking = $false }
        } | ConvertTo-Json -Depth 6

        $maxAttempts = 1 + [Math]::Max(0, $MaxRetries)
        $success = $false
        $lastError = $null
        $autoStartAttempted = $false
        $modelDisplay = if ($Model -match '[/\\]') { Split-Path $Model -Leaf } else { $Model }

        for ($attempt = 1; $attempt -le $maxAttempts -and -not $success; $attempt++) {
            if ($attempt -gt 1) {
                Write-Host "  [Retry] $attempt / $maxAttempts..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }

            Write-Host "`n  [AI] [$($modelDisplay.ToUpper())] " -NoNewline -ForegroundColor Magenta

            $httpClient = [System.Net.Http.HttpClient]::new()
            $response = $null
            $stream = $null
            $reader = $null
            $responseText = [System.Text.StringBuilder]::new()
            try {
                $httpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
                $body = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                $response = $httpClient.PostAsync("$($script:HawkLlamaEndpoint)/v1/chat/completions", $body).GetAwaiter().GetResult()
                $response.EnsureSuccessStatusCode() | Out-Null
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $reader = [System.IO.StreamReader]::new($stream)

                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    if (-not $line) { continue }
                    if (-not $line.StartsWith('data:')) { continue }

                    $data = $line.Substring(5).Trim()
                    if ($data -eq '[DONE]') { break }

                    try {
                        $chunk = $data | ConvertFrom-Json -ErrorAction Stop
                        $delta = $chunk.choices[0].delta
                        if ($delta.reasoning_content) {
                            $null = $responseText.Append($delta.reasoning_content)
                            Write-Host $delta.reasoning_content -NoNewline -ForegroundColor DarkGray
                        }
                        elseif ($delta.content) {
                            $null = $responseText.Append($delta.content)
                            Write-Host $delta.content -NoNewline -ForegroundColor White
                        }
                        if ($chunk.choices[0].finish_reason) { break }
                    }
                    catch {
                        Write-Verbose "Skipping malformed AI stream line: $line"
                    }
                }

                Write-Host ''
                $success = $true
            }
            catch {
                $lastError = $_
                $isConnError = $_.Exception.Message -match 'refused|No connection|timed out|unreachable|connection reset|Could not connect'
                if ($isConnError -and -not $autoStartAttempted) {
                    $autoStartAttempted = $true
                    Write-Host "`n  [AI] llama server not reachable - starting it..." -ForegroundColor Yellow
                    $proc = Start-HawkLlamaServer
                    if ($proc) {
                        $ready = $false
                        for ($i = 0; $i -lt 60; $i++) {
                            Start-Sleep -Seconds 1
                            try {
                                $null = Invoke-RestMethod "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
                                $ready = $true
                                break
                            }
                            catch { }
                        }
                        if ($ready) {
                            Write-Host "  [AI] server ready (PID $($proc.Id)) - retrying..." -ForegroundColor Green
                            $maxAttempts = $attempt + 1
                            $lastError = $null
                        }
                        else {
                            Write-Warning "  [AI] server started (PID $($proc.Id)) but not ready after 60s"
                        }
                    }
                }
                if ($lastError) {
                    Write-Warning "AI request failed: $($_.Exception.Message)"
                }
            }
            finally {
                if ($reader) { $reader.Dispose() }
                if ($stream) { $stream.Dispose() }
                if ($response) { $response.Dispose() }
                $httpClient.Dispose()
            }
        }

        if ($success -and $PassThru) {
            return $responseText.ToString()
        }
        if (-not $success -and $lastError) {
            throw $lastError
        }
    }
}

function Invoke-HawkChatStream {
    # Private: streams one multi-turn chat completion; returns assistant text.
    [CmdletBinding()]
    param(
        [object[]]$Messages,
        [string]$Model = $script:HawkLlamaModelPath,
        [int]$TimeoutSec = 300
    )

    $payload = @{
        model                = $Model
        messages             = $Messages
        stream               = $true
        chat_template_kwargs = @{ enable_thinking = $false }
    } | ConvertTo-Json -Depth 6

    $httpClient = [System.Net.Http.HttpClient]::new()
    $response = $null
    $stream = $null
    $reader = $null
    $reply = [System.Text.StringBuilder]::new()
    try {
        $httpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
        $body = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
        $response = $httpClient.PostAsync("$($script:HawkLlamaEndpoint)/v1/chat/completions", $body).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $reader = [System.IO.StreamReader]::new($stream)

        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if (-not $line -or -not $line.StartsWith('data:')) { continue }
            $data = $line.Substring(5).Trim()
            if ($data -eq '[DONE]') { break }
            try {
                $chunk = $data | ConvertFrom-Json -ErrorAction Stop
                $delta = $chunk.choices[0].delta
                if ($delta.reasoning_content) {
                    Write-Host $delta.reasoning_content -NoNewline -ForegroundColor DarkGray
                }
                elseif ($delta.content) {
                    $null = $reply.Append($delta.content)
                    Write-Host $delta.content -NoNewline -ForegroundColor White
                }
                if ($chunk.choices[0].finish_reason) { break }
            }
            catch {
                Write-Verbose "Skipping malformed AI stream line: $line"
            }
        }
        Write-Host ''
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($response) { $response.Dispose() }
        $httpClient.Dispose()
    }

    return $reply.ToString()
}

function Invoke-HawkChat {
    <#
    .SYNOPSIS
    Starts an interactive multi-turn chat session with the local llama model.
    .DESCRIPTION
    REPL with full conversation memory across turns. Commands: /exit, /clear,
    /help. Use the alias 'hawkchat'.
    .PARAMETER Model
    Model file path. Defaults to the configured Hawk model.
    .PARAMETER TimeoutSec
    Per-reply timeout in seconds. Default: 300.
    .PARAMETER HistoryLimit
    Max user/assistant turns kept in context (oldest trimmed first). Default: 16.
    #>
    [CmdletBinding()]
    param(
        [string]$Model = $script:HawkLlamaModelPath,
        [int]$TimeoutSec = 300,
        [int]$HistoryLimit = 16
    )

    if (-not (Test-HawkInteractiveSession)) {
        Write-Host '  [chat] an interactive console is required' -ForegroundColor Yellow
        return
    }

    try {
        $null = Invoke-RestMethod "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
    }
    catch {
        Write-Host '  [chat] llama server not reachable.' -ForegroundColor Yellow
        $answer = Read-Host '  [chat] start it now? [y/N]'
        if ($answer -match '^(y|yes)$') {
            $proc = Start-HawkLlamaServer
            if (-not $proc) { return }
            Write-Host '  [chat] waiting for server...' -ForegroundColor DarkGray
            $ready = $false
            for ($i = 0; $i -lt 60; $i++) {
                Start-Sleep -Seconds 1
                try {
                    $null = Invoke-RestMethod "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
                    $ready = $true
                    break
                }
                catch { }
            }
            if (-not $ready) {
                Write-Warning '  [chat] server not ready after 60s'
                return
            }
        }
        else {
            return
        }
    }

    $systemPrompt = @'
You are Hawk AI, the local assistant of the PowershellOps profile, a fast PowerShell/SysOps assistant running on llama.cpp.
Answer the user's question directly and concisely.
Remember earlier turns of this conversation and stay consistent with them.
Do not output commands unless the user asks how to do something or asks for a command, script, fix, or change.
If you do not know, say so and suggest the smallest useful next check.
'@

    $messages = [System.Collections.Generic.List[object]]::new()
    $messages.Add(@{ role = 'system'; content = $systemPrompt })
    $modelDisplay = Split-Path $Model -Leaf

    Write-Host "`n  ◆ HAWKCHAT — $modelDisplay  (type /help for commands)" -ForegroundColor Magenta

    :chatLoop while ($true) {
        $userLine = Read-Host "`n  ❯"
        if ([string]::IsNullOrWhiteSpace($userLine)) { continue }

        switch ($userLine.ToLowerInvariant()) {
            { $_ -in '/exit', '/quit', '/q' } { break chatLoop }
            '/clear' {
                while ($messages.Count -gt 1) { $messages.RemoveAt(1) }
                Write-Host '  (conversation memory cleared)' -ForegroundColor DarkGray
                continue chatLoop
            }
            '/help' {
                Write-Host '  /exit /quit /q   leave chat' -ForegroundColor DarkGray
                Write-Host '  /clear           wipe conversation memory' -ForegroundColor DarkGray
                Write-Host '  /help            this list' -ForegroundColor DarkGray
                continue chatLoop
            }
            default {
                $messages.Add(@{ role = 'user'; content = $userLine })
                try {
                    $reply = Invoke-HawkChatStream -Messages $messages.ToArray() -Model $Model -TimeoutSec $TimeoutSec
                    if (-not [string]::IsNullOrWhiteSpace($reply)) {
                        $messages.Add(@{ role = 'assistant'; content = $reply })
                    }
                    else {
                        Write-Host '  (empty response)' -ForegroundColor Yellow
                        $messages.RemoveAt($messages.Count - 1)
                    }
                }
                catch {
                    Write-Host "  [chat] request failed: $($_.Exception.Message)" -ForegroundColor Red
                    $messages.RemoveAt($messages.Count - 1)
                }

                while ($messages.Count -gt (1 + (2 * $HistoryLimit))) {
                    $messages.RemoveAt(1)
                }
            }
        }
    }

    Write-Host '  ◆ chat ended' -ForegroundColor DarkGray
}

