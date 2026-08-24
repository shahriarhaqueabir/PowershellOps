function Get-HawkDoctor {
    [CmdletBinding()]
    param(
        [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
        [string]$ProjectRoot = $global:HawkProjectRoot
    )

    $rows = [System.Collections.Generic.List[object]]::new()

    $profileExists = Test-Path $ProfilePath
    $parseErrors = @()
    if ($profileExists) {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ProfilePath), [ref]$tokens, [ref]$errors)
        $parseErrors = @($errors)
    }

    $rows.Add([PSCustomObject]@{
        Check   = 'Profile'
        Status  = if ($profileExists -and $parseErrors.Count -eq 0) { 'OK' } elseif ($profileExists) { 'ParserErrors' } else { 'Missing' }
        Details = if ($parseErrors) { ($parseErrors.Message -join '; ') } else { $ProfilePath }
    })

    foreach ($module in $script:HawkRequiredModules) {
        $available = Get-Module -ListAvailable -Name $module
        $rows.Add([PSCustomObject]@{
            Check   = "Module:$module"
            Status  = if ($available) { 'Available' } else { 'Missing' }
            Details = if ($available) { ($available | Select-Object -First 1).ModuleBase } else { 'Run Install-HawkPrerequisites' }
        })
    }

    $rows.Add([PSCustomObject]@{
        Check   = 'ProjectRoot'
        Status  = if ($ProjectRoot -and (Test-Path $ProjectRoot)) { 'OK' } else { 'Missing' }
        Details = $ProjectRoot
    })

    $llama = @(Get-HawkLlamaStatusCore | Select-Object -First 1)
    $rows.Add([PSCustomObject]@{
        Check   = 'Llama'
        Status  = if ($llama.Status -eq 'Reachable') { 'OK' } else { 'Unavailable' }
        Details = if ($llama.Status -eq 'Reachable') { Split-Path $llama.Model -Leaf } else { 'Run llamadoctor' }
    })

    $terminalIconsPrefs = Join-Path $env:APPDATA 'powershell\Community\Terminal-Icons'
    $rows.Add([PSCustomObject]@{
        Check   = 'TerminalIconsPrefs'
        Status  = if (Test-Path $terminalIconsPrefs) { 'Present' } else { 'Missing' }
        Details = $terminalIconsPrefs
    })

    Write-Host "`n  ⛨ HAWK DOCTOR — STACK HEALTH" -ForegroundColor Cyan
    foreach ($r in $rows) {
        $good = $r.Status -in @('OK', 'Available', 'Present')
        $glyph = if ($good) { '[OK]' } else { '[!!]' }
        $color = if ($good) { 'Green' } else { 'Red' }
        Write-Host '  ' -NoNewline
        Write-Host $glyph -NoNewline -ForegroundColor $color
        Write-Host (' ' + ("{0,-26}" -f $r.Check)) -NoNewline -ForegroundColor White
        $detail = [string]$r.Details
        if ($detail.Length -gt 60) { $detail = $detail.Substring(0, 57) + '...' }
        Write-Host " $detail" -ForegroundColor DarkGray
    }

    $bad = @($rows | Where-Object { $_.Status -notin @('OK', 'Available', 'Present') }).Count
    if ($bad -eq 0) {
        Write-Host '  [OK] All stack checks passed' -ForegroundColor Green
    }
    else {
        Write-Host "  [!!] $bad check(s) need attention" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
Runs full Hawk integration tests against the live system.
.DESCRIPTION
Tests profile, module imports, AI connectivity, PATH, and environment setup.
Displays a pass/fail table for each component.
.PARAMETER SkipAI
Skip AI/LLM engine connectivity tests.
.PARAMETER TimeoutSec
Timeout for AI tests in seconds. Default: 300.
#>
function Test-HawkSetup {
    [CmdletBinding()]
    param(
        [switch]$SkipAI,
        [int]$TimeoutSec = 300
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $add = {
        param($Name, $Ok, $Detail)
        $results.Add([pscustomobject]@{ Check = $Name; Passed = $Ok; Detail = $Detail })
    }

    # 1. modules
    $hybrid = [bool](Get-Module HawkwardHybrid)
    & $add 'modules' $hybrid "hybrid=$hybrid"

    # 2. engine
    $pwsh  = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
    $llama = [bool](Get-Command llama -ErrorAction SilentlyContinue)
    & $add 'engine' ($pwsh -and $llama) "pwsh=$pwsh llama=$llama"

    # 3. model
    $modelOk = $script:HawkLlamaModelPath -and (Test-Path -LiteralPath $script:HawkLlamaModelPath)
    & $add 'model' $modelOk $script:HawkLlamaModelPath

    # 4. config
    $cfg = Get-HawkConfig
    $cfgOk = $cfg -and $cfg.projectRoot -and $cfg.hfHome -and $cfg.llamaPort
    & $add 'config' $cfgOk "projectRoot=$($cfg.projectRoot) hfHome=$($cfg.hfHome) llamaPort=$($cfg.llamaPort)"

    # 5. env
    $hfEnv = [Environment]::GetEnvironmentVariable('HF_HOME', 'User')
    $envOk = (-not $hfEnv) -or ($hfEnv -eq $cfg.hfHome)
    & $add 'env' $envOk "HF_HOME=$hfEnv (config=$($cfg.hfHome))"

    # 6. AI known-answer round-trip (retry once, tolerance on '4')
    $aiOk = $true
    $aiDetail = 'skipped (SkipAI)'
    if (-not $SkipAI) {
        $aiOk = $false
        for ($attempt = 1; $attempt -le 2 -and -not $aiOk; $attempt++) {
            try {
                $resp = Invoke-HawkAI -Instruction 'What is 2+2? Reply with only the number.' -PassThru -TimeoutSec $TimeoutSec 6>$null
                $aiOk = $resp -match '4'
                $aiDetail = "attempt ${attempt}: '$resp'"
            } catch {
                $aiDetail = "attempt ${attempt}: $($_.Exception.Message)"
            }
        }
    }
    & $add 'ai' $aiOk $aiDetail

    # 7. auto-start proof: stop a running server, then prove Invoke-HawkAI restarts it
    $autoOk = $true
    $autoDetail = 'skipped'
    if (-not $SkipAI -and $aiOk) {
        $running = Get-HawkLlamaStatusCore -ErrorAction SilentlyContinue
        if ($running) {
            Stop-HawkLlamaServer 6>$null | Out-Null
            Start-Sleep -Seconds 2
            try {
                $resp = Invoke-HawkAI -Instruction 'Reply with the word OK.' -PassThru -TimeoutSec $TimeoutSec 6>$null
                $autoOk = $resp -match 'OK'
                $autoDetail = "stopped server, Invoke-HawkAI restarted it: '$resp'"
            } catch {
                $autoOk = $false
                $autoDetail = "auto-start failed: $($_.Exception.Message)"
            }
        } else {
            $autoDetail = 'server was not running; auto-start covered by ai check'
        }
    }
    & $add 'auto-start' $autoOk $autoDetail

    Write-Host "`n  ✓ HAWK SETUP — INTEGRATION TEST" -ForegroundColor Cyan
    foreach ($r in $results) {
        $glyph = if ($r.Passed) { '[PASS]' } else { '[FAIL]' }
        $color = if ($r.Passed) { 'Green' } else { 'Red' }
        Write-Host '  ' -NoNewline
        Write-Host ("{0,-7}" -f $glyph) -NoNewline -ForegroundColor $color
        Write-Host ("{0,-12}" -f $r.Check) -NoNewline -ForegroundColor White
        $detail = [string]$r.Detail
        if ($detail.Length -gt 55) { $detail = $detail.Substring(0, 52) + '...' }
        Write-Host " $detail" -ForegroundColor DarkGray
    }

    $failed = @($results | Where-Object { -not $_.Passed }).Count
    if ($failed -eq 0) {
        Write-Host "`n  [OK] ALL SYSTEMS OPERATIONAL" -ForegroundColor Green
    }
    else {
        Write-Host "`n  [!!] $failed check(s) FAILED" -ForegroundColor Red
    }

    # Machine-readable result for scripts/tests (console rendering above).
    [pscustomobject]@{
        Passed = ($failed -eq 0)
        Checks = $results
    }
}
<#
.SYNOPSIS
One-shot system health overview with color-coded status.
.DESCRIPTION
Displays uptime, RAM, disk usage, temp cleanup candidates, critical services, internet connectivity, Windows Defender status, and AI server status — all in ~25 lines.
#>
function Get-HawkSysView {
    [CmdletBinding()]
    param()

    Write-HawkHeader 'SYSVIEW — System Health Overview' 'Cyan'
    Write-Host ''

    # --- Uptime & Memory ---
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($os) {
        $uptime = (Get-Date) - $os.LastBootUpTime
        $memUsedPct = if ($os.TotalVisibleMemorySize -gt 0) {
            [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)
        } else { 0 }
        $memColor = if ($memUsedPct -ge 90) { 'Red' } elseif ($memUsedPct -ge 75) { 'Yellow' } else { 'Green' }
        Write-Host '  SYSTEM  ' -NoNewline -ForegroundColor DarkGray
        Write-Host "Uptime: $([math]::Floor($uptime.TotalHours))h $($uptime.Minutes)m" -NoNewline
        Write-Host '  ' -NoNewline
        Write-Host "RAM: ${memUsedPct}%" -ForegroundColor $memColor -NoNewline
        Write-Host " ($([math]::Round($os.FreePhysicalMemory / 1MB, 1)) GB free)"
    }

    # --- Disk ---
    Write-Host '  DISK    ' -NoNewline -ForegroundColor DarkGray
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    if ($drives) {
        foreach ($d in $drives) {
            $free = [math]::Round($d.FreeSpace / 1GB, 1)
            $usedPct = if ($d.Size -gt 0) { [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 0) } else { 0 }
            $color = if ($usedPct -ge 95) { 'Red' } elseif ($usedPct -ge 85) { 'Yellow' } else { 'Green' }
            Write-Host "$($d.DeviceID) ${usedPct}%" -ForegroundColor $color -NoNewline
            Write-Host " (${free}GB free) " -NoNewline
        }
    }

    # --- Temp cleanup candidates ---
    $tempSizes = @()
    $tempPaths = @($env:TEMP, "$env:LOCALAPPDATA\Temp") | Where-Object { $_ } | Sort-Object -Unique
    foreach ($tempVar in $tempPaths) {
        if ($tempVar -and (Test-Path -LiteralPath $tempVar -ErrorAction SilentlyContinue)) {
            $tempSize = (Get-ChildItem -LiteralPath $tempVar -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($tempSize -gt 0) { $tempSizes += $tempSize }
        }
    }
    $tempTotalGB = [math]::Round(($tempSizes | Measure-Object -Sum).Sum / 1GB, 2)
    if ($tempTotalGB -gt 0.5) {
        Write-Host "  TEMP    " -NoNewline -ForegroundColor DarkGray
        Write-Host "${tempTotalGB} GB temp files" -ForegroundColor Yellow -NoNewline
        Write-Host ' — diskclean to reclaim'
    }

    # --- Critical Services ---
    Write-Host '  SERVICES' -NoNewline -ForegroundColor DarkGray
    $criticalSvc = @('Spooler', 'WinDefend', 'WSearch', 'Dhcp', 'Dnscache', 'EventLog')
    $svcIssues = @()
    foreach ($name in $criticalSvc) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') { $svcIssues += "$name=$($svc.Status)" }
    }
    # Check llama-server as a process (not a Windows service)
    $llamaProc = Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue
    $llamaStatus = if ($llamaProc) { 'Running' } else { 'Stopped' }
    if ($llamaStatus -ne 'Running') { $svcIssues += "llama-server=$llamaStatus" }
    if ($svcIssues.Count -eq 0) {
        Write-Host ' All critical running' -ForegroundColor Green
    } else {
        Write-Host " Issues: $($svcIssues -join ', ')" -ForegroundColor Yellow
    }

    # --- Network ---
    Write-Host '  NETWORK ' -NoNewline -ForegroundColor DarkGray
    try {
        $probeHost = '8.8.8.8'
        $ping = Test-Connection -ComputerName $probeHost -Count 1 -TimeoutSeconds 2 -ErrorAction Stop
        Write-Host "Internet OK" -NoNewline -ForegroundColor Green
        Write-Host " ($([math]::Round($ping.ResponseTime))ms)"
    } catch {
        Write-Host 'Internet UNREACHABLE' -ForegroundColor Red
    }

    # --- Defender ---
    Write-Host '  DEFENDER' -NoNewline -ForegroundColor DarkGray
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp) {
        $rtColor = if ($mp.RealTimeProtectionEnabled) { 'Green' } else { 'Red' }
        Write-Host "RT: " -NoNewline
        Write-Host "$(if ($mp.RealTimeProtectionEnabled) { 'ON' } else { 'OFF' })" -ForegroundColor $rtColor -NoNewline
        $defAge = ((Get-Date) - $mp.AntivirusSignatureLastUpdated).Days
        $defColor = if ($defAge -le 3) { 'Green' } elseif ($defAge -le 7) { 'Yellow' } else { 'Red' }
        Write-Host "  Defs: " -NoNewline
        Write-Host "${defAge}d old" -ForegroundColor $defColor -NoNewline
        if ($mp.AntivirusScanEndTime -and ((Get-Date) - $mp.AntivirusScanEndTime).Days -le 7) {
            Write-Host "  Last scan: $([math]::Round(((Get-Date) - $mp.AntivirusScanEndTime).TotalHours))h ago" -NoNewline
        }
    } else {
        Write-Host 'Not available' -ForegroundColor DarkGray
    }

    # --- Pending Reboot ---
    $rebootPending = $false
    try {
        $cbsKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        $wuKey  = 'HKLM:\SOFTWARE\Microsoft\Windows\WindowsUpdate\Auto Update\RebootRequired'
        if ((Test-Path $cbsKey -ErrorAction SilentlyContinue) -or (Test-Path $wuKey -ErrorAction SilentlyContinue)) {
            $rebootPending = $true
        }
    } catch {}
    if ($rebootPending) {
        Write-Host '  REBOOT  ' -NoNewline -ForegroundColor DarkGray
        Write-Host 'Reboot pending' -ForegroundColor Yellow
    }

    # --- AI Server ---
    Write-Host '  AI      ' -NoNewline -ForegroundColor DarkGray
    try {
        $null = Invoke-RestMethod -Uri "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
        Write-Host 'llama-server ACTIVE' -ForegroundColor Green
    } catch {
        Write-Host 'llama-server STANDBY' -ForegroundColor DarkGray
    }

    Write-Host ''
}

<#
.SYNOPSIS
Displays the Hawk command dashboard with AI status.
.DESCRIPTION
Shows all available Hawk commands organized by suite (Sentinel, Diagnostics, Environment, AI & Workspace).
Indicates AI server status (active/standby) at the top.
#>
