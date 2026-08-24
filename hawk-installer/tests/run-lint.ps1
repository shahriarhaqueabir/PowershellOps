# run-lint.ps1 — static analysis gate ("eyes") over ALL PowerShell code.
#
# Stage 1 (always): AST parse of every *.ps1 / *.psm1 / *.psd1 under the repo
#                   root. Zero dependencies, catches syntax errors instantly.
# Stage 2 (opt-out): PSScriptAnalyzer pass with curated settings. Fails on
#                    Error-severity findings; reports Warnings without failing.
#
# Usage:
#   pwsh -NoProfile -File tests\run-lint.ps1             # full gate
#   pwsh -NoProfile -File tests\run-lint.ps1 -ParseOnly  # fast syntax-only
#
# Exit codes: 0 = clean (warnings allowed), 1 = parse errors or analyzer errors.

param(
    [switch]$ParseOnly
)

$ErrorActionPreference = 'Continue'
$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # repo root
$script:Findings = [System.Collections.Generic.List[string]]::new()

function Write-LintHeader { param([string]$Text) Write-Host "`n== $Text ==" -ForegroundColor Cyan }

# --- enumerate target files -------------------------------------------------
$excludeDirs = '\\(\.git|node_modules|\.context|\.memory|\.opencode)(\\|$)'
$files = @(Get-ChildItem -LiteralPath $script:RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' -and $_.FullName -notmatch $excludeDirs })

if ($files.Count -eq 0) {
    Write-Host 'FAIL no PowerShell files found - check repo root detection' -ForegroundColor Red
    exit 1
}
Write-Host ("scanning {0} PowerShell files under {1}" -f $files.Count, $script:RepoRoot)

# --- stage 1: AST parse -----------------------------------------------------
Write-LintHeader 'Stage 1: AST parse'
$parseErrors = [System.Collections.Generic.List[string]]::new()
foreach ($f in $files) {
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    foreach ($e in $errors) {
        $parseErrors.Add(("{0}:{1}:{2} {3}" -f $f.FullName.Substring($script:RepoRoot.Length + 1), $e.Extent.StartLineNumber, $e.Extent.StartColumnNumber, $e.Message))
    }
}
if ($parseErrors.Count -gt 0) {
    Write-Host ("FAIL {0} parse error(s):" -f $parseErrors.Count) -ForegroundColor Red
    $parseErrors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
Write-Host ("PASS all {0} files parse clean" -f $files.Count) -ForegroundColor Green

if ($ParseOnly) { exit 0 }

# --- stage 2: PSScriptAnalyzer ----------------------------------------------
Write-LintHeader 'Stage 2: PSScriptAnalyzer'
$analyzer = Get-Module PSScriptAnalyzer -ListAvailable | Select-Object -First 1
if (-not $analyzer) {
    Write-Host 'SKIP PSScriptAnalyzer not installed (Install-Module PSScriptAnalyzer -Scope CurrentUser)' -ForegroundColor Yellow
    exit 0
}
Import-Module PSScriptAnalyzer -Force
$settingsPath = Join-Path $PSScriptRoot 'analyzer.settings.psd1'
$results = @(Invoke-ScriptAnalyzer -Path $script:RepoRoot -Recurse -Settings $settingsPath -ErrorAction SilentlyContinue)

$errors   = @($results | Where-Object Severity -eq 'ParseError')
$errors  += @($results | Where-Object { $_.Severity -eq 'Error' })
$warnings = @($results | Where-Object Severity -eq 'Warning')
$info     = @($results | Where-Object Severity -eq 'Information')

foreach ($r in $errors) {
    Write-Host ("  ERROR {0}:{1} [{2}] {3}" -f $r.ScriptPath.Substring($script:RepoRoot.Length + 1), $r.LineNumber, $r.RuleName, $r.Message) -ForegroundColor Red
}
foreach ($r in $warnings) {
    Write-Host ("  warn  {0}:{1} [{2}] {3}" -f $r.ScriptPath.Substring($script:RepoRoot.Length + 1), $r.LineNumber, $r.RuleName, $r.Message) -ForegroundColor Yellow
}

if ($errors.Count -gt 0) {
    Write-Host ("FAIL {0} analyzer error(s), {1} warning(s)" -f $errors.Count, $warnings.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("PASS analyzer clean ({0} warning(s), {1} info)" -f $warnings.Count, $info.Count) -ForegroundColor Green
exit 0
