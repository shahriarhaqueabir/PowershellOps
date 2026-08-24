function Get-HawkPortMap {
    <#
    .SYNOPSIS
    Shows active TCP connections with process info.
    .DESCRIPTION
    Lists TCP ports enriched with process name and company information.
    Default shows listening sockets; use -State Established for active
    remote traffic, or -State All for both views. Alias: portmap.
    .PARAMETER State
    Connection state to show: Listen (default), Established, or All.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Listen', 'Established', 'All')]
        [string]$State = 'Listen'
    )

    if ($State -in 'Listen', 'All') {
        Write-HawkHeader "`n  [Ports] Active listeners" Cyan
        Get-HawkTcpListeners |
        Sort-Object LocalPort |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                Port    = $_.LocalPort
                PID     = $_.OwningProcess
                Process = if ($proc) { $proc.ProcessName } else { '-' }
                Company = if ($proc) { try { $proc.Company } catch { 'Unknown' } } else { 'Unknown' }
            }
        }
    }

    if ($State -in 'Established', 'All') {
        Write-HawkHeader "`n  [Ports] Established connections" Cyan
        Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Sort-Object RemoteAddress |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                RemoteAddress = $_.RemoteAddress
                RemotePort    = $_.RemotePort
                LocalPort     = $_.LocalPort
                TargetApp     = if ($proc) { $proc.ProcessName } else { '-' }
            }
        }
    }
}

<#
.SYNOPSIS
Shows top CPU and RAM consuming processes.
.DESCRIPTION
Lists the top processes by CPU and memory usage, with color-coded severity.
Helps identify resource hogs quickly.
.PARAMETER Top
Number of processes to show. Default: 10.
#>
function Get-HawkResourceMap {
    [CmdletBinding()]
    param([int]$Top = 10)

    Write-HawkHeader "`n  [Resources] Top CPU/RAM consumers" Red
    Get-Process -ErrorAction SilentlyContinue |
    Sort-Object WorkingSet -Descending |
    Select-Object -First $Top |
    Select-Object ProcessName, Id,
    @{ Name = 'RAMMB'; Expression = { [Math]::Round($_.WorkingSet / 1MB, 0) } },
    @{ Name = 'CPUSec'; Expression = { [Math]::Round($_.CPU, 1) } },
    Company
}

function Invoke-HawkProject {
    <#
    .SYNOPSIS
    Changes directory to the configured project root.
    .DESCRIPTION
    Navigates to the Hawkward project root directory. Use the alias 'proj'.
    .PARAMETER Path
    Directory to navigate to. Defaults to $global:HawkProjectRoot.
    #>
    [CmdletBinding()]
    param([string]$Path = $global:HawkProjectRoot)

    if (Test-Path $Path) {
        Set-Location $Path
        Write-Host "  [Project] Jumped to: $Path" -ForegroundColor Blue
    }
    else {
        throw "Project root $Path not found."
    }
}

