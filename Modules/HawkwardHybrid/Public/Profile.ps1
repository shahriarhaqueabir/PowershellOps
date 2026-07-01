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
    $pathSegment = "${esc}[48;5;239m${esc}[38;5;255m 󰉋 $path ${reset}"
    $timeSegment = "${esc}[48;5;24m${esc}[38;5;117m 󱑎 $([System.DateTime]::Now.ToString('HH:mm:ss')) ${reset}"
    $gitSegment = Get-HawkPromptGitSegment -Reset $reset
    $statusColor = if ($LastSuccess) { "${esc}[38;5;121m" } else { "${esc}[38;5;196m" }
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
        @("health", "Get-HawkHealth"),
        @("spec", "Get-HawkSpec"),
        @("uptime", "Get-HawkUptime"),
        @("ram", "Get-HawkRamInfo"),
        @("battery", "Get-HawkBattery"),
        @("display", "Get-HawkDisplay"),
        @("powerplan", "Get-HawkPower"),
        @("hyperv", "Get-HawkHypervisor"),
        @("license", "Get-HawkLicense"),
        @("disk", "Get-HawkDiskPressureAudit"),
        @("temp", "Get-HawkTempCheck"),
        @("clip", "Get-HawkClipCheck"),
        @("smarts", "Get-HawkDriveHealth"),
        @("res", "Get-HawkResourceMap"),
        @("port", "Get-HawkPortMap"),
        @("admin", "Get-HawkAdmin"),
        @("shield", "Get-HawkShield"),
        @("fw", "Get-HawkFirewallAudit"),
        @("boot", "Get-HawkBootMap"),
        @("schedtask", "Get-HawkScheduledTaskRiskAudit"),
        @("ghost", "Get-HawkGhostPortAudit"),
        @("sus", "Get-HawkSuspiciousProcessAudit"),
        @("storm", "Get-HawkEventStormAudit"),
        @("cert", "Get-HawkCert"),
        @("dump", "Get-HawkDump"),
        @("badfile", "Get-HawkBadFile"),
        @("link", "Get-HawkLink"),
        @("lock", "Get-HawkLock"),
        @("sparse", "Get-HawkSparseFile"),
        @("compress", "Get-HawkCompressedDir"),
        @("patch", "Get-HawkPatchHistory"),
        @("driver", "Get-HawkDriverAudit"),
        @("recent", "Get-HawkRecent"),
        @("secretredact", "Protect-HawkSensitiveText"),
        @("ping", "Get-HawkNetCheck"),
        @("wifi", "Get-HawkWifi"),
        @("established", "Get-HawkEstablished"),
        @("dns", "Get-HawkDnsBench"),
        @("linkspeed", "Get-HawkLinkSpeed"),
        @("smb", "Get-HawkShare"),
        @("hosts", "Get-HawkHostsCheck"),
        @("dnscache", "Get-HawkDnsCache"),
        @("nettriage", "Get-HawkNetworkTriage"),
        @("envmap", "Get-HawkEnvMap"),
        @("path", "Get-HawkPathAudit"),
        @("app", "Get-HawkApp"),
        @("where", "Get-HawkAppLocation"),
        @("ai", "Invoke-HawkAI"),
        @("ggl", "Invoke-HawkSearch"),
        @("aistatus", "Get-HawkAIStatus"),
        @("intent", "Get-HawkAIIntent"),
        @("aiprofile", "Get-HawkAIDataProfile"),
        @("quality", "Get-HawkSourceQualityScore"),
        @("injecttest", "Test-HawkPromptInjection"),
        @("remember", "Add-HawkMemory"),
        @("recall", "Search-HawkMemory"),
        @("memmap", "Get-HawkMemoryMap"),
        @("readmem", "Read-HawkMemory"),
        @("memfile", "Get-HawkMemoryFile"),
        @("hawkreport", "New-HawkReport"),
        @("reportpath", "Get-HawkReportPath"),
        @("dash", "Show-HawkDashboard"),
        @("watch", "Watch-HawkDashboard"),
        @("hawkman", "Show-HawkManual"),
        @("reload", "Update-HawkProfile"),
        @("init", "Initialize-HawkProfile"),
        @("proj", "Get-HawkProject"),
        @("projset", "Invoke-HawkProject"),
        @("explorer", "Invoke-ExplorerHere"),
        @("cached", "Invoke-HawkCachedData"),
        @("sys", "Get-HawkSystem"),
        @("audit", "Get-HawkAudit"),
        @("net", "Get-HawkNetwork"),
        @("env", "Get-HawkEnv"),
        @("dailyops", "Invoke-HawkDailyOps"),
        @("sysreview", "Invoke-HawkSystemReview"),
        @("secaudit", "Invoke-HawkSecurityAudit"),
        @("netdiag", "Invoke-HawkNetworkDiagnostics"),
        @("threat", "Invoke-HawkThreatHunt"),
        @("change", "Invoke-HawkChangeAudit"),
        @("compliance", "Invoke-HawkComplianceCheck")
    )
    foreach ($m in $mappings) {
        Set-Alias -Scope Global -Name (Get-HawkSafeAliasName -Name $m[0]) -Value $m[1] -Force
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
        Write-Host ''
        Write-Host '  ⚠  HAWKWARD HYBRID — First Run Notice' -ForegroundColor Yellow
        Write-Host '  ─────────────────────────────────────' -ForegroundColor DarkGray
        Write-Host '  This profile loader registers:' -ForegroundColor White
        Write-Host '    • 81 hawk-* aliases (all prefixed, no shadowing of system cmdlets)' -ForegroundColor Gray
        Write-Host '    • A custom prompt with git status segment' -ForegroundColor Gray
        Write-Host '    • PSReadLine predictive IntelliSense configuration' -ForegroundColor Gray
        Write-Host ''
        Write-Host '  To remove aliases at any time:' -ForegroundColor White
        Write-Host '    Get-Alias | Where-Object { $_.Name -like "hawk-*" } | Remove-Item' -ForegroundColor Gray
        Write-Host ''
        Write-Host '  Set $env:HAWK_NO_DASH=1 to suppress the automatic dashboard.' -ForegroundColor White
        Write-Host ''
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
    if ($PSCmdlet.ShouldProcess('HawkwardHybrid', 'Pull latest and reload')) {
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
            Remove-Module HawkwardHybrid -Force -ErrorAction SilentlyContinue
            Write-Information "  [Update] Reloading..." -InformationAction Continue
            Import-Module (Join-Path $moduleDir 'HawkwardHybrid.psd1') -Force -Global
            Write-Information "  [Update] HawkwardHybrid reloaded." -InformationAction Continue
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

