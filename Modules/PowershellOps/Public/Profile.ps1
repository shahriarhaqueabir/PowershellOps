# ── PUBLIC: PROFILE & INIT ─────────────────────────────────────────────────

function Install-HawkPrerequisite {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string[]]$ModuleName = $script:HawkRequiredModules
    )
    foreach ($module in $ModuleName) {
        if (Get-Module -ListAvailable -Name $module) {
            $trust = Test-HawkModulePublisher -ModuleName $module
            if (-not $trust.Trusted) {
                [PSCustomObject]@{
                    Module      = $module
                    Status      = $trust.Status
                    Message     = $trust.Message
                    Author      = $trust.Author
                    CompanyName = $trust.CompanyName
                }
                continue
            }
            [PSCustomObject]@{ Module = $module; Status = 'AlreadyInstalled'; Author = $trust.Author; CompanyName = $trust.CompanyName }
            continue
        }
        if ($PSCmdlet.ShouldProcess($module, 'Install PowerShell module for current user')) {
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                $trust = Test-HawkModulePublisher -ModuleName $module
                if (-not $trust.Trusted) {
                    [PSCustomObject]@{
                        Module      = $module
                        Status      = $trust.Status
                        Message     = $trust.Message
                        Author      = $trust.Author
                        CompanyName = $trust.CompanyName
                    }
                    continue
                }
                [PSCustomObject]@{ Module = $module; Status = 'Installed'; Author = $trust.Author; CompanyName = $trust.CompanyName }
            } catch {
                [PSCustomObject]@{ Module = $module; Status = 'Failed'; Message = $_.Exception.Message }
            }
        }
    }
}

function Import-HawkPrerequisite {
    [CmdletBinding()]
    param(
        [string[]]$ModuleName = $script:HawkRequiredModules,
        [switch]$Quiet
    )
    $results = foreach ($module in $ModuleName) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            [PSCustomObject]@{ Module = $module; Status = 'Missing'; Message = 'Run Install-HawkPrerequisites' }
            continue
        }
        $trust = Test-HawkModulePublisher -ModuleName $module
        if (-not $trust.Trusted) {
            [PSCustomObject]@{
                Module      = $module
                Status      = $trust.Status
                Message     = $trust.Message
                Author      = $trust.Author
                CompanyName = $trust.CompanyName
            }
            continue
        }
        try {
            Import-Module -Name $module -ErrorAction SilentlyContinue 2>$null
            [PSCustomObject]@{ Module = $module; Status = 'Imported'; Message = ''; Author = $trust.Author; CompanyName = $trust.CompanyName }
        } catch {
            [PSCustomObject]@{ Module = $module; Status = 'Failed'; Message = $_.Exception.Message }
        }
    }
    if (-not $Quiet) { $results }
}

function Set-HawkReadLine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) { return }
    if ($PSCmdlet.ShouldProcess('PSReadLine options', 'Configure prediction settings')) {
        try {
            Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
        } catch { Write-Warning "PSReadLine configuration failed: $($_.Exception.Message)" }
    }
}

function Get-HawkPromptText {
    param([bool]$LastSuccess = $true)
    $esc = [char]27
    $reset = "${esc}[0m"
    $path = (Get-Location).Path -replace "^$([Regex]::Escape([Environment]::GetFolderPath('UserProfile')))", '~'
    $pathSegment = "${esc}[48;5;158m${esc}[38;5;16m 󰉋 $path ${reset}"
    $timeSegment = "${esc}[48;5;244m${esc}[38;5;255m 󱑎 $([System.DateTime]::Now.ToString('HH:mm:ss')) ${reset}"
    $gitSegment = Get-HawkPromptGitSegment -Reset $reset
    $statusColor = if ($LastSuccess) { "${esc}[38;5;158m" } else { "${esc}[38;5;217m" }
    return "`n${pathSegment}${timeSegment}${gitSegment}`n${statusColor}󱞩 ${reset} "
}