function Start-HawkLlamaServer {
    <#
    .SYNOPSIS
    Starts the llama.cpp inference server.
    .DESCRIPTION
    Launches llama-server with the configured model on the configured port.
    Returns the process object. Use the alias 'llamastart'.
    .PARAMETER ModelPath
    Path to the GGUF model file. Defaults to the configured Hawk model.
    .PARAMETER Port
    HTTP port for the server. Defaults to the configured Hawk port.
    #>
    [CmdletBinding()]
    param(
        [string]$ModelPath = $script:HawkLlamaModelPath,
        [int]$Port = $script:HawkLlamaPort
    )

    $llama = Get-Command llama -ErrorAction SilentlyContinue
    if (-not $llama) {
        Write-Warning 'llama.cpp not found in PATH. Install with: irm https://llama.app/install.ps1 | iex'
        return $null
    }

    if (-not $ModelPath) {
        Write-Warning 'llama model not configured. Set modelPath in hawk.config.json or run: hawkmodel -Switch <name>'
        return $null
    }

    if (-not (Test-Path -LiteralPath $ModelPath)) {
        Write-Warning "llama model not found: $ModelPath"
        return $null
    }

    $probe = New-Object System.Net.Sockets.TcpClient
    try {
        $probe.Connect('127.0.0.1', $Port)
        $alreadyUp = $probe.Connected
    } catch {
        $alreadyUp = $false
    } finally {
        $probe.Dispose()
    }
    if ($alreadyUp) {
        Write-Verbose "Port $Port already has a listener; skipping llama-server start."
        return $null
    }

    $logDir = Join-Path $env:LOCALAPPDATA 'llama-app\logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null

    $arguments = @(
        'serve',
        '-m', $ModelPath,
        '--host', '127.0.0.1',
        '--port', "$Port",
        '-c', '32768',
        '-t', '8',
        '--flash-attn', 'on',
        '--no-warmup'
    )

    $proc = Start-Process -FilePath $llama.Source `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'llama-serve.out.log') `
        -RedirectStandardError (Join-Path $logDir 'llama-serve.err.log') `
        -PassThru

    Write-Host "  llama.cpp server starting (PID $($proc.Id), port $Port)" -ForegroundColor DarkGray
    return $proc
}

function Stop-HawkLlamaServer {
    <#
    .SYNOPSIS
    Stops the running llama.cpp server process.
    .DESCRIPTION
    Finds and terminates the llama-server process listening on the configured port.
    Use the alias 'llamastop'.
    .PARAMETER Port
    Port to match against. Defaults to the configured Hawk port.
    #>
    [CmdletBinding()]
    param(
        [int]$Port = $script:HawkLlamaPort
    )

    $procs = Get-CimInstance Win32_Process -Filter "Name='llama.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "--port $Port" }
    foreach ($p in $procs) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "  llama.cpp server stopped (PID $($p.ProcessId), port $Port)" -ForegroundColor DarkGray
    }
    if (-not $procs) {
        Write-Host "  no llama server running on port $Port" -ForegroundColor DarkGray
    }
}
function Get-HawkLlamaStatusCore {
    [CmdletBinding()]
    param(
        [string]$Endpoint = $script:HawkLlamaEndpoint,
        [switch]$Start
    )

    try {
        $resp = Invoke-RestMethod -Uri "$Endpoint/v1/models" -TimeoutSec 3 -ErrorAction Stop
        foreach ($model in @($resp.data)) {
            [PSCustomObject]@{
                Endpoint = $Endpoint
                Status   = 'Reachable'
                Model    = $model.id
                SizeGB   = if ($model.meta.size) { [Math]::Round($model.meta.size / 1GB, 2) } else { '' }
                Modified = ''
            }
        }
    }
    catch {
        if ($Start) {
            $proc = Start-HawkLlamaServer
            if ($proc) {
                for ($i = 0; $i -lt 60; $i++) {
                    Start-Sleep -Seconds 1
                    try {
                        $resp = Invoke-RestMethod -Uri "$Endpoint/v1/models" -TimeoutSec 2 -ErrorAction Stop
                        [PSCustomObject]@{
                            Endpoint = $Endpoint
                            Status   = 'Started'
                            Model    = $resp.data[0].id
                            SizeGB   = ''
                            Modified = "PID $($proc.Id)"
                        }
                        return
                    }
                    catch { }
                }
                [PSCustomObject]@{
                    Endpoint = $Endpoint
                    Status   = 'Starting'
                    Model    = ''
                    SizeGB   = ''
                    Modified = "PID $($proc.Id) still loading model"
                }
            }
            else {
                [PSCustomObject]@{
                    Endpoint = $Endpoint
                    Status   = 'Unavailable'
                    Model    = ''
                    SizeGB   = ''
                    Modified = 'llama.cpp or model missing'
                }
            }
        }
        else {
            [PSCustomObject]@{
                Endpoint = $Endpoint
                Status   = 'Unavailable'
                Model    = ''
                SizeGB   = ''
                Modified = $_.Exception.Message
            }
        }
    }
}

function Get-HawkLlamaStatus {
    <#
    .SYNOPSIS
    Checks if the llama.cpp server is reachable and reports model info.
    .DESCRIPTION
    Queries the local llama endpoint for loaded model status and renders a
    color-coded summary. Use -Start to auto-launch the server when offline.
    Use -PassThru to also receive the raw status objects (used by doctor,
    setup checks, and reports). Alias: aidoctor.
    .PARAMETER Endpoint
    Llama server URL. Defaults to the configured Hawk endpoint.
    .PARAMETER Start
    Auto-start the server if it is not running.
    .PARAMETER PassThru
    Emit the raw status object(s) in addition to rendering.
    #>
    [CmdletBinding()]
    param(
        [string]$Endpoint = $script:HawkLlamaEndpoint,
        [switch]$Start,
        [switch]$PassThru
    )

    $coreArgs = @{ Endpoint = $Endpoint }
    if ($Start) { $coreArgs.Start = $true }
    $rows = @(Get-HawkLlamaStatusCore @coreArgs)

    Write-Host "`n  ◆ LLAMA SERVER STATUS" -ForegroundColor Magenta
    foreach ($r in $rows) {
        $statusColor = switch -Wildcard ($r.Status) {
            'Reachable' { 'Green' }
            'Started'   { 'Green' }
            'Starting'  { 'Yellow' }
            default     { 'Red' }
        }
        Write-Host '  Endpoint : ' -NoNewline; Write-Host $r.Endpoint -ForegroundColor DarkGray
        Write-Host '  Status   : ' -NoNewline; Write-Host $r.Status -ForegroundColor $statusColor
        if ($r.Model) {
            Write-Host '  Model    : ' -NoNewline; Write-Host (Split-Path $r.Model -Leaf) -ForegroundColor White
        }
        if ($r.SizeGB) {
            Write-Host '  Size     : ' -NoNewline; Write-Host "$($r.SizeGB) GB" -ForegroundColor DarkGray
        }
        if ($r.Modified) {
            Write-Host '  Info     : ' -NoNewline; Write-Host $r.Modified -ForegroundColor DarkGray
        }
    }

    if ($PassThru) { $rows }
}

