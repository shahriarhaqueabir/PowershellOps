# Hawkward Hybrid - module-backed local ops toolkit.

$script:HawkVersion = '11.2'
$script:HawkDefaultProjectRoot = 'E:\Projects'
$script:HawkRequiredModules = @('Terminal-Icons', 'PSReadLine', 'PSTree')
$script:HawkSuppressHeaders = $false
$script:HawkSensitiveNamePattern = '(?i)(secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)'
$script:HawkLastFirewallFilterError = $null
$script:HawkReportRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Reports'

function Write-HawkHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = 'Cyan'
    )

    if (-not $script:HawkSuppressHeaders) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-HawkInteractiveSession {
    if ($env:HAWK_NO_DASH) { return $false }
    if ($env:CI) { return $false }

    try {
        return [Environment]::UserInteractive -and -not [Console]::IsOutputRedirected
    }
    catch {
        return $false
    }
}

function Install-HawkPrerequisites {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string[]]$ModuleName = $script:HawkRequiredModules
    )

    foreach ($module in $ModuleName) {
        if (Get-Module -ListAvailable -Name $module) {
            [PSCustomObject]@{
                Module = $module
                Status = 'AlreadyInstalled'
            }
            continue
        }

        if ($PSCmdlet.ShouldProcess($module, 'Install PowerShell module for current user')) {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            [PSCustomObject]@{
                Module = $module
                Status = 'Installed'
            }
        }
    }
}

function Import-HawkPrerequisites {
    [CmdletBinding()]
    param(
        [string[]]$ModuleName = $script:HawkRequiredModules,
        [switch]$Quiet
    )

    $results = foreach ($module in $ModuleName) {
        $available = Get-Module -ListAvailable -Name $module
        if (-not $available) {
            [PSCustomObject]@{
                Module  = $module
                Status  = 'Missing'
                Message = 'Run Install-HawkPrerequisites to install it.'
            }
            continue
        }

        try {
            # Terminal-Icons can emit preference-file write errors on locked profiles.
            Import-Module -Name $module -ErrorAction SilentlyContinue 2>$null
            [PSCustomObject]@{
                Module  = $module
                Status  = 'Imported'
                Message = ''
            }
        }
        catch {
            [PSCustomObject]@{
                Module  = $module
                Status  = 'Failed'
                Message = $_.Exception.Message
            }
        }
    }

    if (-not $Quiet) {
        $results
    }
}

function Set-HawkReadLine {
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) {
        return
    }

    try {
        Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
    }
    catch {
        # Some hosts do not expose the console handles PSReadLine wants.
    }
}

function Get-HawkPromptText {
    param([bool]$LastSuccess = $true)

    $esc = [char]27
    $reset = "${esc}[0m"
    $user = [Environment]::UserName
    $hostName = [Environment]::MachineName
    $psVer = $PSVersionTable.PSVersion.ToString()
    $os = ([System.Runtime.InteropServices.RuntimeInformation]::OSDescription -replace 'Microsoft ', '').Trim()
    $path = (Get-Location).Path -replace "^$([Regex]::Escape([Environment]::GetFolderPath('UserProfile')))", '~'

    $bgSys = "${esc}[48;5;60m${esc}[38;5;255m"
    $bgUsr = "${esc}[48;5;25m${esc}[38;5;255m"
    $bgPth = "${esc}[48;5;208m${esc}[38;5;0m"
    $sep = ' '

    $segSys = "${bgSys} 💻 $os | PS $psVer ${reset}"
    $segUsr = "${bgUsr} ⚡ $user@$hostName ${reset}"
    $segPth = "${bgPth} 📂 $path ${reset}"
    $segGit = Get-HawkPromptGitSegment -Reset $reset

    $topLine = "$segSys$sep$segUsr$sep$segPth"
    if ($segGit) { $topLine += "$sep$segGit" }

    $statusColor = if ($LastSuccess) { "${esc}[38;5;82m" } else { "${esc}[38;5;196m" }
    return "`n$topLine`n${statusColor}>${reset} "
}

function Get-HawkPromptGitSegment {
    param([string]$Reset)

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return ''
    }

    $cwd = (Get-Location).Path
    $now = Get-Date
    $cache = $global:HawkPromptGitCache
    if ($cache -and $cache.Path -eq $cwd -and (($now - $cache.Time).TotalSeconds -lt 2)) {
        return $cache.Segment
    }

    $segment = ''
    try {
        $inside = & git -C $cwd rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0 -and $inside -eq 'true') {
            $branch = & git -C $cwd branch --show-current 2>$null
            if (-not $branch) {
                $branch = & git -C $cwd rev-parse --short HEAD 2>$null
            }

            if ($branch) {
                $status = & git -C $cwd status --porcelain -uno 2>$null
                $esc = [char]27
                if ($status) {
                    $bgGit = "${esc}[48;5;136m${esc}[38;5;255m"
                    $segment = "${bgGit} 🌿 $branch [⚠️] ${Reset}"
                }
                else {
                    $bgGit = "${esc}[48;5;28m${esc}[38;5;255m"
                    $segment = "${bgGit} 🌿 $branch [✅] ${Reset}"
                }
            }
        }
    }
    catch {
        $segment = ''
    }

    $global:HawkPromptGitCache = [PSCustomObject]@{
        Path    = $cwd
        Time    = $now
        Segment = $segment
    }
    return $segment
}

function Set-HawkPrompt {
    Set-Item -Path Function:\global:Prompt -Value {
        $lastSuccess = $?
        Get-HawkPromptText -LastSuccess:$lastSuccess
    }
}

function Protect-HawkSensitiveText {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return
        }

        $text = if ($InputObject -is [string]) { $InputObject } else { $InputObject | Out-String }
        $redacted = [regex]::Replace(
            $text,
            '(?im)^(\s*[^=\r\n]*(?:secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)[^=\r\n]*\s*=\s*).+$',
            '$1<REDACTED>'
        )
        $redacted = [regex]::Replace(
            $redacted,
            '(?i)("(?:[^"]*(?:secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)[^"]*)"\s*:\s*")[^"]*(")',
            '$1<REDACTED>$2'
        )
        $redacted
    }
}

