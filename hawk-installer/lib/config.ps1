# Config read/write helpers for the installer.
# Depends on lib/common.ps1 (Get-HawkTargetPath, Write-HawkLog).

function Read-HawkConfig {
    param([string]$Path = (Get-HawkTargetPath -Kind 'Config'))
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-HawkLog "Config at '$Path' unreadable: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Write-HawkConfig {
    param(
        [string]$Path = (Get-HawkTargetPath -Kind 'Config'),
        [hashtable]$Values
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Values | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-HawkLog "Config written to '$Path'" 'OK'
}