function Invoke-HawkLlamaDoctor {
    <#
    .SYNOPSIS
    Diagnoses llama.cpp and auto-starts the server if needed.
    .DESCRIPTION
    Wrapper that calls the llama status check with -Start to probe server
    health and automatically launch it if offline. Alias: llamadoctor.
    #>
    Get-HawkLlamaStatus -Start
}

function Get-HawkModel {
    <#
    .SYNOPSIS
    Lists local GGUF models and switches the active Hawk model.
    .DESCRIPTION
    Scans the configured HfHome directory for GGUF files and marks the active
    model. Use -Switch with a name substring to make another model the default:
    stops a running server, persists the choice to hawk.config.json, and
    restarts the server on the new model (skip with -NoRestart). Alias: hawkmodel.
    .PARAMETER Switch
    Substring of the GGUF file name to activate.
    .PARAMETER NoRestart
    Persist the switch without restarting a running llama server.
    #>
    [CmdletBinding()]
    param(
        [string]$Switch,
        [switch]$NoRestart
    )

    $cfg = Get-HawkConfig
    $hfHome = $cfg.HfHome
    if (-not (Test-Path -LiteralPath $hfHome)) {
        Write-Host "  [models] model directory not found: $hfHome" -ForegroundColor Yellow
        return
    }

    $models = @(Get-ChildItem -LiteralPath $hfHome -Recurse -Filter '*.gguf' -File -ErrorAction SilentlyContinue | Sort-Object FullName)
    if (-not $models.Count) {
        Write-Host "  [models] no .gguf files under: $hfHome" -ForegroundColor Yellow
        return
    }

    $loadedLeaf = $null
    try {
        $resp = Invoke-RestMethod "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
        if ($resp.data.Count) { $loadedLeaf = Split-Path $resp.data[0].id -Leaf }
    } catch { }

    if ($Switch) {
        $hits = @($models | Where-Object { $_.Name -like "*$Switch*" })
        if ($hits.Count -eq 0) {
            Write-Host "  [models] no model matches '$Switch'" -ForegroundColor Yellow
            return
        }
        if ($hits.Count -gt 1) {
            Write-Host "  [models] ambiguous match '$Switch' — candidates:" -ForegroundColor Yellow
            foreach ($m in $hits) { Write-Host "    $($m.Name)" -ForegroundColor DarkGray }
            return
        }
        $target = $hits[0]

        $wasRunning = [bool]$loadedLeaf
        if ($wasRunning -and -not $NoRestart) {
            Stop-HawkLlamaServer | Out-Null
        }

        $configPath = $script:HawkConfigPath
        $json = if (Test-Path -LiteralPath $configPath) {
            Get-Content -LiteralPath $configPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        } else { $null }
        if (-not $json) { $json = [pscustomobject]@{ } | Select-Object projectRoot, hfHome, llamaPort, modelPath }
        $json | Add-Member -NotePropertyName modelPath -NotePropertyValue $target.FullName -Force
        $json | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8

        $script:HawkLlamaModelPath = $target.FullName

        Write-Host '  ◆ HAWK MODELS' -ForegroundColor Magenta
        Write-Host '  Status : ' -NoNewline; Write-Host "switched to $($target.Name)" -ForegroundColor Green
        Write-Host '  Path   : ' -NoNewline; Write-Host $target.FullName -ForegroundColor DarkGray
        Write-Host '  Saved  : ' -NoNewline; Write-Host $configPath -ForegroundColor DarkGray

        if ($wasRunning -and -not $NoRestart) {
            Write-Host '  Info   : restarting server on new model...' -ForegroundColor DarkGray
            Start-HawkLlamaServer | Out-Null
            $ready = $false
            for ($i = 0; $i -lt 60; $i++) {
                Start-Sleep -Seconds 1
                try {
                    $null = Invoke-RestMethod "$($script:HawkLlamaEndpoint)/v1/models" -TimeoutSec 2 -ErrorAction Stop
                    $ready = $true
                    break
                } catch { }
            }
            if ($ready) {
                Write-Host '  [OK] server ready on new model' -ForegroundColor Green
            } else {
                Write-Host '  [!!] server not ready after 60s (check llamadoctor)' -ForegroundColor Red
            }
        }
        return
    }

    Write-Host "`n  ◆ HAWK MODELS — $hfHome" -ForegroundColor Magenta
    foreach ($m in $models) {
        $isActive = ($m.FullName -eq $cfg.ModelPath) -or ($loadedLeaf -eq $m.Name)
        $marker = if ($isActive) { '►' } else { ' ' }
        $color = if ($isActive) { 'Green' } else { 'White' }
        $sizeGB = [Math]::Round($m.Length / 1GB, 2)
        Write-Host "  $marker " -NoNewline -ForegroundColor $color
        $name = if ($m.Name.Length -gt 44) { $m.Name.Substring(0, 41) + '...' } else { $m.Name }
        $label = if ($isActive) { "$($name.PadRight(44))[ACTIVE]" } else { $name }
        Write-Host "  $marker " -NoNewline -ForegroundColor $color
        Write-Host $label.PadRight(55) -NoNewline -ForegroundColor $color
        Write-Host "$sizeGB GB" -ForegroundColor DarkGray
    }
    Write-Host "`n  switch with: hawkmodel -Switch <name-part>" -ForegroundColor DarkGray
}

