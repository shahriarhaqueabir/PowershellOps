# PowershellOps Hawk profile - module-backed local ops toolkit.

$script:HawkVersion = '12.0'
$script:HawkDefaultProjectRoot = Join-Path $env:USERPROFILE 'Projects'
$script:HawkRequiredModules = @('Terminal-Icons', 'PSReadLine', 'PSTree', 'ZLocation')
$script:HawkSuppressHeaders = $false
$script:HawkSensitiveNamePattern = '(?i)(secret|token|password|passwd|pwd|credential|connection.?string|sas|bearer|api.?key|private.?key)'
$script:HawkLastFirewallFilterError = $null
$script:HawkReportRoot = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Reports'
$script:HawkLlamaModelPath = $null
$script:HawkLlamaPort = 8081
$script:HawkLlamaEndpoint = "http://127.0.0.1:$($script:HawkLlamaPort)"
$script:HawkDefaultHfHome = Join-Path $env:USERPROFILE 'Models\GGUF'
$script:HawkConfigPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\hawk.config.json'
$script:HawkModelRepo = 'unsloth/Qwen3-1.7B-GGUF'
$script:HawkModelFile = 'Qwen3-1.7B-Q4_K_M.gguf'
$script:HawkSettingsPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\hawk-settings.json'

function Resolve-HawkMigratedPath {
    <#
    .SYNOPSIS
    One-time migration: if Path is missing but a legacy-named sibling exists,
    rename the legacy file to the new name and return Path.
    #>
    param([string]$Path, [string]$LegacyName)
    if (-not (Test-Path -LiteralPath $Path)) {
        $legacy = Join-Path (Split-Path -Parent $Path) $LegacyName
        if (Test-Path -LiteralPath $legacy) {
            Move-Item -LiteralPath $legacy -Destination $Path -Force
            Write-Verbose "Migrated legacy '$LegacyName' -> '$(Split-Path -Leaf $Path)'"
        }
    }
    return $Path
}$script:HawkOpsMemoryRoot = $null

function Get-HawkConfig {
    <#
    .SYNOPSIS
    Reads the Hawkward machine config file (hawk.config.json).
    .DESCRIPTION
    Returns a PSCustomObject with ProjectRoot, HfHome, LlamaPort, and ModelPath,
    falling back to built-in defaults when the file is missing or malformed. Honors
    $env:HAWK_CONFIG_PATH for installer staging mode.
    #>
    $configPath = if ($env:HAWK_CONFIG_PATH) { $env:HAWK_CONFIG_PATH } else { $script:HawkConfigPath }
    $cfg = [pscustomobject]@{
        ProjectRoot = $script:HawkDefaultProjectRoot
        HfHome      = $script:HawkDefaultHfHome
        LlamaPort   = $script:HawkLlamaPort
        ModelPath   = $null
        NerdFont    = $null   # $null = auto-detect; true/false forces on/off
    }
    if (Test-Path -LiteralPath $configPath) {
        try {
            $raw = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($raw.projectRoot) { $cfg.ProjectRoot = [string]$raw.projectRoot }
            if ($raw.hfHome) { $cfg.HfHome = [string]$raw.hfHome }
            if ($raw.llamaPort) { $cfg.LlamaPort = [int]$raw.llamaPort }
            if ($raw.modelPath) { $cfg.ModelPath = [string]$raw.modelPath }
            if ($null -ne $raw.nerdFont) { $cfg.NerdFont = $raw.nerdFont }
        } catch {
            Write-Warning "Hawk config at '$configPath' could not be read ($($_.Exception.Message)); using defaults."
        }
    }
    if (-not $cfg.ModelPath) {
        $snapshots = Join-Path $cfg.HfHome "hub\models--$($script:HawkModelRepo -replace '/', '--')\snapshots"
        if (Test-Path -LiteralPath $snapshots) {
            $gguf = Get-ChildItem -LiteralPath $snapshots -Recurse -Filter $script:HawkModelFile -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gguf) { $cfg.ModelPath = $gguf.FullName }
        }
    }
    return $cfg
}

# --- Machine config override (hawk.config.json) ---
$script:HawkConfig = Get-HawkConfig
$script:HawkDefaultProjectRoot = $script:HawkConfig.ProjectRoot
if ($script:HawkConfig.ModelPath) { $script:HawkLlamaModelPath = $script:HawkConfig.ModelPath }
$script:HawkLlamaPort = $script:HawkConfig.LlamaPort

