# Targeted ShouldProcess removal using string replacement
$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"
$psm1Path = Join-Path $talonDir 'Talon.psm1'

# Read as single string (preserve line endings)
$content = [System.IO.File]::ReadAllText($psm1Path)

# Pattern 1: Set-TalonAliases - remove SupportsShouldProcess and the guard
$patterns = @(
    @{
        Old = "function Set-TalonAliases {
    <#
    .SYNOPSIS
        Register all 50+ short aliases. Called once at startup.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not `$PSCmdlet.ShouldProcess('Global aliases', 'Set all Talon aliases')) { return }"
        New = "function Set-TalonAliases {
    <#
    .SYNOPSIS
        Register all 50+ short aliases. Called once at startup.
    #>
    [CmdletBinding()]
    param()"
    }
    @{
        Old = "function Set-TalonPrompt {
    <#
    .SYNOPSIS
        Install the Talon prompt function (replaces default prompt).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (`$PSCmdlet.ShouldProcess('global:prompt', 'Set custom prompt function')) {
        if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
            Set-Item -Path Function:\global:Prompt -Value {
                Get-TalonPromptText -LastSuccess:`
$?
            }
        }
    }
}"
        New = "function Set-TalonPrompt {
    <#
    .SYNOPSIS
        Install the Talon prompt function (replaces default prompt).
    #>
    [CmdletBinding()]
    param()
    if (-not (Get-Module oh-my-posh, posh-git -ErrorAction SilentlyContinue)) {
        Set-Item -Path Function:\global:Prompt -Value {
            Get-TalonPromptText -LastSuccess:`$?
        }
    }
}"
    }
    @{
        Old = "    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (`$PSCmdlet.ShouldProcess('PSReadLine options', 'Configure prediction settings')) {
        try {
            Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
        } catch { Write-Warning ""PSReadLine configuration failed: `$(`$_.Exception.Message)"" }
    }"
        New = "    [CmdletBinding()]
    param()
    try {
        Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
    } catch { Write-Warning ""PSReadLine configuration failed: `$(`$_.Exception.Message)"" }"
    }
    @{
        Old = "function Update-TalonProfile {
    <#
    .SYNOPSIS
        Dot-source the profile without restarting the terminal.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (`$PSCmdlet.ShouldProcess('`$PROFILE', 'Dot-source profile')) { . `$PROFILE }
}"
        New = "function Update-TalonProfile {
    <#
    .SYNOPSIS
        Dot-source the profile without restarting the terminal.
    #>
    [CmdletBinding()]
    param()
    . `$PROFILE
}"
    }
)

foreach ($p in $patterns) {
    $content = $content.Replace($p.Old, $p.New)
}

[System.IO.File]::WriteAllText($psm1Path, $content, [System.Text.Encoding]::UTF8)
Write-Host "Patched all ShouldProcess guards."

# Verify
$parentDir = "C:\Users\shahr\Documents\PowerShell"
$env:PSModulePath = "$parentDir;$env:PSModulePath"
Remove-Module Talon -ErrorAction SilentlyContinue
Remove-Module Talon.Commands -ErrorAction SilentlyContinue
try {
    Import-Module Talon -Force -ErrorAction Stop
    Write-Host "Import OK" -ForegroundColor Green

    $aliases = @('dash','reload','health','spec','disk','ports','admin','netcheck','app','ai')
    $count = 0
    foreach ($a in $aliases) { if (Get-Alias $a -ErrorAction SilentlyContinue) { $count++ } }
    Write-Host "Aliases registered: $count / $($aliases.Count)" -ForegroundColor Green

    # Test a function
    $h = Get-TalonHealth
    Write-Host "health works: CPU $($h.'CPU Load')" -ForegroundColor Cyan

} catch { Write-Host "FAIL: $_" -ForegroundColor Red }