function Get-HawkBootMap {
    [CmdletBinding()]
    param()

    if (-not $script:HawkSuppressHeaders -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning 'Non-admin session: registry access may be limited.'
    }

    Write-HawkHeader '  [Startup] Registry startup scraper' Yellow
    $regPaths = @(
        @{ Hive = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' }
    )

    foreach ($entry in $regPaths) {
        if (-not (Test-Path $entry.Path)) { continue }

        $key = Get-ItemProperty -Path $entry.Path -ErrorAction SilentlyContinue
        $key.PSObject.Properties |
        Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*' } |
        ForEach-Object {
            [PSCustomObject]@{
                Hive   = $entry.Hive
                Name   = $_.Name
                Target = $_.Value
                Source = $entry.Path
            }
        }
    }
}

function Get-HawkEventMap {
    [CmdletBinding()]
    param(
        [int]$MaxEvents = 20,
        [string[]]$LogName = @('System', 'Application')
    )

    Write-HawkHeader "  [Events] System/Application warnings and errors (last $MaxEvents)" Cyan
    Get-WinEvent -FilterHashtable @{ LogName = $LogName; Level = 2, 3 } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message
}

function Get-HawkFirewallMap {
    [CmdletBinding()]
    param([int]$First = 15)

    Write-HawkHeader '  [Firewall] Enabled inbound allow rules' Yellow
    Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction SilentlyContinue |
    Select-Object Name, DisplayName, Profile |
    Select-Object -First $First
}

function Get-HawkEnvMap {
    [CmdletBinding()]
    param([switch]$IncludeSensitive)

    Write-HawkHeader '  [Environment] Variable audit' Blue
    Get-ChildItem Env: |
    Sort-Object Name |
    ForEach-Object {
        $sensitive = $_.Name -match $script:HawkSensitiveNamePattern
        [PSCustomObject]@{
            Name      = $_.Name
            Value     = if ($sensitive -and -not $IncludeSensitive) { '<REDACTED>' } else { $_.Value }
            Sensitive = $sensitive
        }
    }
}

function Get-HawkTcpListeners {
    [CmdletBinding()]
    param()

    try {
        Get-NetTCPConnection -State Listen -ErrorAction Stop |
        Select-Object LocalAddress, LocalPort, OwningProcess, @{ Name = 'Source'; Expression = { 'Get-NetTCPConnection' } }
        return
    }
    catch {
        Write-Verbose "Get-NetTCPConnection unavailable, falling back to netstat: $($_.Exception.Message)"
    }

    $lines = & netstat -ano -p tcp 2>$null
    foreach ($line in $lines) {
        if ($line -match '^\s*TCP\s+(.+):(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$') {
            [PSCustomObject]@{
                LocalAddress  = $matches[1]
                LocalPort     = [int]$matches[2]
                OwningProcess = [int]$matches[3]
                Source        = 'netstat'
            }
        }
    }
}

function Get-HawkGhostPortAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Ports] Ghost listener audit' Red
    $net = Get-HawkTcpListeners
    $ghosts = foreach ($conn in $net) {
        if ($conn.OwningProcess -ne 0 -and -not (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue)) {
            [PSCustomObject]@{
                Port   = $conn.LocalPort
                PID    = $conn.OwningProcess
                Status = 'Ghost/Orphaned'
            }
        }
    }

    if ($ghosts) { $ghosts }
    else { Write-HawkHeader '  [OK] No ghost listeners detected.' Green }
}

function Get-HawkEnabledInboundTcpPortFilters {
    [CmdletBinding()]
    param()

    $script:HawkLastFirewallFilterError = $null
    try {
        $rules = Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow -ErrorAction Stop
        foreach ($rule in $rules) {
            $filters = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
            foreach ($filter in $filters) {
                if ($filter.Protocol -in @('TCP', 'Any')) {
                    [PSCustomObject]@{
                        RuleName    = $rule.Name
                        DisplayName = $rule.DisplayName
                        Profile     = [string]$rule.Profile
                        Protocol    = [string]$filter.Protocol
                        LocalPort   = [string]$filter.LocalPort
                    }
                }
            }
        }
    }
    catch {
        $script:HawkLastFirewallFilterError = $_.Exception.Message
        @()
    }
}

function Test-HawkPortSpecMatch {
    param(
        [Parameter(Mandatory = $true)][string]$PortSpec,
        [Parameter(Mandatory = $true)][int]$Port
    )

    foreach ($token in ($PortSpec -split ',')) {
        $value = $token.Trim()
        if (-not $value) { continue }
        if ($value -eq 'Any') { return $true }
        if ($value -match '^\d+$' -and [int]$value -eq $Port) { return $true }
        if ($value -match '^(\d+)-(\d+)$') {
            $start = [int]$matches[1]
            $end = [int]$matches[2]
            if ($Port -ge $start -and $Port -le $end) { return $true }
        }
    }

    return $false
}

function Get-HawkFirewallAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Firewall] Open ports vs enabled inbound allow rules' Magenta
    $connections = Get-HawkTcpListeners
    $filters = @(Get-HawkEnabledInboundTcpPortFilters)

    if ($script:HawkLastFirewallFilterError) {
        [PSCustomObject]@{
            Port        = ''
            PID         = ''
            Process     = ''
            Status      = "Firewall rules unavailable: $script:HawkLastFirewallFilterError"
            MatchedRule = ''
        }
        return
    }

    foreach ($group in ($connections | Group-Object LocalPort | Sort-Object { [int]$_.Name })) {
        $port = [int]$group.Name
        $pids = @($group.Group.OwningProcess | Sort-Object -Unique)
        $processNames = foreach ($pid in $pids) {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) { $proc.ProcessName }
        }

        $matched = $filters | Where-Object { Test-HawkPortSpecMatch -PortSpec $_.LocalPort -Port $port } | Select-Object -First 1
        if (-not $matched) {
            [PSCustomObject]@{
                Port        = $port
                PID         = ($pids -join ',')
                Process     = (($processNames | Sort-Object -Unique) -join ',')
                Status      = 'No enabled inbound allow port filter'
                MatchedRule = ''
            }
        }
    }
}

function Get-HawkSuspiciousProcessAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Processes] Temp/AppData process audit' Red
    foreach ($proc in (Get-Process -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $proc.Path } catch { }
        if ($path -and $path -match '(?i)\\(AppData|Temp)\\') {
            [PSCustomObject]@{
                ProcessName = $proc.ProcessName
                Id          = $proc.Id
                Path        = $path
                Company     = try { $proc.Company } catch { $null }
            }
        }
    }
}

function Get-HawkDiskPressureAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Disk] Disk pressure map' Yellow
    try {
        $disks = @(Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object DriveType -eq 3)
        if ($disks.Count -gt 0) {
            $disks | Select-Object DeviceID,
            @{ Name = 'SizeGB'; Expression = { [Math]::Round($_.Size / 1GB, 2) } },
            @{ Name = 'FreeGB'; Expression = { [Math]::Round($_.FreeSpace / 1GB, 2) } },
            @{ Name = 'FreePercent'; Expression = { if ($_.Size) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 } } },
            @{ Name = 'Source'; Expression = { 'CIM' } }
            return
        }
    }
    catch {
        Write-Verbose "CIM disk query unavailable, falling back to PSDrive: $($_.Exception.Message)"
    }

    Get-PSDrive -PSProvider FileSystem |
    Where-Object { $null -ne $_.Free -and $null -ne $_.Used -and $_.Root -match '^[A-Za-z]:\\$' } |
    Select-Object @{ Name = 'DeviceID'; Expression = { "$($_.Name):" } },
    @{ Name = 'SizeGB'; Expression = { [Math]::Round(($_.Used + $_.Free) / 1GB, 2) } },
    @{ Name = 'FreeGB'; Expression = { [Math]::Round($_.Free / 1GB, 2) } },
    @{ Name = 'FreePercent'; Expression = { if (($_.Used + $_.Free) -gt 0) { [Math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 2) } else { 0 } } },
    @{ Name = 'Source'; Expression = { 'PSDrive' } }
}

