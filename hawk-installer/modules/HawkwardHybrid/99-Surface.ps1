function Get-HawkSystem {
    <#
    .SYNOPSIS
    System diagnostics dispatcher.
    .PARAMETER Type
    health, spec, uptime, ram, battery, display, disk, res, port, temp,
    fans, hyperv, power or license.
    .EXAMPLE
    sysdiag -Type disk      # -> Get-HawkDiskPressureAudit
    Alias: sysdiag.
    #>
    [CmdletBinding()]
    param([ValidateSet('health', 'spec', 'uptime', 'ram', 'battery', 'display', 'disk', 'res', 'port', 'temp', 'fans', 'hyperv', 'power', 'license')][string]$Type = 'health')

    switch ($Type) {
        'health'  { Get-HawkDoctor }
        'spec'    { Get-HawkSpecs }
        'uptime'  { Get-HawkUptime }
        'ram'     { Get-HawkRamInfo }
        'battery' { Get-HawkBattery }
        'display' { Get-HawkDisplays }
        'disk'    { Get-HawkDiskPressureAudit }
        'res'     { Get-HawkResourceMap }
        'port'    { Get-HawkPortMap }
        'temp'    { Get-HawkThermals }
        'fans'    { Get-HawkFans }
        'hyperv'  { Get-HawkHypervisor }
        'power'   { Get-HawkPower }
        'license' { Get-HawkLicense }
    }
}

function Get-HawkAudit {
    <#
    .SYNOPSIS
    Security/audit dispatcher.
    .PARAMETER Type
    fw, boot, schedtask, ghost, sus, storm, admin, shield, temp, clip,
    defender, reg, ifeo or pathaudit.
    .EXAMPLE
    auditdiag -Type fw      # -> Get-HawkFirewallAudit
    Alias: auditdiag.
    #>
    [CmdletBinding()]
    param([ValidateSet('fw', 'boot', 'schedtask', 'ghost', 'sus', 'storm', 'admin', 'shield', 'temp', 'clip', 'defender', 'reg', 'ifeo', 'pathaudit')][string]$Type = 'fw')

    switch ($Type) {
        'fw'        { Get-HawkFirewallAudit }
        'boot'      { Get-HawkBootMap }
        'schedtask' { Get-HawkScheduledTaskRiskAudit }
        'ghost'     { Get-HawkGhostPortAudit }
        'sus'       { Get-HawkSuspiciousProcessAudit }
        'storm'     { Get-HawkEventStormAudit }
        'admin'     { Get-HawkAdmins }
        'shield'    { Get-HawkShield }
        'temp'      { Get-HawkThermals }
        'clip'      { Get-HawkClipCheck }
        'defender'  { Get-HawkDefenderAudit }
        'reg'       { Get-HawkRegAudit }
        'ifeo'      { Get-HawkIfeoAudit }
        'pathaudit' { Get-HawkPathAudit }
    }
}

function Get-HawkNetwork {
    <#
    .SYNOPSIS
    Network diagnostics dispatcher.
    .PARAMETER Type
    ping, wifi, dns, linkspeed, shares, hosts, dnscache, established,
    nettriage or portmap.
    .EXAMPLE
    netview -Type ping      # -> Get-HawkNetCheck
    Alias: netview.
    #>
    [CmdletBinding()]
    param([ValidateSet('ping', 'wifi', 'dns', 'linkspeed', 'shares', 'hosts', 'dnscache', 'established', 'nettriage', 'portmap')][string]$Type = 'ping')

    switch ($Type) {
        'ping'        { Get-HawkNetCheck }
        'wifi'        { Get-HawkWifi }
        'dns'         { Get-HawkDnsBench }
        'linkspeed'   { Get-HawkLinkSpeed }
        'shares'      { Get-HawkShares }
        'hosts'       { Get-HawkHostsCheck }
        'dnscache'    { Get-HawkDnsCache }
        'established' { Get-HawkTcpListeners }
        'nettriage'   { Get-HawkNetworkTriage }
        'portmap'     { Get-HawkPortMap }
    }
}

function Get-HawkEnv {
    <#
    .SYNOPSIS
    Environment dispatcher.
    .PARAMETER Type
    envmap, path or app.
    .EXAMPLE
    envdiag -Type path      # -> Get-HawkPathAudit
    Alias: envdiag.
    #>
    [CmdletBinding()]
    param([ValidateSet('envmap', 'path', 'app')][string]$Type = 'envmap')

    switch ($Type) {
        'envmap' { Get-HawkEnvMap }
        'path'   { Get-HawkPathAudit }
        'app'    { Get-HawkAppLocation }
    }
}

