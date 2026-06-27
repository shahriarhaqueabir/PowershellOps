# ── Fix Talon.psd1 ────────────────────────────────────────────
# The generator piped a hashtable to Set-Content, producing
# "System.Collections.Hashtable" instead of the manifest text.
# Fix: rewrite as a here-string (text), not a hashtable.

$talonDir = "C:\Users\shahr\Documents\PowerShell\Talon"

$manifest = @'
@{
    RootModule        = 'Talon.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Talon Contributors'
    CompanyName       = 'Talon'
    Copyright         = '(c) 2026 Talon Contributors. MIT License.'
    Description       = 'Talon - featherweight PowerShell 7 ops shell with 50 diagnostic + AI commands.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Initialize-Talon', 'Set-TalonPrompt', 'Set-TalonAliases',
        'Update-TalonProfile', 'Test-InteractiveSession', 'Show-TalonDashboard',
        'Invoke-TalonCachedData', 'Write-TalonHeader'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('powershell', 'diagnostics', 'security', 'ollama', 'ai', 'windows')
            ProjectUri = 'https://github.com/talon-ps/talon'
            LicenseUri = 'https://github.com/talon-ps/talon/blob/main/LICENSE'
        }
    }
}
'@

$manifest | Set-Content (Join-Path $talonDir 'Talon.psd1') -Encoding UTF8

# Verify
$content = Get-Content (Join-Path $talonDir 'Talon.psd1') -Raw
Write-Host "PSD1 length: $($content.Length) bytes"
if ($content -match 'RootModule') {
    Write-Host "OK: PSD1 contains RootModule and other keys" -ForegroundColor Green
} else {
    Write-Host "FAIL: PSD1 still wrong" -ForegroundColor Red
    Write-Host "Content: $content"
}