function Get-HawkScheduledTaskRiskAudit {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Tasks] Scheduled task risk audit' DarkYellow
    Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object State -ne 'Disabled' |
    ForEach-Object {
        $task = $_
        $execActions = $task.Actions | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskExecAction' }
        foreach ($action in $execActions) {
            $text = "$($action.Execute) $($action.Arguments)"
            if ($text -match '(?i)AppData|Temp|powershell|pwsh|cmd') {
                [PSCustomObject]@{
                    TaskPath = $task.TaskPath
                    TaskName = $task.TaskName
                    Path     = $action.Execute
                    Args     = $action.Arguments
                }
            }
        }
    }
}

function Get-HawkEventStormAudit {
    [CmdletBinding()]
    param(
        [int]$WindowMinutes = 30,
        [int]$Threshold = 5,
        [string]$LogName = 'System'
    )

    Write-HawkHeader "  [Events] Event storm detection ($WindowMinutes minute window)" DarkRed
    $window = (Get-Date).AddMinutes(-$WindowMinutes)
    Get-WinEvent -FilterHashtable @{ LogName = $LogName; StartTime = $window } -ErrorAction SilentlyContinue |
    Group-Object Id |
    Where-Object Count -gt $Threshold |
    Select-Object Count, Name, @{ Name = 'Source'; Expression = { $_.Group[0].ProviderName } }
}