# ── Hub shortcuts ──────────────────────────────────────────────────

function Invoke-HawkCompanion {
    <#
    .SYNOPSIS
    Hub router for the five one-word shortcuts.
    .DESCRIPTION
    Routes: brief -> daily report, fix -> AI remediation of last error,
    stat -> one-page pulse, ask -> pipable research, mem -> semantic
    recall router. Extra words after the mode are forwarded.
    .NOTES
    -Query, -Tag and -Pinned are honoured only by the mem mode; they are
    ignored (with a warning) when any other mode is selected.
    .EXAMPLE
    hub brief          # same as running 'brief'
    hub mem -Query quantization
    Alias: hub.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][ValidateSet('brief', 'fix', 'stat', 'ask', 'mem')][string]$Mode = 'brief',
        [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest,
        [string]$Query,
        [string[]]$Tag,
        [switch]$Pinned
    )

    if ($Mode -ne 'mem' -and ($Query -or $Tag -or $Pinned)) {
        Write-Warning "-Query/-Tag/-Pinned only apply to 'mem' mode; ignoring them for '$Mode'."
    }

    switch ($Mode) {
        'brief' { Invoke-HawkDaily }
        'fix'   { Invoke-HawkShortFix -Context ($Rest -join ' ') }
        'stat'  { Invoke-HawkShortStat }
        'ask'   {
            if ($Rest) { Invoke-HawkShortAsk -Question ($Rest -join ' ') }
            else { Invoke-HawkShortAsk }
        }
        'mem'   {
            if ($Query) { Search-HawkMemory -Query $Query }
            elseif ($Rest) { Add-HawkMemory -Text ($Rest -join ' ') -Tags $Tag -Pinned:$Pinned }
            else { Get-HawkMemoryMap }
        }
    }
}

function Invoke-HawkShortFix {
    <#
    .SYNOPSIS
    AI remediation for the most recent PowerShell error.
    .DESCRIPTION
    Packages $Error[0] with invocation context and asks the local model
    for a concrete, concise fix. Sensitive strings are redacted first.
    .PARAMETER Context
    Optional extra context appended to the prompt.
    .EXAMPLE
    fix
    Alias: fix.
    #>
    [CmdletBinding()]
    param([string]$Context)

    $err = $global:Error | Select-Object -First 1
    if (-not $err) {
        Write-Host '  No error found in $Error to remediate.' -ForegroundColor Yellow
        return
    }

    $payload = "Last PowerShell error:`n$($err.ToString())`n`nInvocation context:`n$($err.InvocationInfo.PositionMessage)"
    if ($Context) { $payload += "`n`nExtra context:`n$Context" }

    $payload | Invoke-HawkAI -Instruction 'Diagnose this PowerShell error and give a concrete fix (commands where possible). Be concise.' -RedactSensitive
}

function Invoke-HawkShortStat {
    <#
    .SYNOPSIS
    One-page operational pulse (system overview).
    .EXAMPLE
    stat
    Alias: stat.
    #>
    [CmdletBinding()]
    param()

    Get-HawkSysView
}

function Invoke-HawkShortAsk {
    <#
    .SYNOPSIS
    Pipable research question to the local model.
    .DESCRIPTION
    With pipeline input, the data is summarized and analyzed; with a bare
    question it is answered directly. Sensitive content is redacted.
    .EXAMPLE
    resmap | ask "What is using the most memory?"
    ask "How do I shrink a VHDX safely?"
    Alias: ask.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Question,
        [Parameter(ValueFromPipeline)]$InputData,
        [string]$Instruction
    )

    process {
        if ($null -ne $InputData) {
            $payload = ($InputData | Out-String).Trim()
            if (-not $payload) { Write-Host '  Nothing received on the pipeline.' -ForegroundColor Yellow; return }
            $payload | Invoke-HawkAI -Instruction $(if ($Instruction) { $Instruction } else { 'Analyze this operational data and answer concisely.' }) -RedactSensitive
        }
        elseif ($Question) {
            $Question | Invoke-HawkAI -Instruction $(if ($Instruction) { $Instruction } else { 'Answer as a concise Windows operations copilot.' }) -RedactSensitive
        }
        else {
            Write-Host '  Usage: ask "question"   |   some-command | ask' -ForegroundColor Yellow
        }
    }
}

