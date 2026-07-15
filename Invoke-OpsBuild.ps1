param(
    [switch]$SkipAnalyzer,
    [switch]$SkipTests,
    [string]$ReportPath
)

$projectRoot = $PSScriptRoot
$moduleManifest = Join-Path $projectRoot "Modules\PowershellOps\PowershellOps.psd1"
$moduleFile = Join-Path $projectRoot "Modules\PowershellOps\PowershellOps.psm1"
$testFile = Join-Path $projectRoot "Modules\PowershellOps\Tests\PowershellOps.Tests.ps1"

$esc = [char]27
$reset = "${esc}[0m"
Write-Host "${esc}[38;5;183m╔═══════════════════════════════════════════════════╗${reset}"
Write-Host "${esc}[38;5;183m║      ${esc}[38;5;158mPOWERSHELL OPS BUILD v11.3${reset}${esc}[38;5;183m                   ║${reset}"
Write-Host "${esc}[38;5;183m╚═══════════════════════════════════════════════════╝${reset}"
Write-Host ""

$exitCode = 0

$acceptedAnalyzerRules = @(
    'PSAvoidGlobalVars',       # $global:HawkProjectRoot & $global:HawkLastSearchTime — intentional user-facing config
    'PSAvoidUsingWriteHost',   # Dashboard UI, AI streaming, Report tables — deliberate console rendering
    'PSReviewUnusedParameter', # $Color in Write-HawkHeader, $Reset in Get-HawkPromptGitSegment — API consistency & closure usage
    'PSUseSingularNouns'       # Set-HawkAliases — intentionally manages multiple aliases
)

if (-not $SkipAnalyzer) {
    Write-Host "── [1/2] PSScriptAnalyzer ──────────────────────" -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
        Write-Host "  [SKIP] PSScriptAnalyzer not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser" -ForegroundColor DarkYellow
    } else {
        $results = Invoke-ScriptAnalyzer -Path $moduleFile -Severity Error, Warning -ErrorAction SilentlyContinue
        $accepted = @($results | Where-Object { $_.RuleName -in $acceptedAnalyzerRules })
        $failures = @($results | Where-Object { $_.RuleName -notin $acceptedAnalyzerRules })
        if ($results) { $results | Format-Table RuleName, Severity, Line, Message -AutoSize }
        if ($accepted) { Write-Host "  [INFO] $($accepted.Count) accepted/intentional violations (not counted as failure)." -ForegroundColor DarkYellow }
        if ($failures) {
            Write-Host "  [FAIL] $($failures.Count) new/critical analyzer violations found." -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "  [PASS] No new analyzer violations." -ForegroundColor Green
        }
    }
    Write-Host ""
}

if (-not $SkipTests) {
    Write-Host "── [2/2] Pester Tests ───────────────────────────" -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable Pester)) {
        Write-Host "  [SKIP] Pester not installed. Run: Install-Module Pester -Scope CurrentUser -Force" -ForegroundColor DarkYellow
    } else {
        $config = New-PesterConfiguration
        $config.Run.Path = $testFile
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        if ($ReportPath) {
            $config.TestResult.OutputPath = Join-Path $ReportPath "hawk-test-results.xml"
        }
        $config.Output.Verbosity = 'Detailed'
        $result = Invoke-Pester -Configuration $config
        if ($result.FailedCount -gt 0) {
            Write-Host "  [FAIL] $($result.FailedCount) test(s) failed." -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "  [PASS] All $($result.TotalCount) tests passed." -ForegroundColor Green
        }
    }
    Write-Host ""
}

Write-Host "── Summary ────────────────────────────────────────" -ForegroundColor Yellow
if ($exitCode -eq 0) {
    Write-Host "  BUILD PASSED" -ForegroundColor Green
} else {
    Write-Host "  BUILD FAILED" -ForegroundColor Red
}

exit $exitCode