function Invoke-HawkAI {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        $InputData,
        [Parameter(Position = 0)]
        [string]$Instruction = 'Analyze this data.',
        [string]$Model = 'hawk-reasoning',
        [int]$TimeoutSec = 120,
        [int]$MaxRetries = 2,
        [switch]$RedactSensitive
    )

    begin {
        $dataBuffer = [System.Collections.Generic.List[object]]::new()
    }
    process {
        $dataBuffer.Add($InputData)
    }
    end {
        $stringifiedData = $dataBuffer | Out-String
        if ($RedactSensitive) {
            $stringifiedData = $stringifiedData | Protect-HawkSensitiveText | Out-String
        }

        try {
            $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5 -ErrorAction Stop
        }
        catch {
            Write-Host "`n  [Warning] AI Engine (Ollama) is not reachable on 127.0.0.1:11434. Start Ollama and try again." -ForegroundColor Red
            return
        }

        $payload = @{
            model  = $Model
            prompt = "Instruction: $Instruction`n`nData:`n$stringifiedData"
            stream = $true
        } | ConvertTo-Json -Depth 5

        $maxAttempts = 1 + [Math]::Max(0, $MaxRetries)
        $success = $false
        $lastError = $null

        for ($attempt = 1; $attempt -le $maxAttempts -and -not $success; $attempt++) {
            if ($attempt -gt 1) {
                Write-Host "  [Retry] $attempt / $maxAttempts..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }

            Write-Host "`n  [AI] [$($Model.ToUpper())] " -NoNewline -ForegroundColor Magenta

            $httpClient = [System.Net.Http.HttpClient]::new()
            $response = $null
            $stream = $null
            $reader = $null
            try {
                $httpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
                $body = [System.Net.Http.StringContent]::new($payload, [System.Text.Encoding]::UTF8, 'application/json')
                $response = $httpClient.PostAsync('http://127.0.0.1:11434/api/generate', $body).GetAwaiter().GetResult()
                $response.EnsureSuccessStatusCode() | Out-Null
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $reader = [System.IO.StreamReader]::new($stream)

                while (-not $reader.EndOfStream) {
                    $line = $reader.ReadLine()
                    if (-not $line) { continue }

                    try {
                        $chunk = $line | ConvertFrom-Json -ErrorAction Stop
                        if ($chunk.response) { Write-Host $chunk.response -NoNewline -ForegroundColor White }
                        if ($chunk.done) { break }
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
                Write-Warning "AI request failed: $($_.Exception.Message)"
            }
            finally {
                if ($reader) { $reader.Dispose() }
                if ($stream) { $stream.Dispose() }
                if ($response) { $response.Dispose() }
                $httpClient.Dispose()
            }
        }

        if (-not $success -and $lastError) {
            throw $lastError
        }
    }
}

function Get-HawkPortMap {
    [CmdletBinding()]
    param()

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

function Get-HawkAIStatus {
    [CmdletBinding()]
    param([string]$Endpoint = 'http://127.0.0.1:11434')

    try {
        $tags = Invoke-RestMethod -Uri "$Endpoint/api/tags" -TimeoutSec 5 -ErrorAction Stop
        foreach ($model in $tags.models) {
            [PSCustomObject]@{
                Endpoint = $Endpoint
                Status   = 'Reachable'
                Model    = $model.name
                SizeGB   = [Math]::Round($model.size / 1GB, 2)
                Modified = $model.modified_at
            }
        }
    }
    catch {
        [PSCustomObject]@{
            Endpoint = $Endpoint
            Status   = 'Unavailable'
            Model    = ''
            SizeGB   = ''
            Modified = $_.Exception.Message
        }
    }
}

function Get-HawkPathAudit {
    [CmdletBinding()]
    param([string]$PathValue = $env:Path)

    $segments = @($PathValue -split ';')
    $seen = @{}
    for ($i = 0; $i -lt $segments.Count; $i++) {
        $raw = $segments[$i]
        $path = $raw.Trim()
        if (-not $path) {
            [PSCustomObject]@{
                Index     = $i
                Path      = ''
                Status    = 'Empty'
                Duplicate = $false
            }
            continue
        }

        $key = $path.ToLowerInvariant()
        $duplicate = $seen.ContainsKey($key)
        $seen[$key] = $true

        [PSCustomObject]@{
            Index     = $i
            Path      = $path
            Status    = if (Test-Path $path) { 'OK' } else { 'Missing' }
            Duplicate = $duplicate
        }
    }
}

function Get-HawkNetworkTriage {
    [CmdletBinding()]
    param()

    Write-HawkHeader '  [Network] Listener/firewall triage' Cyan
    $filters = @(Get-HawkEnabledInboundTcpPortFilters)
    $filterUnavailable = $script:HawkLastFirewallFilterError
    Get-HawkTcpListeners |
    Sort-Object LocalPort |
    ForEach-Object {
        $port = [int]$_.LocalPort
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        $matched = $filters | Where-Object { Test-HawkPortSpecMatch -PortSpec $_.LocalPort -Port $port } | Select-Object -First 1
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

function Get-HawkProjectAudit {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $global:HawkProjectRoot,
        [int]$Depth = 1
    )

    if (-not (Test-Path $ProjectRoot)) {
        throw "Project root $ProjectRoot not found."
    }

    $dirs = Get-ChildItem -Path $ProjectRoot -Directory -Depth $Depth -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        if (-not (Test-Path (Join-Path $dir.FullName '.git'))) { continue }

        $branch = & git -C $dir.FullName branch --show-current 2>$null
        if (-not $branch) { $branch = & git -C $dir.FullName rev-parse --short HEAD 2>$null }
        $dirty = @(& git -C $dir.FullName status --short 2>$null)
        $lastCommit = & git -C $dir.FullName log -1 --format='%cr | %s' 2>$null

        [PSCustomObject]@{
            Project    = $dir.Name
            Path       = $dir.FullName
            Branch     = $branch
            DirtyFiles = $dirty.Count
            LastCommit = $lastCommit
        }
    }
}

function Format-HawkMarkdownCell {
    param(
        [AllowNull()][string]$Text,
        [int]$MaxWidth = 0
    )

    if ($null -eq $Text) { $Text = '' }

    $clean = ($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' '
    $clean = $clean.Trim().Replace('|', '\|')

    if ($MaxWidth -gt 0 -and $clean.Length -gt $MaxWidth) {
        if ($MaxWidth -eq 1) { return $clean.Substring(0, 1) }
        return $clean.Substring(0, $MaxWidth - 1) + '…'
    }

    return $clean
}

function ConvertTo-HawkMarkdownTable {
    param(
        [object[]]$InputObject,
        [string]$Section = ''
    )

    $rows = @($InputObject | Where-Object { $null -ne $_ })
    if (-not $rows -or $rows.Count -eq 0) {
        return '_No data._'
    }

    $props = @($rows[0].PSObject.Properties.Name)
    $maxWidths = @{
        Endpoint    = 32
        Model       = 64
        Modified    = 20
        ProcessName = 28
        Company     = 28
        Name        = 42
        Target      = 76
        Source      = 48
        TaskPath    = 34
        TaskName    = 52
        Path        = 72
        Args        = 72
        Status      = 56
        MatchedRule = 32
        LastCommit  = 56
    }

    if ($Section -eq 'Startup') {
        $maxWidths.Name = 38
        $maxWidths.Target = 72
        $maxWidths.Source = 44
    }
    elseif ($Section -eq 'ScheduledTaskRisks') {
        $maxWidths.TaskPath = 34
        $maxWidths.TaskName = 48
        $maxWidths.Path = 64
        $maxWidths.Args = 64
    }

    $formattedRows = foreach ($row in $rows) {
        $formatted = [ordered]@{}
        foreach ($prop in $props) {
            $value = $row.PSObject.Properties[$prop].Value
            $maxWidth = if ($maxWidths.ContainsKey($prop)) { [int]$maxWidths[$prop] } else { 0 }
            $formatted[$prop] = Format-HawkMarkdownCell -Text ([string]$value) -MaxWidth $maxWidth
        }
        [PSCustomObject]$formatted
    }

    $widths = [ordered]@{}
    foreach ($prop in $props) {
        $max = $prop.Length
        foreach ($row in $formattedRows) {
            $length = ([string]$row.PSObject.Properties[$prop].Value).Length
            if ($length -gt $max) { $max = $length }
        }
        $widths[$prop] = [Math]::Max(3, $max)
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $headers = foreach ($prop in $props) { $prop.PadRight($widths[$prop]) }
    $separators = foreach ($prop in $props) { '-' * $widths[$prop] }

    $lines.Add('| ' + ($headers -join ' | ') + ' |')
    $lines.Add('| ' + ($separators -join ' | ') + ' |')

    foreach ($row in $formattedRows) {
        $cells = foreach ($prop in $props) {
            ([string]$row.PSObject.Properties[$prop].Value).PadRight($widths[$prop])
        }
        $lines.Add('| ' + ($cells -join ' | ') + ' |')
    }

    return ($lines -join [Environment]::NewLine)
}

function ConvertTo-HawkReportMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        $Report
    )

    $sectionIcons = @{
        AI                 = '◉'
        Disk               = '▰'
        Resources          = '▤'
        Ports              = '◦'
        FirewallGaps       = '▣'
        Startup            = '⌂'
        ScheduledTaskRisks = '⌁'
        EventStorms        = '↯'
    }

    $aiModels = @($Report.AI | Where-Object Status -eq 'Reachable')
    $diskCount = @($Report.Disk).Count
    $lowestDisk = @($Report.Disk | Sort-Object FreePercent | Select-Object -First 1)
    $portCount = @($Report.Ports).Count
    $firewallGapCount = @($Report.FirewallGaps).Count
    $startupCount = @($Report.Startup).Count
    $taskRiskCount = @($Report.ScheduledTaskRisks).Count
    $eventStormCount = @($Report.EventStorms).Count

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Hawkward Hybrid Report')
    $lines.Add('')
    $lines.Add("Generated: $($Report.Generated)")
    $lines.Add('')
    $lines.Add('## ▣ Summary')
    $lines.Add('')
    $lines.Add('| Signal | Value |')
    $lines.Add('| --- | --- |')
    $lines.Add("| ◉ AI | $($aiModels.Count) reachable model(s) |")
    if ($lowestDisk) {
        $lines.Add("| ▰ Disk | $diskCount drive(s), lowest free: $($lowestDisk.DeviceID) $($lowestDisk.FreePercent)% |")
    }
    else {
        $lines.Add('| ▰ Disk | No disk data |')
    }
    $lines.Add("| ◦ Ports | $portCount listener row(s) |")
    $lines.Add("| ▣ Firewall gaps | $firewallGapCount item(s) |")
    $lines.Add("| ⌂ Startup | $startupCount entry/entries |")
    $lines.Add("| ⌁ Scheduled risks | $taskRiskCount item(s) |")
    $lines.Add("| ↯ Event storms | $eventStormCount item(s) |")

    foreach ($section in @('AI', 'Disk', 'Resources', 'Ports', 'FirewallGaps', 'Startup', 'ScheduledTaskRisks', 'EventStorms')) {
        $lines.Add('')
        $lines.Add("## $($sectionIcons[$section]) $section")
        $lines.Add('')
        $lines.Add((ConvertTo-HawkMarkdownTable -InputObject $Report[$section] -Section $section))
    }

    return ($lines -join [Environment]::NewLine)
}

function New-HawkReportPath {
    param(
        [ValidateSet('md', 'json')]
        [string]$Extension = 'md'
    )

    if (-not (Test-Path $script:HawkReportRoot)) {
        $null = New-Item -Path $script:HawkReportRoot -ItemType Directory -Force
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Join-Path $script:HawkReportRoot "hawkreport-$stamp.$Extension"
}

function Format-HawkReportCell {
    param(
        [AllowNull()][string]$Text,
        [int]$Width
    )

    if ($Width -le 0) { return '' }
    if ($null -eq $Text) { $Text = '' }

    $clean = ($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' '
    $clean = $clean.Trim()
    if ($clean.Length -gt $Width) {
        if ($Width -eq 1) { return $clean.Substring(0, 1) }
        return $clean.Substring(0, $Width - 1) + '…'
    }

    return $clean.PadRight($Width)
}

function Write-HawkReportTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][hashtable[]]$Columns,
        [object[]]$InputObject = @(),
        [string]$Icon = '•',
        [ConsoleColor]$Color = 'Cyan',
        [ConsoleColor]$RowColor = 'White',
        [int]$MaxRows = 0
    )

    $rows = @($InputObject | Where-Object { $null -ne $_ })
    $visibleRows = if ($MaxRows -gt 0) { @($rows | Select-Object -First $MaxRows) } else { $rows }
    $tableWidth = (($Columns | ForEach-Object { [int]$_.Width } | Measure-Object -Sum).Sum + (($Columns.Count - 1) * 2))

    Write-Host ''
    Write-Host "  $Icon $Title" -ForegroundColor $Color
    Write-Host "  $('─' * [Math]::Max(1, $tableWidth))" -ForegroundColor DarkGray

    if (-not $rows -or $rows.Count -eq 0) {
        Write-Host '  ✓ No data.' -ForegroundColor Green
        return
    }

    $header = foreach ($column in $Columns) {
        $label = if ($column.Label) { [string]$column.Label } else { [string]$column.Name }
        Format-HawkReportCell -Text $label -Width ([int]$column.Width)
    }
    Write-Host ('  ' + ($header -join '  ')) -ForegroundColor DarkGray

    foreach ($row in $visibleRows) {
        $cells = foreach ($column in $Columns) {
            $value = if ($column.Expression) {
                & $column.Expression $row
            }
            else {
                $prop = $row.PSObject.Properties[[string]$column.Name]
                if ($prop) { $prop.Value } else { '' }
            }

            Format-HawkReportCell -Text ([string]$value) -Width ([int]$column.Width)
        }

        Write-Host ('  ' + ($cells -join '  ')) -ForegroundColor $RowColor
    }

    if ($MaxRows -gt 0 -and $rows.Count -gt $MaxRows) {
        Write-Host "  … $($rows.Count - $MaxRows) more row(s) in the saved Markdown report." -ForegroundColor DarkGray
    }
}

function Write-HawkReportConsole {
    param(
        [Parameter(Mandatory = $true)]
        $Report,
        [string]$SavedPath
    )

    $aiModels = @($Report.AI | Where-Object Status -eq 'Reachable')
    $lowestDisk = @($Report.Disk | Sort-Object FreePercent | Select-Object -First 1)
    $summary = @(
        [PSCustomObject]@{ Signal = 'AI'; Value = "$($aiModels.Count) reachable model(s)" }
        [PSCustomObject]@{ Signal = 'Disk'; Value = if ($lowestDisk) { "$(@($Report.Disk).Count) drive(s), lowest free: $($lowestDisk.DeviceID) $($lowestDisk.FreePercent)%" } else { 'No disk data' } }
        [PSCustomObject]@{ Signal = 'Ports'; Value = "$(@($Report.Ports).Count) listener row(s)" }
        [PSCustomObject]@{ Signal = 'Firewall gaps'; Value = "$(@($Report.FirewallGaps).Count) item(s)" }
        [PSCustomObject]@{ Signal = 'Startup'; Value = "$(@($Report.Startup).Count) entry/entries" }
        [PSCustomObject]@{ Signal = 'Task risks'; Value = "$(@($Report.ScheduledTaskRisks).Count) item(s)" }
        [PSCustomObject]@{ Signal = 'Event storms'; Value = "$(@($Report.EventStorms).Count) item(s)" }
    )

    Write-Host ''
    Write-Host '  ▣ HAWKWARD HYBRID REPORT' -ForegroundColor Cyan
    Write-Host "  Generated  $($Report.Generated)" -ForegroundColor DarkGray
    if ($SavedPath) {
        Write-Host "  Saved      $SavedPath" -ForegroundColor DarkGray
    }

    Write-HawkReportTable -Title 'Summary' -Icon '▣' -Color Cyan -InputObject $summary -Columns @(
        @{ Name = 'Signal'; Width = 16 }
        @{ Name = 'Value'; Width = 64 }
    )

    Write-HawkReportTable -Title 'AI Models' -Icon '◉' -Color Magenta -InputObject $Report.AI -Columns @(
        @{ Name = 'Status'; Width = 10 }
        @{ Name = 'Model'; Width = 46 }
        @{ Name = 'SizeGB'; Label = 'GB'; Width = 8 }
        @{ Name = 'Modified'; Width = 20 }
    )

    Write-HawkReportTable -Title 'Disk' -Icon '▰' -Color Yellow -InputObject $Report.Disk -Columns @(
        @{ Name = 'DeviceID'; Label = 'Drive'; Width = 8 }
        @{ Name = 'SizeGB'; Label = 'Size GB'; Width = 9 }
        @{ Name = 'FreeGB'; Label = 'Free GB'; Width = 9 }
        @{ Name = 'FreePercent'; Label = 'Free %'; Width = 8 }
        @{ Name = 'Source'; Width = 8 }
    )

    Write-HawkReportTable -Title 'Resources' -Icon '▤' -Color Red -InputObject $Report.Resources -MaxRows 12 -Columns @(
        @{ Name = 'ProcessName'; Label = 'Process'; Width = 24 }
        @{ Name = 'Id'; Label = 'PID'; Width = 8 }
        @{ Name = 'RAMMB'; Label = 'RAM MB'; Width = 8 }
        @{ Name = 'CPUSec'; Label = 'CPU s'; Width = 8 }
        @{ Name = 'Company'; Width = 26 }
    )

    Write-HawkReportTable -Title 'Ports' -Icon '◦' -Color Cyan -InputObject $Report.Ports -MaxRows 30 -Columns @(
        @{ Name = 'Port'; Width = 7 }
        @{ Name = 'PID'; Width = 8 }
        @{ Name = 'Process'; Width = 30 }
        @{ Name = 'Company'; Width = 26 }
    )

    Write-HawkReportTable -Title 'Firewall Gaps' -Icon '▣' -Color DarkYellow -InputObject $Report.FirewallGaps -Columns @(
        @{ Name = 'Port'; Width = 7 }
        @{ Name = 'PID'; Width = 8 }
        @{ Name = 'Process'; Width = 24 }
        @{ Name = 'Status'; Width = 44 }
    )

    Write-HawkReportTable -Title 'Startup' -Icon '⌂' -Color Green -InputObject $Report.Startup -MaxRows 20 -Columns @(
        @{ Name = 'Hive'; Width = 6 }
        @{ Name = 'Name'; Width = 30 }
        @{ Name = 'Target'; Width = 64 }
    )

    Write-HawkReportTable -Title 'Scheduled Task Risks' -Icon '⌁' -Color DarkYellow -InputObject $Report.ScheduledTaskRisks -MaxRows 16 -Columns @(
        @{ Name = 'TaskPath'; Width = 28 }
        @{ Name = 'TaskName'; Width = 36 }
        @{ Name = 'Path'; Width = 46 }
    )

    Write-HawkReportTable -Title 'Event Storms' -Icon '↯' -Color Red -InputObject $Report.EventStorms -Columns @(
        @{ Name = 'Count'; Width = 8 }
        @{ Name = 'Name'; Label = 'Event ID'; Width = 12 }
        @{ Name = 'Source'; Width = 44 }
    )
}

function New-HawkReport {
    [CmdletBinding()]
    param(
        [ValidateSet('Console', 'Markdown', 'Json')]
        [string]$Format = 'Console',
        [string]$Path
    )

    $previous = $script:HawkSuppressHeaders
    $script:HawkSuppressHeaders = $true
    try {
        $report = [ordered]@{
            Generated          = Get-Date
            AI                 = @(Get-HawkAIStatus)
            Disk               = @(Get-HawkDiskPressureAudit)
            Resources          = @(Get-HawkResourceMap)
            Ports              = @(Get-HawkPortMap)
            FirewallGaps       = @(Get-HawkFirewallAudit)
            Startup            = @(Get-HawkBootMap)
            ScheduledTaskRisks = @(Get-HawkScheduledTaskRiskAudit)
            EventStorms        = @(Get-HawkEventStormAudit)
        }
    }
    finally {
        $script:HawkSuppressHeaders = $previous
    }

    $markdownOutput = ConvertTo-HawkReportMarkdown -Report $report

    if ($Format -eq 'Console') {
        $markdownPath = if ($Path) { $Path } else { New-HawkReportPath -Extension md }
        $parentPath = Split-Path $markdownPath -Parent
        if ($parentPath -and -not (Test-Path $parentPath)) {
            $null = New-Item -Path $parentPath -ItemType Directory -Force
        }

        Set-Content -Path $markdownPath -Value $markdownOutput -Encoding UTF8
        Write-HawkReportConsole -Report $report -SavedPath $markdownPath
        return
    }

    $output = if ($Format -eq 'Json') {
        $report | ConvertTo-Json -Depth 8
    }
    else {
        $markdownOutput
    }

    if ($Path) {
        $parentPath = Split-Path $Path -Parent
        if ($parentPath -and -not (Test-Path $parentPath)) {
            $null = New-Item -Path $parentPath -ItemType Directory -Force
        }

        Set-Content -Path $Path -Value $output -Encoding UTF8
    }

    $output
}

function Show-HawkManual {
    Write-Host "`nHAWKWARD HYBRID - QUICK MANUAL`n" -ForegroundColor Cyan
    Write-Host 'WORKFLOW:' -ForegroundColor Yellow
    Write-Host ' 1. hawkdoctor  > profile/module/AI health'
    Write-Host ' 2. resmap      > system load'
    Write-Host ' 3. diskaudit   > disk health'
    Write-Host ' 4. evntmap     > recent errors'
    Write-Host ' 5. evntaudit   > error patterns'
    Write-Host ' 6. nettriage   > ports + process + firewall rule'
    Write-Host ' 7. fwaudit     > firewall gaps'
    Write-Host ' 8. susaudit    > suspicious processes'
    Write-Host ' 9. ghostaudit  > orphaned ports'
    Write-Host '10. taskaudit   > scheduled risks'
    Write-Host '11. bootmap     > startup persistence'
    Write-Host '12. hawkreport  > console report + saved Markdown'
    Write-Host "`nTIP: Pipe sensitive output through secretredact before AI: envmap -IncludeSensitive | secretredact | ai"
}

function Resolve-HawkDuckDuckGoHref {
    param([string]$Href)

    if (-not $Href) { return $null }
    if ($Href -match 'uddg=([^&]+)') { return [Uri]::UnescapeDataString($matches[1]) }
    if ($Href -match '^//') { return "https:$Href" }
    if ($Href -match '^https?://') { return $Href }
    return $null
}

function Invoke-HawkSearch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Query,
        [ValidateSet('google', 'ddg', 'gh', 'so', 'bing')]
        [Alias('e')]
        [string]$Engine = 'google',
        [Alias('a')]
        [switch]$AI,
        [string]$Instruction = 'Synthesize a concise report answering the query based on the following website contents. Extract key facts and insights.'
    )

    $cleanQuery = $Query | Where-Object { $_ -notmatch '^-AI$|^-a$|^-Engine$|^-e$' -and $_ -notin @('google', 'ddg', 'gh', 'so', 'bing') }
    $joinedQuery = ($cleanQuery -join ' ').Trim()
    if (-not $joinedQuery) {
        throw 'Search query cannot be empty.'
    }

    $encoded = [Uri]::EscapeDataString($joinedQuery)
    $browserUrls = @{
        google = "https://www.google.com/search?q=$encoded"
        ddg    = "https://duckduckgo.com/?q=$encoded"
        gh     = "https://github.com/search?q=$encoded&type=repositories"
        so     = "https://stackoverflow.com/search?q=$encoded"
        bing   = "https://www.bing.com/search?q=$encoded"
    }

    if (-not $AI) {
        Write-Host "  [Search] Opened [$Engine] -> $joinedQuery" -ForegroundColor Cyan
        Start-Process $browserUrls[$Engine]
        return
    }

    Write-Host "  [Search] Fetching top links for: $joinedQuery" -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri 'https://lite.duckduckgo.com/lite/' -Method Post -Body @{ q = $joinedQuery } -UseBasicParsing -ErrorAction Stop

        $urls = $response.Links |
        Where-Object { ($_.outerHTML -match "class='result-link'" -or $_.class -eq 'result-link') } |
        ForEach-Object { Resolve-HawkDuckDuckGoHref -Href $_.href } |
        Where-Object { $_ -and $_ -notmatch '^https?://(?:www\.)?duckduckgo\.com' } |
        Select-Object -Unique |
        Select-Object -First 30

        if (-not $urls) {
            Write-Warning 'Could not find any URLs. Opening browser instead.'
            Start-Process $browserUrls[$Engine]
            return
        }

        $context = "Search Query: $joinedQuery`n`n"
        $readCount = 0
        $targetReadCount = 10

        foreach ($url in $urls) {
            if ($readCount -ge $targetReadCount) { break }

            Write-Host "  [Read] $url" -ForegroundColor DarkGray
            try {
                $page = Invoke-WebRequest -Uri $url -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
                $cleanText = [System.Net.WebUtility]::HtmlDecode(($page.Content -replace '(?s)<style[^>]*>.*?</style>', '' -replace '(?s)<script[^>]*>.*?</script>', '' -replace '<[^>]+>', ' ').Trim())
                $cleanText = $cleanText -replace '\s+', ' '
                if ([string]::IsNullOrWhiteSpace($cleanText)) {
                    throw 'No readable text extracted from the page.'
                }

                if ($cleanText.Length -gt 3000) { $cleanText = $cleanText.Substring(0, 3000) }
                $context += "Source: $url`nContent: $cleanText`n`n"
                $readCount++
            }
            catch {
                $reason = $_.Exception.Message
                $statusCode = $null
                if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }

                $detail = if ($statusCode) { "HTTP $statusCode - $reason" } else { $reason }
                Write-Host "  [Warning] Failed to read $url ($detail)" -ForegroundColor DarkYellow
            }
        }

        if ($readCount -eq 0) {
            Write-Warning 'Could not read any result pages. Opening browser instead.'
            Start-Process $browserUrls[$Engine]
            return
        }

        if ($readCount -lt $targetReadCount) {
            Write-Host "  [Warning] Read $readCount of $targetReadCount target sources; candidate list exhausted." -ForegroundColor DarkYellow
        }

        Write-Host '  [AI] Analyzing results...' -ForegroundColor Magenta
        try {
            $context | Invoke-HawkAI -Instruction $Instruction
        }
        catch {
            Write-Warning "AI analysis failed: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Warning "Search request failed: $($_.Exception.Message). Opening browser."
        Start-Process $browserUrls[$Engine]
    }
}