function Get-HawkPromptGitSegment {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Used in cached scriptblock via closure')]
    [CmdletBinding()]
    param([string]$Reset)
    $cwd = $ExecutionContext.SessionState.Path.CurrentLocation.Path

    if (-not $script:HawkGitPromptBlock) {
        $script:HawkGitPromptBlock = {
            param([string]$currentDir, [string]$ansiReset)
            $gitDir = Join-Path $currentDir '.git'
            if (-not (Test-Path $gitDir)) {
                $parent = Split-Path $currentDir -Parent
                for ($i = 0; $i -lt 3 -and $parent; $i++) {
                    if (Test-Path (Join-Path $parent '.git')) {
                        $gitDir = Join-Path $parent '.git'
                        break
                    }
                    $parent = Split-Path $parent -Parent
                }
            }
            if (-not (Test-Path $gitDir)) { return '' }
            try {
                $headPath = Join-Path $gitDir 'HEAD'
                if (Test-Path $headPath) {
                    $headContent = Get-Content $headPath -Raw -ErrorAction SilentlyContinue
                    if ($headContent -match 'ref:\s+refs/heads/(.*)') {
                        $branch = $matches[1].Trim()
                        $esc = [char]27
                        return "${esc}[48;5;28m${esc}[38;5;255m 🌿 $branch [FS-Cached] ${ansiReset}"
                    }
                }
            } catch { Write-Verbose "Git prompt cache failed: $($_.Exception.Message)" }
            return ''
        }
    }

    return Invoke-HawkCachedData -Key "git_prompt_$cwd" -ExpirySeconds 3 -ScriptBlock {
        &$script:HawkGitPromptBlock $cwd $Reset
    }
}

function Set-HawkPrompt {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if ($PSCmdlet.ShouldProcess('global:prompt', 'Set custom prompt function')) {
        if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
            Set-Item -Path Function:\global:Prompt -Value { Get-HawkPromptText -LastSuccess:$? }
        }
    }
}

