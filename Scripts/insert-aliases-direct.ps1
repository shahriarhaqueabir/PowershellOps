$psm1 = "C:\Users\shahr\Documents\PowerShell\Talon\Talon.psm1"
$content = Get-Content $psm1 -Raw

# Build the module-level alias block
$aliasBlock = @'

# ── ALIASES (created at module scope on import, exported via AliasesToExport) ──
Set-Alias -Scope Global -Name health       -Value Get-TalonHealth          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name spec         -Value Get-TalonSpec            -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name uptime       -Value Get-TalonUptime          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name disk         -Value Get-TalonDiskPressure    -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name hog          -Value Get-TalonResourceMap     -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name ports        -Value Get-TalonPortMap         -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name battery      -Value Get-TalonBattery         -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name temp         -Value Get-TalonTempCheck       -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name fwaudit      -Value Get-TalonFirewallAudit   -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name boot         -Value Get-TalonBootMap         -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name taskaudit    -Value Get-TalonScheduledTaskRisk -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name ghostaudit   -Value Get-TalonGhostPortAudit  -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name susaudit     -Value Get-TalonSuspiciousProcess -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name evntaudit    -Value Get-TalonEventStormAudit -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name admin        -Value Get-TalonAdmin           -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name netcheck     -Value Get-TalonNetCheck        -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name wifi         -Value Get-TalonWifi            -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name dnsbench     -Value Get-TalonDnsBench        -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name dnscache     -Value Get-TalonDnsCache        -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name nettriage    -Value Get-TalonNetworkTriage   -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name envmap       -Value Get-TalonEnvMap          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name pathaudit    -Value Get-TalonPathAudit       -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name app          -Value Get-TalonApp             -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name patch        -Value Get-TalonPatchHistory    -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name driveraudit  -Value Get-TalonDriverAudit     -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name ai           -Value Invoke-TalonAI           -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name ggl          -Value Invoke-TalonSearch       -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name secretredact -Value Protect-TalonSensitiveText -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name aistatus     -Value Get-TalonAIStatus        -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name injecttest   -Value Test-TalonPromptInjection -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name quality      -Value Get-TalonSourceQuality   -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name remember     -Value Add-TalonMemory          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name recall       -Value Search-TalonMemory       -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name memmap       -Value Get-TalonMemoryMap       -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name report       -Value New-TalonReport          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name dash         -Value Show-TalonDashboard      -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name reload       -Value Update-TalonProfile      -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name shield       -Value Get-TalonShield          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name certs        -Value Get-TalonCertCheck       -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name sys          -Value Get-TalonSystem          -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name audit        -Value Get-TalonAudit           -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name net          -Value Get-TalonNetwork         -Force -ErrorAction SilentlyContinue
Set-Alias -Scope Global -Name env          -Value Get-TalonEnv             -Force -ErrorAction SilentlyContinue

'@

# Insert after the $script:TalonConfig = $null line and before function Get-TalonConfig
$insertAfter = '$script:TalonConfig = $null'
$insertIndex = $content.IndexOf($insertAfter)
if ($insertIndex -ge 0) {
    $insertPoint = $insertIndex + $insertAfter.Length
    $newContent = $content.Substring(0, $insertPoint) + $aliasBlock + $content.Substring($insertPoint)

    # Remove the trailing "Set-TalonAliases" call we added earlier
    $newContent = $newContent -replace "`n# ── CREATE ALIASES AT MODULE LOAD ──────────────────────`nSet-TalonAliases`n", ''
    # Remove "Set-TalonAliases" call from Initialize-Talon (so no double-call)
    # Actually, keep it in Initialize-Talon for backward compat, since Set-Alias -Force overwrites
    # But change it to not use -Scope Global (aliases are already global from module load)
    $newContent = $newContent -replace 'Set-TalonAliases', '# Aliases created at module load'

    Set-Content -Path $psm1 -Value $newContent -Encoding UTF8 -Force
    Write-Host "Module-level alias block inserted. Set-TalonAliases call commented out in Initialize-Talon."
} else {
    Write-Host "Could not find insertion point."
}