function Get-HawkDoctor {
    [CmdletBinding()]
    param(
        [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
        [string]$ProjectRoot = $global:HawkProjectRoot
    )

    $profileExists = Test-Path $ProfilePath
    $parseErrors = @()
    if ($profileExists) {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ProfilePath), [ref]$tokens, [ref]$errors)
        $parseErrors = @($errors)
    }

    [PSCustomObject]@{
        Check   = 'Profile'
        Status  = if ($profileExists -and $parseErrors.Count -eq 0) { 'OK' } elseif ($profileExists) { 'ParserErrors' } else { 'Missing' }
        Details = if ($parseErrors) { ($parseErrors.Message -join '; ') } else { $ProfilePath }
    }

    foreach ($module in $script:HawkRequiredModules) {
        $available = Get-Module -ListAvailable -Name $module
        [PSCustomObject]@{
            Check   = "Module:$module"
            Status  = if ($available) { 'Available' } else { 'Missing' }
            Details = if ($available) { ($available | Select-Object -First 1).ModuleBase } else { 'Run Install-HawkPrerequisites' }
        }
    }

    [PSCustomObject]@{
        Check   = 'ProjectRoot'
        Status  = if ($ProjectRoot -and (Test-Path $ProjectRoot)) { 'OK' } else { 'Missing' }
        Details = $ProjectRoot
    }

    $ai = @(Get-HawkAIStatus | Select-Object -First 1)
    [PSCustomObject]@{
        Check   = 'Ollama'
        Status  = if ($ai.Status -eq 'Reachable') { 'OK' } else { 'Unavailable' }
        Details = if ($ai.Status -eq 'Reachable') { 'Models available' } else { $ai.Modified }
    }

    $terminalIconsPrefs = Join-Path $env:APPDATA 'powershell\Community\Terminal-Icons'
    [PSCustomObject]@{
        Check   = 'TerminalIconsPrefs'
        Status  = if (Test-Path $terminalIconsPrefs) { 'Present' } else { 'Missing' }
        Details = $terminalIconsPrefs
    }
}