function Set-HawkAliases {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Intentionally sets all aliases in one call')]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not $PSCmdlet.ShouldProcess('Global aliases', 'Set all Hawk aliases')) { return }
    $mappings = @(
        @("corehealth", "Get-HawkHealth"),
        @("sysspec", "Get-HawkSpec"),
        @("sysuptime", "Get-HawkUptime"),
        @("ramstats", "Get-HawkRamInfo"),
        @("battstatus", "Get-HawkBattery"),
        @("gpuview", "Get-HawkDisplay"),
        @("powertriage", "Get-HawkPower"),
        @("vmcheck", "Get-HawkHypervisor"),
        @("liccheck", "Get-HawkLicense"),
        @("diskpressure", "Get-HawkDiskPressureAudit"),
        @("tempcheck", "Get-HawkTempCheck"),
        @("clipcheck", "Get-HawkClipCheck"),
        @("smartstatus", "Get-HawkDriveHealth"),
        @("resourcemap", "Get-HawkResourceMap"),
        @("portmap", "Get-HawkPortMap"),
        @("adminaudit", "Get-HawkAdmin"),
        @("shieldstatus", "Get-HawkShield"),
        @("fwcheck", "Get-HawkFirewallAudit"),
        @("bootmap", "Get-HawkBootMap"),
        @("taskrisk", "Get-HawkScheduledTaskRiskAudit"),
        @("ghostports", "Get-HawkGhostPortAudit"),
        @("susprocs", "Get-HawkSuspiciousProcessAudit"),
        @("eventstorm", "Get-HawkEventStormAudit"),
        @("certaudit", "Get-HawkCert"),
        @("dumpmap", "Get-HawkDump"),
        @("filecheck", "Get-HawkBadFile"),
        @("shortcutcheck", "Get-HawkLink"),
        @("lockcheck", "Get-HawkLock"),
        @("sparsecheck", "Get-HawkSparseFile"),
        @("compresscheck", "Get-HawkCompressedDir"),
        @("patchhistory", "Get-HawkPatchHistory"),
        @("driveraudit", "Get-HawkDriverAudit"),
        @("recentfiles", "Get-HawkRecent"),
        @("secretmask", "Protect-HawkSensitiveText"),
        @("netping", "Get-HawkNetCheck"),
        @("wificheck", "Get-HawkWifi"),
        @("peerscheck", "Get-HawkEstablished"),
        @("dnsbench", "Get-HawkDnsBench"),
        @("netspeed", "Get-HawkLinkSpeed"),
        @("smbshares", "Get-HawkShare"),
        @("hostscheck", "Get-HawkHostsCheck"),
        @("dnsmap", "Get-HawkDnsCache"),
        @("nettriage", "Get-HawkNetworkTriage"),
        @("envmap", "Get-HawkEnvMap"),
        @("pathaudit", "Get-HawkPathAudit"),
        @("applist", "Get-HawkApp"),
        @("apploc", "Get-HawkAppLocation"),
        @("askai", "Invoke-HawkAI"),
        @("websearch", "Invoke-HawkSearch"),
        @("aistatus", "Get-HawkAIStatus"),
        @("aiintent", "Get-HawkAIIntent"),
        @("aiprofile", "Get-HawkAIDataProfile"),
        @("sourcequality", "Get-HawkSourceQualityScore"),
        @("safetycheck", "Test-HawkPromptInjection"),
        @("airemember", "Add-HawkMemory"),
        @("airecall", "Search-HawkMemory"),
        @("memorymap", "Get-HawkMemoryMap"),
        @("memoryread", "Read-HawkMemory"),
        @("memoryfile", "Get-HawkMemoryFile"),
        @("fullreport", "New-HawkReport"),
        @("reportpath", "Get-HawkReportPath"),
        @("coreindex", "Show-HawkDashboard"),
        @("watchindex", "Watch-HawkDashboard"),
        @("coremanual", "Show-HawkManual"),
        @("corereload", "Update-HawkProfile"),
        @("coreinit", "Initialize-HawkProfile"),
        @("projview", "Get-HawkProject"),
        @("projset", "Invoke-HawkProject"),
        @("openhere", "Invoke-ExplorerHere"),
        @("corecache", "Invoke-HawkCachedData"),
        @("sysdiag", "Get-HawkSystem"),
        @("auditdiag", "Get-HawkAudit"),
        @("netdiag", "Get-HawkNetwork"),
        @("envdiag", "Get-HawkEnv"),
        @("dailycheck", "Invoke-HawkDailyOps"),
        @("sysreview", "Invoke-HawkSystemReview"),
        @("secaudit", "Invoke-HawkSecurityAudit"),
        @("netdiag", "Invoke-HawkNetworkDiagnostics"),
        @("threathunt", "Invoke-HawkThreatHunt"),
        @("changeaudit", "Invoke-HawkChangeAudit"),
        @("compliancecheck", "Invoke-HawkComplianceCheck")
    )
    foreach ($m in $mappings) {
        Set-Alias -Scope Global -Name $m[0] -Value $m[1] -Force
    }
}

function Initialize-HawkProfile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$ProjectRoot = $script:HawkDefaultProjectRoot,
        [switch]$ShowDashboard,
        [switch]$SkipModules
    )
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $global:HawkProjectRoot = $ProjectRoot

    $isFirstRun = -not (Test-Path $script:HawkFirstRunSentinel)
    if ($isFirstRun -and (Test-HawkInteractiveSession)) {
        $esc = [char]27
        $gray = "${esc}[38;5;246m"
        $mint = "${esc}[48;5;158m${esc}[38;5;16m"
        $reset = "${esc}[0m"

        Write-Host ""
        Write-Host "  ${mint} POWERSHELL OPS : CORE ${reset} System provisioned. Version $($script:HawkVersion)."
        Write-Host "  ${gray}──────────────────────────────────────────────────────────${reset}"
        Write-Host "  Active environment: $ProjectRoot"
        Write-Host "  Architecture: 81 utilities | 7 workflows | Local AI"
        Write-Host ""

        if (-not (Test-HawkNerdFont)) {
            Write-Host "  ${gray}Note: Graphical symbols inactive. Install a Nerd Font for full UI.${reset}"
        }

        Write-Host "  Type 'coreindex' for index. 'dailycheck' for status."
        Write-Host ""
        try {
            $null = New-Item -Path $script:HawkFirstRunSentinel -ItemType File -Force -ErrorAction Stop
        } catch { Write-Verbose "Could not write first-run sentinel: $($_.Exception.Message)" }
    }

    if (-not $SkipModules) {
        Import-HawkPrerequisite -Quiet | Out-Null
    }

    Set-HawkReadLine
    Set-HawkAliases
    Set-HawkPrompt

    if ($ShowDashboard -and (Test-HawkInteractiveSession)) {
        Show-HawkDashboard
    }
}