# --- Nerd Font support (dashboard glyphs) ---
# Resolution order: $env:HAWK_NERDFONT ('1'/'true'/'0'/'false'/'auto')
#   > hawk.config.json "nerdFont": true|false|"auto"  > auto-detect.
# Auto-detect scans installed fonts for "*Nerd Font*" (HKLM + HKCU). Note this
# proves the font is INSTALLED, not that the terminal selected it — use the
# override when auto-detect guesses wrong. Result is cached per session;
# pass -Refresh to re-scan.
function Test-HawkNerdFont {
    [CmdletBinding()]
    param([switch]$Refresh)

    if (-not $Refresh -and $null -ne $script:HawkNerdFontDetected) {
        return $script:HawkNerdFontDetected
    }

    $override = $env:HAWK_NERDFONT
    if (-not $override -and $null -ne $script:HawkConfig.NerdFont) {
        $override = "$($script:HawkConfig.NerdFont)".ToLowerInvariant()
    }
    switch ($override) {
        { $_ -in '1', 'true', 'yes', 'on' } {
            $script:HawkNerdFontDetected = $true; return $true
        }
        { $_ -in '0', 'false', 'no', 'off' } {
            $script:HawkNerdFontDetected = $false; return $false
        }
    }

    $found = $false
    foreach ($root in @(
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    )) {
        try {
            $props = Get-ItemProperty -LiteralPath $root -ErrorAction Stop
            # Matches long ('Nerd Font ...') and winget short ('JetBrainsMono NF ...') naming.
            if ($props.PSObject.Properties.Name -match 'Nerd ?Font|\bNF\b') { $found = $true; break }
        } catch { }
    }

    $script:HawkNerdFontDetected = $found
    return $found
}

# Nerd Font glyphs for dashboard tiles, keyed by command alias. All codepoints
# are BMP private-use-area (single UTF-16 unit). Unicode fallbacks live in the
# Show-HawkDashboard suite table and are used whenever NF is off or unmapped.
$script:HawkNerdGlyphs = @{
    'ghostaudit'    = "`u{F186}"   # ghost
    'susaudit'      = "`u{F188}"   # bug
    'fwaudit'       = "`u{F134}"   # fire-extinguisher
    'taskaudit'     = "`u{F274}"   # calendar-check-o
    'secretredact'  = "`u{F084}"   # key
    'defendermap'   = "`u{F132}"   # shield
    'regaudit'      = "`u{F1C0}"   # database
    'ifeoaudit'     = "`u{F05B}"   # crosshairs
    'regsnap'       = "`u{F030}"   # camera
    'sysview'       = "`u{F0E4}"   # tachometer
    'hawkdoctor'    = "`u{F21E}"   # heartbeat
    'hawkcheck'     = "`u{F058}"   # check-circle
    'evntmap'       = "`u{F073}"   # calendar
    'evntaudit'     = "`u{F0E7}"   # bolt
    'diskaudit'     = "`u{F0A0}"   # hdd-o
    'resmap'        = "`u{F2DB}"   # microchip
    'fwmap'         = "`u{F0E3}"   # gavel
    'envmap'        = "`u{F120}"   # terminal
    'pathaudit'     = "`u{F277}"   # map-signs
    'portmap'       = "`u{F1E6}"   # plug
    'nettriage'     = "`u{F6FF}"   # network-wired
    'bootmap'       = "`u{F135}"   # rocket
    'ggl'           = "`u{F002}"   # search
    'ai'            = "`u{F0D0}"   # magic
    'llamastart'    = "`u{F04B}"   # play
    'llamastop'     = "`u{F04D}"   # stop
    'aidoctor'      = "`u{F233}"   # server
    'llamadoctor'   = "`u{F0FA}"   # medkit
    'hawkchat'      = "`u{F086}"   # comments
    'hawkmodel'     = "`u{F1B3}"   # cubes
    'hawkdaily'     = "`u{F185}"   # sun-o
    'hawkwatch'     = "`u{F06E}"   # eye
    'projaudit'     = "`u{F408}"   # octicon repo
    'hawkreport'    = "`u{F0F6}"   # file-text-o
    'proj'          = "`u{F115}"   # folder-open-o
    'dash'          = "`u{F009}"   # th-large
    'reload'        = "`u{F021}"   # refresh
    'hawkman'       = "`u{F02D}"   # book
    'locate'        = "`u{F041}"   # map-marker
    'open'          = "`u{F08E}"   # external-link
    'specs'         = "`u{F108}"   # desktop
    'uptime'        = "`u{F017}"   # clock-o
    'raminfo'       = "`u{F538}"   # memory
    'battery'       = "`u{F241}"   # battery-three-quarters
    'temps'         = "`u{F2C9}"   # thermometer-half
    'fans'          = "`u{F863}"   # fan
    'displays'      = "`u{F26C}"   # tv
    'hypervisor'    = "`u{F247}"   # object-group
    'power'         = "`u{F011}"   # power-off
    'license'       = "`u{F0A3}"   # certificate
    'wifi'          = "`u{F1EB}"   # wifi
    'dnsbench'      = "`u{F252}"   # hourglass-half
    'linkspeed'     = "`u{F07D}"   # arrows-v
    'shares'        = "`u{F1E0}"   # share-alt
    'hostscheck'    = "`u{F1C9}"   # file-code-o
    'dnscache'      = "`u{F1DA}"   # history
    'shield'        = "`u{F132}"   # shield
    'admins'        = "`u{F505}"   # user-shield
    'apps'          = "`u{F17A}"   # windows brand
    'patchhistory'  = "`u{F0AD}"   # wrench
    'driveraudit'   = "`u{F085}"   # cogs
    'certs'         = "`u{F559}"   # award
    'clipcheck'     = "`u{F0EA}"   # clipboard
    'recent'        = "`u{F016}"   # file-o
    'drivehealth'   = "`u{F004}"   # heart
    'dumps'         = "`u{F1E2}"   # bomb
    'badfiles'      = "`u{F071}"   # exclamation-triangle
    'links'         = "`u{F0C1}"   # chain
    'locked'        = "`u{F023}"   # lock
    'sparse'        = "`u{F070}"   # eye-slash
    'compress'      = "`u{F187}"   # archive
}

