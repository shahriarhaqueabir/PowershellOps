# vars.ps1 — centralized version pins and constants for the Hawk installer.
# Dot-sourced by install.ps1 (both the PS 5.1 bootstrap and the PS 7 main body)
# and by the step scripts. Bumping a version is a one-line edit here.

# --- PowerShell 7 ---
$script:HawkPs7Version   = '7.6.5'
$script:HawkPs7WingetId  = 'Microsoft.PowerShell'
$script:HawkPs7MsiUrl    = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.5/PowerShell-7.6.5-win-x64.msi'

# --- llama.cpp ---
$script:HawkLlamaVersion     = 'b10217'
$script:HawkLlamaInstallUrl  = 'https://llama.app/install.ps1'

# --- Model ---
$script:HawkModelRepo  = 'unsloth/Qwen3-1.7B-GGUF'
$script:HawkModelQuant = 'Q4_K_M'
$script:HawkModelSpec  = "$($script:HawkModelRepo):$($script:HawkModelQuant)"
$script:HawkModelFile  = 'Qwen3-1.7B-Q4_K_M.gguf'

# --- Defaults (used when the machine config file is absent) ---
# Uses $env:USERPROFILE for portability across machines
$script:HawkDefaultProjectRoot = Join-Path $env:USERPROFILE 'Projects'
$script:HawkDefaultHfHome      = Join-Path $env:USERPROFILE 'Models\GGUF'
$script:HawkDefaultLlamaPort   = 8081