function Show-HawkDashboard {
    $aiStatus = try {
        $null = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 -ErrorAction Stop
        'ACTIVE'
    }
    catch {
        'STANDBY'
    }

    $projectRoot = if ($global:HawkProjectRoot) { $global:HawkProjectRoot } else { $script:HawkDefaultProjectRoot }

    $fitText = {
        param(
            [AllowNull()][string]$Text,
            [int]$Width
        )

        if ($Width -le 0) { return '' }
        if ($null -eq $Text) { $Text = '' }
        if ($Text.Length -gt $Width) {
            if ($Width -eq 1) { return $Text.Substring(0, 1) }
            return $Text.Substring(0, $Width - 1) + '…'
        }

        return $Text.PadRight($Width)
    }

    $consoleWidth = try { [Console]::WindowWidth } catch { 120 }
    if ($consoleWidth -lt 1) { $consoleWidth = 120 }

    $dashboardWidth = [Math]::Max(78, [Math]::Min(($consoleWidth - 4), 150))
    $boxTextWidth = $dashboardWidth - 2
    $gap = '  '
    $columnCount = if ($dashboardWidth -ge 116) { 4 } elseif ($dashboardWidth -ge 76) { 2 } else { 1 }
    $columnWidth = [int][Math]::Floor(($dashboardWidth - (($columnCount - 1) * $gap.Length)) / $columnCount)
    $rule = '─' * $dashboardWidth

    Write-Host "`n  ╭$rule╮" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fitText "🦅 HAWKWARD HYBRID $script:HawkVersion · SENTINEL EDITION" $boxTextWidth) -ForegroundColor Cyan -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ├$rule┤" -ForegroundColor DarkGray
    Write-Host '  │ ' -NoNewline -ForegroundColor DarkGray
    Write-Host (& $fitText "AI Engine : $aiStatus    Workspace : $projectRoot" $boxTextWidth) -ForegroundColor DarkGray -NoNewline
    Write-Host ' │' -ForegroundColor DarkGray
    Write-Host "  ╰$rule╯`n" -ForegroundColor DarkGray

    $suites = @(
        @{
            Title = '🛡️ SENTINEL'
            Desc  = 'Security & Audits'
            Items = @(
                @{ Icon = '◌'; Alias = 'ghostaudit'; Desc = 'Ports' }
                @{ Icon = '▲'; Alias = 'susaudit'; Desc = 'AppData' }
                @{ Icon = '▣'; Alias = 'fwaudit'; Desc = 'Firewall' }
                @{ Icon = '⌁'; Alias = 'taskaudit'; Desc = 'Tasks' }
                @{ Icon = '◆'; Alias = 'secretredact'; Desc = 'Secrets' }
            )
        }
        @{
            Title = '🩺 DIAGNOSTICS'
            Desc  = 'System & Health'
            Items = @(
                @{ Icon = '✚'; Alias = 'hawkdoctor'; Desc = 'Health' }
                @{ Icon = '◉'; Alias = 'aidoctor'; Desc = 'Ollama' }
                @{ Icon = '◷'; Alias = 'evntmap'; Desc = 'Events' }
                @{ Icon = '↯'; Alias = 'evntaudit'; Desc = 'Storms' }
                @{ Icon = '▰'; Alias = 'diskaudit'; Desc = 'Disk' }
                @{ Icon = '▤'; Alias = 'resmap'; Desc = 'CPU/RAM' }
            )
        }
        @{
            Title = '⚙️ ENVIRONMENT'
            Desc  = 'State & Config'
            Items = @(
                @{ Icon = '□'; Alias = 'fwmap'; Desc = 'Rules' }
                @{ Icon = '≡'; Alias = 'envmap'; Desc = 'Env vars' }
                @{ Icon = '⌘'; Alias = 'pathaudit'; Desc = 'PATH audit' }
                @{ Icon = '◦'; Alias = 'portmap'; Desc = 'Listeners' }
                @{ Icon = '⇄'; Alias = 'nettriage'; Desc = 'Network' }
                @{ Icon = '⌂'; Alias = 'bootmap'; Desc = 'Startup' }
            )
        }
        @{
            Title = '🤖 AI & WORKSPACE'
            Desc  = 'Core Tools'
            Items = @(
                @{ Icon = '⌕'; Alias = 'ggl'; Desc = 'Search + AI' }
                @{ Icon = 'λ'; Alias = 'ai'; Desc = 'Analyze' }
                @{ Icon = '⑂'; Alias = 'projaudit'; Desc = 'Repos' }
                @{ Icon = '▧'; Alias = 'hawkreport'; Desc = 'Report + MD' }
                @{ Icon = '↗'; Alias = 'proj'; Desc = 'Root' }
                @{ Icon = '▦'; Alias = 'dash'; Desc = 'Dashboard' }
                @{ Icon = '↻'; Alias = 'reload'; Desc = 'Profile' }
                @{ Icon = '?'; Alias = 'hawkman'; Desc = 'Guide' }
            )
        }
    )

    for ($suiteIndex = 0; $suiteIndex -lt $suites.Count; $suiteIndex += $columnCount) {
        $lastSuiteIndex = [Math]::Min($suiteIndex + $columnCount - 1, $suites.Count - 1)
        $suiteGroup = @($suites[$suiteIndex..$lastSuiteIndex])
        $maxItems = @($suiteGroup | ForEach-Object { $_.Items.Count } | Measure-Object -Maximum).Maximum

        $titleLine = @(
            foreach ($suite in $suiteGroup) {
                & $fitText $suite.Title $columnWidth
            }
        )
        Write-Host ("  " + ($titleLine -join $gap)) -ForegroundColor Cyan

        $descLine = @(
            foreach ($suite in $suiteGroup) {
                & $fitText $suite.Desc $columnWidth
            }
        )
        Write-Host ("  " + ($descLine -join $gap)) -ForegroundColor DarkGray

        $sectionRule = @(
            foreach ($suite in $suiteGroup) {
                '─' * $columnWidth
            }
        )
        Write-Host ("  " + ($sectionRule -join $gap)) -ForegroundColor DarkGray

        for ($itemIndex = 0; $itemIndex -lt $maxItems; $itemIndex++) {
            $itemLine = @(
                foreach ($suite in $suiteGroup) {
                    if ($itemIndex -lt $suite.Items.Count) {
                        $item = $suite.Items[$itemIndex]
                        $command = "$($item.Icon) $($item.Alias.PadRight(12)) $($item.Desc)"
                        & $fitText $command $columnWidth
                    }
                    else {
                        ' ' * $columnWidth
                    }
                }
            )
            Write-Host ("  " + ($itemLine -join $gap)) -ForegroundColor White
        }

        Write-Host ''
    }
}