function Invoke-HawkShortMem {
    <#
    .SYNOPSIS
    Semantic recall router (remember / recall / map).
    .DESCRIPTION
    No args -> memory map; text -> save note; -Query -> search.
    .EXAMPLE
    mem                                  # list recent entries
    mem "Prefer Q4_K_M quantization"     # remember a note
    mem -Query quantization              # recall matching notes
    Alias: mem.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Text,
        [string]$Query,
        [string[]]$Tag,
        [switch]$Pinned
    )

    if ($Query) { Search-HawkMemory -Query $Query }
    elseif ($Text) { Add-HawkMemory -Text $Text -Tags $Tag -Pinned:$Pinned }
    else { Get-HawkMemoryMap }
}

# ── Onboarding ─────────────────────────────────────────────────────

function Invoke-HawkOnboardStep1 {
    <#
    .SYNOPSIS
    Onboard step 1: set + persist the project root.
    .DESCRIPTION
    Saves projectRoot to hawk-settings.json and exports $global:HawkProjectRoot.
    .PARAMETER ProjectRoot
    Path to store. Prompts interactively when omitted in a console host.
    .EXAMPLE
    Invoke-HawkOnboardStep1 -ProjectRoot E:\Projects
    Function: Invoke-HawkOnboardStep1.
    #>
    [CmdletBinding()]
    param([string]$ProjectRoot)

    if (-not $ProjectRoot) {
        if ($global:HawkProjectRoot) { $ProjectRoot = $global:HawkProjectRoot }
        elseif ($Host.Name -match 'Console|Windows Terminal') { $ProjectRoot = Read-Host '  Project root path (blank = default)' }
        if (-not $ProjectRoot) { $ProjectRoot = $script:HawkDefaultProjectRoot }
    }

    Set-HawkSetting -Name projectRoot -Value $ProjectRoot
    $global:HawkProjectRoot = $ProjectRoot
    Write-Host ('  [OK] Project root: {0}' -f $ProjectRoot) -ForegroundColor Green
    return $ProjectRoot
}