<#
.SYNOPSIS
Audits PATH entries for duplicates and missing directories.
.DESCRIPTION
Validates every PATH segment exists on disk, identifies duplicate entries,
and flags missing directories. Renders a color-coded report with a summary.
Use -PassThru to also receive the raw row objects for scripting.
.PARAMETER PathValue
The PATH string to audit. Defaults to the current $env:Path.
.PARAMETER IncludeRegistry
Also audit the PATH values persisted in the registry (Machine:
HKLM Session Manager\Environment, User: HKCU Environment). Entries are
expanded (%VAR% resolved) before validation, matching real resolution
behavior. Adds a Scope column (Process/Machine/User) to every row.
.PARAMETER PassThru
Emit the raw audit rows in addition to rendering.
#>
function Get-HawkPathAudit {
    [CmdletBinding()]
    param(
        [string]$PathValue = $env:Path,
        [switch]$IncludeRegistry,
        [switch]$PassThru
    )

    $buildRows = {
        param([string]$ScopeName, [string]$RawPathValue)
        $scopeSeen = @{}
        $scopeRows = @()
        $segments = @($RawPathValue -split ';')
        for ($i = 0; $i -lt $segments.Count; $i++) {
            $path = $segments[$i].Trim()
            if (-not $path) {
                $scopeRows += [PSCustomObject]@{
                    Scope     = $ScopeName
                    Index     = $i
                    Path      = ''
                    Status    = 'Empty'
                    Duplicate = $false
                }
                continue
            }
            $key = $path.ToLowerInvariant()
            $duplicate = $scopeSeen.ContainsKey($key)
            $scopeSeen[$key] = $true
            $scopeRows += [PSCustomObject]@{
                Scope     = $ScopeName
                Index     = $i
                Path      = $path
                Status    = if (Test-Path $path) { 'OK' } else { 'Missing' }
                Duplicate = $duplicate
            }
        }
        return ,$scopeRows
    }

    $renderSection = {
        param([string]$Title, $sectionRows)
        Write-Host "`n  ⇉ PATH AUDIT — $Title" -ForegroundColor Green
        foreach ($r in $sectionRows) {
            Write-Host ('   {0,3} ' -f $r.Index) -NoNewline -ForegroundColor DarkGray
            $disp = [string]$r.Path
            if ($disp.Length -gt 58) { $disp = $disp.Substring(0, 55) + '...' }
            Write-Host ("{0,-58}" -f $disp) -NoNewline -ForegroundColor White
            $statusColor = switch ($r.Status) {
                'OK'      { 'Green' }
                'Missing' { 'Red' }
                default   { 'DarkGray' }
            }
            Write-Host ("{0,-8}" -f $r.Status) -NoNewline -ForegroundColor $statusColor
            if ($r.Duplicate) {
                Write-Host ' DUP' -NoNewline -ForegroundColor Yellow
            }
            Write-Host ''
        }
    }

    $allRows = [System.Collections.Generic.List[object]]::new()

    $procRows = & $buildRows 'Process' $PathValue
    & $renderSection 'process scope' @($procRows | Where-Object Scope -eq 'Process')
    foreach ($r in $procRows) { $allRows.Add($r) }

    if ($IncludeRegistry) {
        foreach ($entry in @(
            @{ Scope = 'Machine'; Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'; Label = 'persisted (Machine)' },
            @{ Scope = 'User';    Key = 'HKCU:\Environment';                                                  Label = 'persisted (User)' }
        )) {
            try {
                $item = Get-Item -LiteralPath $entry.Key -ErrorAction Stop
                $rawReg = [string]$item.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
            }
            catch {
                Write-Host "`n  ⇉ PATH AUDIT — $($entry.Label)" -ForegroundColor Green
                Write-Host '   [!!] registry key not readable' -ForegroundColor Red
                continue
            }
            $expanded = if ($rawReg) { [Environment]::ExpandEnvironmentVariables($rawReg) } else { '' }
            $regRows = & $buildRows $entry.Scope $expanded
            & $renderSection $entry.Label @($regRows | Where-Object Scope -eq $entry.Scope)
            foreach ($r in $regRows) { $allRows.Add($r) }
        }
    }

    $missing = @($allRows | Where-Object Status -eq 'Missing').Count
    $dupes = @($allRows | Where-Object Duplicate).Count
    if ($missing -eq 0 -and $dupes -eq 0) {
        Write-Host "  [OK] segments: $($allRows.Count) | clean PATH" -ForegroundColor Green
    }
    else {
        Write-Host "  [!!] segments: $($allRows.Count) | missing: $missing | duplicates: $dupes" -ForegroundColor Yellow
    }

    if ($PassThru) { $allRows }
}

<#
.SYNOPSIS
Quick network triage — active listeners matched against firewall rules.
.DESCRIPTION
Lists TCP listeners with their owning process and matching firewall rule (if any).
Use as a first-pass network health check. With -WanCheck, also pings a public
resolver and lists active IPv4 interfaces before the listener table.
.PARAMETER WanCheck
Prepend WAN reachability (1.1.1.1 ping) and active interface summary.
#>
function Get-HawkNetworkTriage {
    [CmdletBinding()]
    param([switch]$WanCheck)

    if ($WanCheck) {
        Write-HawkHeader '  [Network] WAN connectivity check' Green
        $probeHost = '1.1.1.1'
        $ping = Test-Connection $probeHost -Count 1 -Quiet -ErrorAction SilentlyContinue
        $statusText = if ($ping) { 'ONLINE' } else { 'OFFLINE' }
        $statusColor = if ($ping) { 'Green' } else { 'Red' }
        Write-Host '  WAN Infrastructure Access Gateway: ' -NoNewline; Write-Host $statusText -ForegroundColor $statusColor
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -notlike '127.*' |
        ForEach-Object {
            $int = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
            if ($int -and $int.Status -eq 'Up') {
                [PSCustomObject]@{ Interface = $int.InterfaceDescription; IP = $_.IPAddress }
            }
        } | Format-Table -AutoSize | Out-Host
    }

    Write-HawkHeader '  [Network] Listener/firewall triage' Cyan
    $filters = @(Get-HawkEnabledInboundTcpPortFilters)
    $filterUnavailable = $script:HawkLastFirewallFilterError
    Get-HawkTcpListeners |
    Sort-Object LocalPort |
    ForEach-Object {
        $port = [int]$_.LocalPort
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        $matched = $filters |
            Where-Object { Test-HawkPortSpecMatch -PortSpec $_.LocalPort -Port $port } |
            Where-Object { $_.LocalPort -ne 'Any' } |
            Select-Object -First 1
        if (-not $matched) {
            $matched = $filters | Where-Object { $_.LocalPort -eq 'Any' } | Select-Object -First 1
        }
        [PSCustomObject]@{
            Port         = $port
            PID          = $_.OwningProcess
            Process      = if ($proc) { $proc.ProcessName } else { '-' }
            LocalAddress = $_.LocalAddress
            FirewallRule = if ($filterUnavailable) { '<unavailable>' } elseif ($matched) { $matched.DisplayName } else { '' }
            FirewallPort = if ($matched) { $matched.LocalPort } else { '' }
        }
    }
}

<#
.SYNOPSIS
Audits git repositories under a project root.
.DESCRIPTION
Enumerates git repos under the project directory and renders branch, dirty
file count, and last commit info per repository. Use -PassThru to also
receive the raw row objects for scripting.
.PARAMETER ProjectRoot
Root directory to scan. Defaults to $global:HawkProjectRoot.
.PARAMETER Depth
Directory scan depth. Default: 1.
.PARAMETER PassThru
Emit the raw audit rows in addition to rendering.
#>
