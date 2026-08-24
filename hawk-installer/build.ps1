# build.ps1 — refresh the bundled payload from this machine's live Hawk setup.
# The installer ships copies of: the HawkwardHybrid module (.psm1 + .psd1), and
# a profile template. This script re-copies them so `hawk-installer` always
# ships the current, working versions.
#
# Module files are copied byte-exact (Copy-Item) — safe for UTF-8 multibyte
# content. The profile template is regenerated from the live profile with the
# installer-managed documentation comments applied.
#
param(
    # -Stage assembles a clean release payload under ..\build\PowershellOps (installer tree minus dev tools).
    [switch]$Stage
)

# Usage:  pwsh -NoLogo -File build.ps1 [-Stage]

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot                                        # hawk-installer/
$src  = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'   # live PS7 home

# --- module (recursive dir sync: entry psm1 + manifest + dot-sourced domain files) ---
$repoModule = Join-Path $root 'modules\HawkwardHybrid'
$liveModule = Join-Path $src 'Modules\HawkwardHybrid'
if (-not (Test-Path -LiteralPath $liveModule)) { throw "Missing live module dir: $liveModule" }
Copy-Item -Path (Join-Path $liveModule '*') -Destination $repoModule -Recurse -Force
Get-ChildItem -LiteralPath $repoModule -File | Sort-Object Name | ForEach-Object {
    Write-Host ("Synced {0} -> repo ({1} bytes)" -f $_.Name, $_.Length)
}

# --- profile template: live profile + installer-managed doc comments ---
$live = Join-Path $src 'Microsoft.PowerShell_profile.ps1'
$template = Join-Path $root 'profile\Microsoft.PowerShell_profile.ps1'
if (-not (Test-Path -LiteralPath $live)) { throw "Missing source profile: $live" }
$text = [System.IO.File]::ReadAllText($live, [System.Text.Encoding]::UTF8)

if (-not $text.Contains('(installer-managed template)')) {
    $text = $text -replace [regex]::Escape('merged system'), 'merged system (installer-managed template)'
}
$text = $text -replace [regex]::Escape('HawkwardHybrid v11.2 (Sentinel Edition) — primary system'), 'HawkwardHybrid — primary system'
$text = $text -replace [regex]::Escape('HawkwardHybrid v11.2'), 'HawkwardHybrid'   # merge line (line 4)

$anchor = '# --- HawkwardHybrid — primary system ---'
$note = "# projectRoot comes from hawk.config.json (read at module import with`n# fallback to the module default); no explicit -ProjectRoot needed here."
if ($text.Contains($anchor)) {
    if (-not $text.Contains('# projectRoot comes from hawk.config.json')) {
        $text = $text.Replace($anchor, "$note`n$anchor")
    }
} else {
    throw 'Template regeneration: Phase 2 anchor not found in live profile'
}

foreach ($must in @('installer-managed template', '# projectRoot comes from hawk.config.json')) {
    if (-not $text.Contains($must)) { throw "Template regeneration mismatch: missing '$must'" }
}
if ($text.Contains('v11.2')) { throw 'Template still contains version marker v11.2' }

[System.IO.File]::WriteAllText($template, $text, [System.Text.UTF8Encoding]::new($false))
Write-Host ("Template regenerated -> {0} ({1} bytes)" -f $template, (Get-Item -LiteralPath $template).Length)

# --- build integrity: bundled hybrid module parses, imports, and matches its manifest ---
Write-Host "`nVerifying bundled hybrid module..."
$errs = $null
$hybridPsm1 = Join-Path $root 'modules\HawkwardHybrid\HawkwardHybrid.psm1'
$hybridPsd1 = Join-Path $root 'modules\HawkwardHybrid\HawkwardHybrid.psd1'
[System.Management.Automation.Language.Parser]::ParseFile($hybridPsm1, [ref]$null, [ref]$errs) | Out-Null
if ($errs) { throw "Bundled module parse errors: $($errs.Count)" }
Import-Module $hybridPsm1 -Force
# NOTE: plain `Get-Command -Module X` silently OMITS module-exported aliases;
# always enumerate with explicit -CommandType.
$psm1Fns     = @(Get-Command -Module HawkwardHybrid -CommandType Function | ForEach-Object Name)
$psm1Aliases = @(Get-Command -Module HawkwardHybrid -CommandType Alias    | ForEach-Object Name)
Remove-Module HawkwardHybrid -ErrorAction SilentlyContinue
if ($psm1Fns.Count -lt 48) { throw "Expected >= 48 public functions, got $($psm1Fns.Count)" }
$manifest = Import-PowerShellDataFile -Path $hybridPsd1
$missingFns     = @($psm1Fns     | Where-Object { $_ -notin @($manifest.FunctionsToExport) })
$missingAliases = @($psm1Aliases | Where-Object { $_ -notin @($manifest.AliasesToExport) })
$staleFns       = @(@($manifest.FunctionsToExport) | Where-Object { $_ -notin $psm1Fns })
$staleAliases   = @(@($manifest.AliasesToExport)   | Where-Object { $_ -notin $psm1Aliases })
if ($missingFns.Count)     { throw "Manifest drift: psm1 functions missing from psd1 FunctionsToExport: $($missingFns -join ', ')" }
if ($missingAliases.Count) { throw "Manifest drift: psm1 aliases missing from psd1 AliasesToExport: $($missingAliases -join ', ')" }
if ($staleFns.Count)       { throw "Manifest drift: psd1 FunctionsToExport entries with no live function: $($staleFns -join ', ')" }
if ($staleAliases.Count)   { throw "Manifest drift: psd1 AliasesToExport entries with no live alias: $($staleAliases -join ', ')" }
Write-Host "Bundled module imports OK: $($psm1Fns.Count) functions, $($psm1Aliases.Count) aliases; psd1 export parity OK (both directions)"

Write-Host "`nbuild.ps1 complete — bundled payload is current."

# --- optional release staging ---
if ($Stage) {
    $repo = Split-Path $root -Parent
    $stageRoot = Join-Path $repo 'build\PowershellOps'
    if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
    foreach ($item in @('install.ps1', 'vars.ps1', 'steps', 'lib', 'profile', 'modules')) {
        Copy-Item -LiteralPath (Join-Path $root $item) -Destination $stageRoot -Recurse -Force
    }
    foreach ($doc in @('MANUAL.md', 'README.md')) {
        Copy-Item -LiteralPath (Join-Path $repo $doc) -Destination $stageRoot -Force
    }
    $files = @(Get-ChildItem -LiteralPath $stageRoot -Recurse -File)
    Write-Host ("Staged release payload -> {0} ({1} files)" -f $stageRoot, $files.Count)
}