function Invoke-HawkOnboardStep2 {
    <#
    .SYNOPSIS
    Onboard step 2: create + persist the memory root.
    .DESCRIPTION
    Creates the Memory directory and saves memoryRoot to hawk-settings.json.
    .EXAMPLE
    Invoke-HawkOnboardStep2
    Function: Invoke-HawkOnboardStep2.
    #>
    [CmdletBinding()]
    param([string]$MemoryRoot)

    if (-not $MemoryRoot) { $MemoryRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Memory' }
    New-Item -ItemType Directory -Path $MemoryRoot -Force | Out-Null
    Set-HawkSetting -Name memoryRoot -Value $MemoryRoot
    Write-Host ('  [OK] Memory root ready: {0}' -f $MemoryRoot) -ForegroundColor Green
    return $MemoryRoot
}

function Invoke-HawkOnboardStep3 {
    <#
    .SYNOPSIS
    Onboard step 3: verify the llama.cpp endpoint.
    .DESCRIPTION
    Probes GET <endpoint>/v1/models with a 3s timeout; suggests llamastart
    when unreachable.
    .EXAMPLE
    Invoke-HawkOnboardStep3
    Function: Invoke-HawkOnboardStep3.
    #>
    [CmdletBinding()]
    param([string]$Endpoint)

    if (-not $Endpoint) { $Endpoint = (Get-HawkSettings).llamaEndpoint }
    $uri = $Endpoint.TrimEnd('/') + '/models'
    try {
        $resp = Invoke-RestMethod -Uri $uri -TimeoutSec 3
        $ids = @($resp.data | ForEach-Object { $_.id })
        Write-Host ('  [OK] Llama endpoint reachable: {0}' -f $uri) -ForegroundColor Green
        if ($ids.Count) { Write-Host ('       Models: {0}' -f ($ids -join ', ')) -ForegroundColor DarkGray }
        return $true
    }
    catch {
        Write-Host ('  [!!] Endpoint unreachable: {0}' -f $uri) -ForegroundColor Yellow
        Write-Host '       Tip: run llamastart (or llamadoctor), then re-run step 3.' -ForegroundColor DarkGray
        return $false
    }
}

function Invoke-HawkOnboardStep4 {
    <#
    .SYNOPSIS
    Onboard step 4: select a local GGUF model.
    .DESCRIPTION
    Scans HfHome for *.gguf files, persists the selection to hawk-settings.json.
    Prompts interactively only when multiple models exist in a console host.
    .EXAMPLE
    Invoke-HawkOnboardStep4
    Function: Invoke-HawkOnboardStep4.
    #>
    [CmdletBinding()]
    param([string]$ModelPath)

    $hf = (Get-HawkConfig).HfHome
    $models = @(Get-ChildItem -Path $hf -Filter *.gguf -File -ErrorAction SilentlyContinue)
    if (-not $models.Count) {
        Write-Host ("  [!!] No GGUF models under {0}" -f $hf) -ForegroundColor Yellow
        return $null
    }

    if (-not $ModelPath) {
        if ($models.Count -eq 1 -or $Host.Name -notmatch 'Console|Windows Terminal') {
            $ModelPath = $models[0].FullName
        }
        else {
            for ($i = 0; $i -lt $models.Count; $i++) {
                Write-Host ('  [{0}] {1}' -f ($i + 1), $models[$i].Name) -ForegroundColor DarkGray
            }
            $sel = Read-Host '  Select model #'
            $idx = 0
            [int]::TryParse($sel, [ref]$idx) | Out-Null
            if ($idx -ge 1 -and $idx -le $models.Count) { $ModelPath = $models[$idx - 1].FullName }
            else { $ModelPath = $models[0].FullName }
        }
    }

    Set-HawkSetting -Name model -Value $ModelPath
    Write-Host ('  [OK] Model selected: {0}' -f (Split-Path -Leaf $ModelPath)) -ForegroundColor Green
    return $ModelPath
}

function Invoke-HawkOnboardStep5 {
    <#
    .SYNOPSIS
    Onboard step 5: generate the Modelfile.
    .DESCRIPTION
    Writes Modelfile.powershellops next to hawk-settings.json from the
    selected model plus an operator system prompt.
    .EXAMPLE
    Invoke-HawkOnboardStep5
    Function: Invoke-HawkOnboardStep5.
    #>
    [CmdletBinding()]
    param([string]$ModelPath)

    if (-not $ModelPath) { $ModelPath = (Get-HawkSettings).model }
    if (-not $ModelPath -or -not (Test-Path -LiteralPath $ModelPath)) {
        Write-Host '  [!!] No valid model path; run step 4 first.' -ForegroundColor Red
        return $null
    }

    $settingsPath = if ($env:HAWK_SETTINGS_PATH) { $env:HAWK_SETTINGS_PATH } else { $script:HawkSettingsPath }
    $mf = Join-Path (Split-Path -Parent $settingsPath) 'Modelfile.powershellops'
    $content = @"
FROM $ModelPath
PARAMETER temperature 0.4
PARAMETER num_ctx 4096
SYSTEM """You are PowershellOps, a local Windows operations copilot. Answer concisely, prefer safe read-only diagnostics, and never exfiltrate secrets."""
"@
    Set-Content -LiteralPath $mf -Value $content -Encoding UTF8
    Set-HawkSetting -Name modelfile -Value $mf
    Write-Host ('  [OK] Modelfile written: {0}' -f $mf) -ForegroundColor Green
    return $mf
}

function Invoke-HawkOnboardStep6 {
    <#
    .SYNOPSIS
    Onboard step 6: create the powershellops model via llama CLI.
    .DESCRIPTION
    Runs `llama create powershellops -f <modelfile>` using llama-cli (or
    llama) resolved from PATH.
    .EXAMPLE
    Invoke-HawkOnboardStep6
    Function: Invoke-HawkOnboardStep6.
    #>
    [CmdletBinding()]
    param([string]$ModelFile)

    if (-not $ModelFile) { $ModelFile = (Get-HawkSettings).modelfile }
    if (-not $ModelFile -or -not (Test-Path -LiteralPath $ModelFile)) {
        Write-Host '  [!!] Modelfile missing; run step 5 first.' -ForegroundColor Red
        return $false
    }

    $cli = Get-Command llama-cli -ErrorAction SilentlyContinue
    if (-not $cli) { $cli = Get-Command llama -ErrorAction SilentlyContinue }
    if (-not $cli) {
        Write-Host '  [!!] llama CLI not found on PATH; install llama.cpp first.' -ForegroundColor Red
        return $false
    }

    try {
        & $cli.Source create powershellops -f $ModelFile
        Write-Host '  [OK] Model created: powershellops' -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host ('  [!!] llama create failed: {0}' -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

function Invoke-HawkOnboard {
    <#
    .SYNOPSIS
    Interactive onboarding planner for the Hawk surface.
    .DESCRIPTION
    Prints the 6-step plan by default (or with -WhatIf); -Apply executes
    all steps in order, skipping model steps when no GGUF is present.
    .EXAMPLE
    onboard           # print plan
    onboard -Apply    # execute all 6 steps
    Alias: onboard.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$Apply)

    $steps = @(
        [pscustomobject]@{ N = 1; Name = 'Project root'; Detail = 'Set + persist project root (hawk-settings.json, $global:HawkProjectRoot)' },
        [pscustomobject]@{ N = 2; Name = 'Memory root';  Detail = 'Create Memory/ dir + persist memoryRoot' },
        [pscustomobject]@{ N = 3; Name = 'Llama check';  Detail = 'Verify llama endpoint /v1/models reachability' },
        [pscustomobject]@{ N = 4; Name = 'Model select'; Detail = 'Scan HfHome for GGUF models + persist selection' },
        [pscustomobject]@{ N = 5; Name = 'Modelfile';    Detail = 'Generate Modelfile.powershellops from template' },
        [pscustomobject]@{ N = 6; Name = 'Create';       Detail = 'Run llama create powershellops -f <modelfile>' }
    )

    Write-Host "`n  HAWK ONBOARDING PLAN" -ForegroundColor Cyan
    foreach ($s in $steps) {
        Write-Host ('  [{0}] {1,-13} {2}' -f $s.N, $s.Name, $s.Detail) -ForegroundColor DarkGray
    }

    if ($WhatIfPreference -and -not $Apply) {
        Write-Host '  WhatIf: plan printed; no changes made.' -ForegroundColor DarkGray
        return
    }
    if (-not $Apply) {
        Write-Host '  Dry run. Re-run with -Apply to execute all 6 steps.' -ForegroundColor Yellow
        return
    }

    Write-Host "`n  APPLYING..." -ForegroundColor Magenta
    $null = Invoke-HawkOnboardStep1
    $null = Invoke-HawkOnboardStep2
    $null = Invoke-HawkOnboardStep3
    $model = Invoke-HawkOnboardStep4
    if ($model) {
        $mf = Invoke-HawkOnboardStep5 -ModelPath $model
        if ($mf) { $null = Invoke-HawkOnboardStep6 -ModelFile $mf }
    }
    else {
        Write-Host '  Skipping steps 5-6 (no GGUF model found).' -ForegroundColor Yellow
    }
    Write-Host '  ONBOARDING COMPLETE' -ForegroundColor Green
}

# ── Source quality & injection guard ───────────────────────────────

function Get-HawkSourceQualityScore {
    <#
    .SYNOPSIS
    Heuristic 0-100 quality score for fetched page content.
    .DESCRIPTION
    Base 50; +20 when content exceeds 200 chars, +15 beyond 800 chars,
    +15 for .gov/.edu/.org domains; capped at 100. Used by ggl -AI to
    filter low-signal pages before synthesis (threshold 50).
    .EXAMPLE
    Get-HawkSourceQualityScore -Content $text -Uri $url
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content,
        [string]$Uri
    )

    $score = 50
    if ($Content.Length -gt 200) { $score += 20 }
    if ($Content.Length -gt 800) { $score += 15 }
    if ($Uri -match 'https?://[^/]*\.(?:gov|edu|org)(?:/|$)') { $score += 15 }
    if ($score -gt 100) { $score = 100 }

    [pscustomobject]@{
        Score  = $score
        Length = $Content.Length
        Uri    = $Uri
    }
}

function Test-HawkPromptInjection {
    <#
    .SYNOPSIS
    Detects common prompt-injection patterns in text.
    .DESCRIPTION
    Matches 'ignore previous/above/all instructions', 'you are now',
    'system prompt' and DAN-mode phrasings. Returns $true on any hit.
    .EXAMPLE
    Test-HawkPromptInjection -Text $pageContent   # -> True/False
    #>
    [CmdletBinding()][OutputType([bool])]
    param([Parameter(Mandatory)][string]$Text)

    $patterns = @(
        'ignore\s+(?:previous|above|all)\s+instructions',
        'you\s+are\s+now',
        'system\s+prompt',
        'DAN.*mode'
    )
    foreach ($p in $patterns) {
        if ($Text -match $p) { return $true }
    }
    return $false
}