# Nerd Font variants for suite titles, keyed by the exact Unicode title.
$script:HawkNerdSuiteTitles = @{
    '🛡️ SENTINEL'       = "`u{F132} SENTINEL"
    '🩺 DIAGNOSTICS'    = "`u{F21E} DIAGNOSTICS"
    '⚙️ ENVIRONMENT'    = "`u{F085} ENVIRONMENT"
    '🤖 AI ENGINE'      = "`u{F0D0} AI ENGINE"
    '🔁 WORKFLOWS'      = "`u{F079} WORKFLOWS"
    '💬 HUB & MEMORY'   = "`u{F086} HUB & MEMORY"
    '📁 WORKSPACE'      = "`u{F07B} WORKSPACE"
    '⛁ SYSTEM MATRIX'   = "`u{F2DB} SYSTEM MATRIX"
    '≋ NET INTEL'       = "`u{F6FF} NET INTEL"
    '⛨ SEC SCAN'        = "`u{F3ED} SEC SCAN"
    '▤ STORAGE'         = "`u{F1C0} STORAGE"
}
$script:HawkLlamaEndpoint = "http://127.0.0.1:$($script:HawkLlamaPort)"

function Write-HawkHeader {
    <#
    .SYNOPSIS
    Writes a colored section header to the console.
    .DESCRIPTION
    Outputs a message in the specified color. Headers are suppressed when
    $script:HawkSuppressHeaders is set (used during report generation).
    .PARAMETER Message
    Header text to display.
    .PARAMETER Color
    Console color for the header. Default: Cyan.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = 'Cyan'
    )

    if (-not $script:HawkSuppressHeaders) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-HawkInteractiveSession {
    <#
    .SYNOPSIS
    Tests whether the session is an interactive console.
    .DESCRIPTION
    Returns true when running in a user-interactive, non-redirected console that
    is not CI and has not opted out via HAWK_NO_DASH.
    #>
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
    <#
    .SYNOPSIS
    Installs required PowerShell modules for the current user.
    .DESCRIPTION
    Checks for each required module (Terminal-Icons, PSReadLine, PSTree) and
    installs missing ones from the gallery. Supports -WhatIf via ShouldProcess.
    .PARAMETER ModuleName
    Module names to install. Defaults to Hawk's required modules list.
    #>
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
    <#
    .SYNOPSIS
    Imports required PowerShell modules into the current session.
    .DESCRIPTION
    Attempts to import each required module and returns status objects. Use -Quiet
    to suppress output. Missing modules return a helpful install reminder.
    .PARAMETER ModuleName
    Module names to import. Defaults to Hawk's required modules list.
    .PARAMETER Quiet
    Suppress status output.
    #>
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
            # -Global is REQUIRED when called from inside this module's session state,
            # otherwise imported modules stay private to HawkwardHybrid.
            Import-Module -Name $module -Global -ErrorAction SilentlyContinue 2>$null
            [PSCustomObject]@{
                Module  = $module
                Status  = if (Get-Module $module) { 'Imported' } else { 'Failed' }
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
    <#
    .SYNOPSIS
    Configures PSReadLine prediction and display options.
    .DESCRIPTION
    Enables history-based prediction with ListView style. Silently skips if
    PSReadLine is not available (e.g. in non-console hosts).
    #>
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

    # PSFzf fuzzy finders — only when the fzf binary is present, so sessions
    # without it stay clean (Import-Module PSFzf throws when fzf.exe is missing).
    if ((Get-Module -ListAvailable PSFzf) -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
        try {
            Import-Module PSFzf -Global -ErrorAction Stop
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
            Set-PsFzfOption -EnableAliasFuzzyZLocation
        }
        catch {
            # Headless/redirected hosts may reject the key handlers; ignore.
        }
    }
}

function Get-HawkPromptText {
    <#
    .SYNOPSIS
    Generates the two-line ANSI prompt string for the Hawkward session.
    .DESCRIPTION
    Builds a colored prompt showing OS version, PowerShell version, username,
    hostname, current directory, and git branch (if in a repo). The second
    line shows a green or red indicator based on the last command's success.
    .PARAMETER LastSuccess
    Whether the last command succeeded. Green indicator if true, red if false.
    #>
    [CmdletBinding()]
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

    # Nerd Font glyphs when available, emoji fallback otherwise (cached check).
    $useNf = Test-HawkNerdFont
    $icoSys = if ($useNf) { "`u{F109}" } else { '💻' }   # laptop / desktop
    $icoUsr = if ($useNf) { "`u{F0E7}" } else { '⚡' }   # bolt
    $icoPth = if ($useNf) { "`u{F115}" } else { '📂' }   # folder-open

    $segSys = "${bgSys} $icoSys $os | PS $psVer ${reset}"
    $segUsr = "${bgUsr} $icoUsr $user@$hostName ${reset}"
    $segPth = "${bgPth} $icoPth $path ${reset}"
    $segGit = Get-HawkPromptGitSegment -Reset $reset

    $topLine = "$segSys$sep$segUsr$sep$segPth"
    if ($segGit) { $topLine += "$sep$segGit" }

    $statusColor = if ($LastSuccess) { "${esc}[38;5;82m" } else { "${esc}[38;5;196m" }
    return "`n$topLine`n${statusColor}>${reset} "
}

function Get-HawkPromptGitSegment {
    <#
    .SYNOPSIS
    Builds the git branch segment for the Hawkward prompt.
    .DESCRIPTION
    If the current directory is inside a git repo, returns an ANSI-colored
    string showing the current branch name. Returns empty string if git is
    not installed or the directory is not a repo.
    .PARAMETER Reset
    The ANSI reset escape sequence to append after the segment.
    #>
    [CmdletBinding()]
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
                # Nerd Font branch/status glyphs when available, emoji otherwise.
                $icoBranch = if (Test-HawkNerdFont) { "`u{E725}" } else { '🌿' }   # git branch
                if ($status) {
                    $icoState = if (Test-HawkNerdFont) { "`u{F071}" } else { '⚠️' } # warning
                    $bgGit = "${esc}[48;5;136m${esc}[38;5;255m"
                    $segment = "${bgGit} $icoBranch $branch [$icoState] ${Reset}"
                }
                else {
                    $icoState = if (Test-HawkNerdFont) { "`u{F00C}" } else { '✅' } # check
                    $bgGit = "${esc}[48;5;28m${esc}[38;5;255m"
                    $segment = "${bgGit} $icoBranch $branch [$icoState] ${Reset}"
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
    <#
    .SYNOPSIS
    Installs the Hawkward custom prompt.
    .DESCRIPTION
    Replaces the global Prompt function to show OS, user, path, git branch,
    and last-command status with color-coded segments.
    #>
    Set-Item -Path Function:\global:Prompt -Value {
        $lastSuccess = $?
        Get-HawkPromptText -LastSuccess:$lastSuccess
    }
}

function Protect-HawkSensitiveText {
    <#
    .SYNOPSIS
    Redacts secrets, tokens, and passwords from pipeline text.
    .DESCRIPTION
    Uses regex patterns to replace secret/token/password/API key values with
    <REDACTED> in both key=value and JSON formats. Alias: secretredact.
    .PARAMETER InputObject
    Text or objects to redact secrets from.
    #>
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

function Get-HawkAIIntent {
    <#
    .SYNOPSIS
    Classifies an instruction into an AI intent category.
    .DESCRIPTION
    Parses the instruction text to determine intent: Research, Shell, Compare,
    Explain, or AnalyzeData. Used internally by the AI pipeline.
    .PARAMETER Instruction
    The user instruction to classify.
    #>
    [CmdletBinding()]
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
    <#
    .SYNOPSIS
    Profiles pipeline input data for AI context.
    .DESCRIPTION
    Inspects input objects to determine data kind (Text, Table, Object, Empty),
    row count, and column names. Used internally to build AI context packets.
    .PARAMETER InputObject
    Data objects to profile.
    #>
    [CmdletBinding()]
    param([object[]]$InputObject = @())

    $rows = @($InputObject | Where-Object { $null -ne $_ })
    if (-not $rows -or $rows.Count -eq 0) {
        return [PSCustomObject]@{
            Kind    = 'Empty'
            Rows    = 0
            Columns = ''
        }
    }

    $first = $rows[0]
    if ($first -is [string]) {
        return [PSCustomObject]@{
            Kind    = 'Text'
            Rows    = $rows.Count
            Columns = 'Text'
        }
    }

    $columns = @(
        $first.PSObject.Properties |
        Where-Object { $_.Name -notmatch '^PS' } |
        Select-Object -ExpandProperty Name -First 24
    )

    [PSCustomObject]@{
        Kind    = if ($columns.Count -gt 1) { 'Table' } else { 'Object' }
        Rows    = $rows.Count
        Columns = ($columns -join ', ')
    }
}

function New-HawkAIContextPacket {
    <#
    .SYNOPSIS
    Builds a context envelope for AI requests.
    .DESCRIPTION
    Combines intent classification, analysis mode (Fast/Balanced/Deep), and
    data profile into a structured context packet for the AI pipeline.
    .PARAMETER Instruction
    The user instruction or question.
    .PARAMETER InputObject
    Pipeline data to include in the context.
    #>
    [CmdletBinding()]
    param(
        [string]$Instruction,
        [object[]]$InputObject = @()
    )

    $intent = Get-HawkAIIntent -Instruction $Instruction
    $aiProfile = Get-HawkAIDataProfile -InputObject $InputObject
    $mode = if ($Instruction -match '(?i)\b(deep|thorough|investigate|full|history|compare)\b') {
        'Deep'
    }
    elseif ($intent -in @('Research', 'Compare')) {
        'Balanced'
    }
    else {
        'Fast'
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('Context envelope:')
    $lines.Add("- Mode: $mode")
    $lines.Add("- Intent: $intent")
    $lines.Add("- Data kind: $($aiProfile.Kind)")
    $lines.Add("- Rows: $($aiProfile.Rows)")
    if ($aiProfile.Columns) {
        $lines.Add("- Columns: $($aiProfile.Columns)")
    }

    [PSCustomObject]@{
        Intent = $intent
        Mode   = $mode
        Text   = ($lines -join [Environment]::NewLine)
    }
}

<#
.SYNOPSIS
Maps startup items and their impact on boot time.
.DESCRIPTION
Lists auto-start entries from the Windows Run registry keys (HKLM and HKCU).
Shows name, target command, and registry hive.
#>