function Update-HawkModule {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess('PowershellOps', 'Pull latest and reload')) {
        $moduleDir = $PSScriptRoot
        $repoRoot = $moduleDir
        for ($i = 0; $i -lt 5 -and $repoRoot; $i++) {
            if (Test-Path (Join-Path $repoRoot '.git')) { break }
            $parent = Split-Path $repoRoot -Parent
            if ($parent -eq $repoRoot) { $repoRoot = $null; break }
            $repoRoot = $parent
        }
        if (-not $repoRoot -or -not (Test-Path (Join-Path $repoRoot '.git'))) {
            Write-Warning "No git repository found for module path: $moduleDir"
            return
        }
        Push-Location $repoRoot
        try {
            Write-Information "  [Update] Pulling latest from git..." -InformationAction Continue
            git pull
            Write-Information "  [Update] Removing module from session..." -InformationAction Continue
            Remove-Module PowershellOps -Force -ErrorAction SilentlyContinue
            Write-Information "  [Update] Reloading..." -InformationAction Continue
            Import-Module (Join-Path $moduleDir 'PowershellOps.psd1') -Force -Global
            Write-Information "  [Update] PowershellOps reloaded." -InformationAction Continue
        } finally { Pop-Location }
    }
}

function Update-HawkProfile {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if ($PSCmdlet.ShouldProcess('$PROFILE', 'Dot-source profile')) { . $PROFILE }
}

function Show-HawkManual {
    $manualPath = Join-Path $script:HawkWorkspaceRoot 'MANUAL.md'
    if (Test-Path $manualPath) {
        Write-Host "  Opening MANUAL.md..." -ForegroundColor Cyan
        Invoke-Item $manualPath
    } else {
        Write-Warning "Manual not found at: $manualPath"
    }
}

function Invoke-ExplorerHere { Start-Process explorer.exe -ArgumentList (Get-Location).Path }

function Get-HawkProject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding()]
    param()
    [PSCustomObject]@{ CurrentRoot = ($global:HawkProjectRoot ?? $script:HawkDefaultProjectRoot) }
}

function Invoke-HawkProject {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Intentional user-facing config')]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$Path = $script:HawkDefaultProjectRoot)
    if ($PSCmdlet.ShouldProcess("Project root '$Path'", 'Set project root')) {
        $global:HawkProjectRoot = $Path
    }
    Get-HawkProject
}

function Get-HawkEnv {
    [CmdletBinding()]
    param([ValidateSet('Env','Path','App','Patch','Driver','Admin','Hypervisor','Power','License')][string]$Type = 'Env')
    switch ($Type) {
        'Env'        { Get-HawkEnvMap }
        'Path'       { Get-HawkPathAudit }
        'App'        { Get-HawkApp }
        'Patch'      { Get-HawkPatchHistory }
        'Driver'     { Get-HawkDriverAudit }
        'Admin'      { Get-HawkAdmin }
        'Hypervisor' { Get-HawkHypervisor }
        'Power'      { Get-HawkPower }
        'License'    { Get-HawkLicense }
    }
}