function Update-HawkProfile {
    . $PROFILE
}

function Set-HawkAliases {
    Set-Alias -Scope Global -Name ai           -Value Invoke-HawkAI -Force
    Set-Alias -Scope Global -Name proj         -Value Invoke-HawkProject -Force
    Set-Alias -Scope Global -Name reload       -Value Update-HawkProfile -Force
    Set-Alias -Scope Global -Name dash         -Value Show-HawkDashboard -Force
    Set-Alias -Scope Global -Name ghostaudit   -Value Get-HawkGhostPortAudit -Force
    Set-Alias -Scope Global -Name fwaudit      -Value Get-HawkFirewallAudit -Force
    Set-Alias -Scope Global -Name susaudit     -Value Get-HawkSuspiciousProcessAudit -Force
    Set-Alias -Scope Global -Name diskaudit    -Value Get-HawkDiskPressureAudit -Force
    Set-Alias -Scope Global -Name taskaudit    -Value Get-HawkScheduledTaskRiskAudit -Force
    Set-Alias -Scope Global -Name evntaudit    -Value Get-HawkEventStormAudit -Force
    Set-Alias -Scope Global -Name evntmap      -Value Get-HawkEventMap -Force
    Set-Alias -Scope Global -Name fwmap        -Value Get-HawkFirewallMap -Force
    Set-Alias -Scope Global -Name envmap       -Value Get-HawkEnvMap -Force
    Set-Alias -Scope Global -Name pathaudit    -Value Get-HawkPathAudit -Force
    Set-Alias -Scope Global -Name portmap      -Value Get-HawkPortMap -Force
    Set-Alias -Scope Global -Name nettriage    -Value Get-HawkNetworkTriage -Force
    Set-Alias -Scope Global -Name resmap       -Value Get-HawkResourceMap -Force
    Set-Alias -Scope Global -Name bootmap      -Value Get-HawkBootMap -Force
    Set-Alias -Scope Global -Name hawkman      -Value Show-HawkManual -Force
    Set-Alias -Scope Global -Name ggl          -Value Invoke-HawkSearch -Force
    Set-Alias -Scope Global -Name hawkdoctor   -Value Get-HawkDoctor -Force
    Set-Alias -Scope Global -Name aidoctor     -Value Get-HawkAIStatus -Force
    Set-Alias -Scope Global -Name secretredact -Value Protect-HawkSensitiveText -Force
    Set-Alias -Scope Global -Name projaudit    -Value Get-HawkProjectAudit -Force
    Set-Alias -Scope Global -Name hawkreport   -Value New-HawkReport -Force
}

function Initialize-HawkProfile {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $script:HawkDefaultProjectRoot,
        [switch]$ShowDashboard,
        [switch]$SkipModules
    )

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $global:HawkProjectRoot = $ProjectRoot

    if (-not $SkipModules) {
        Import-HawkPrerequisites -Quiet | Out-Null
    }

    Set-HawkReadLine
    Set-HawkAliases
    Set-HawkPrompt

    if ($ShowDashboard -and (Test-HawkInteractiveSession)) {
        Show-HawkDashboard
    }
}

Export-ModuleMember -Function * -Alias *
