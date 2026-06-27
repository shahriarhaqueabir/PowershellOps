# Hawkward Hybrid — Architecture

## Overview

```
Microsoft.PowerShell_profile.ps1
        │
        └─ Import-Module HawkwardHybrid.psd1
                │
                └─ HawkwardHybrid.psm1
                        ├─ Initialize-HawkProfile     ← entry point called by profile
                        │       ├─ Import-HawkPrerequisites
                        │       ├─ Set-HawkReadLine
                        │       ├─ Set-HawkAliases
                        │       ├─ Set-HawkPrompt
                        │       └─ Show-HawkDashboard  (interactive sessions only)
                        │
                        ├─ SENTINEL suite
                        │       ghostaudit / susaudit / fwaudit / taskaudit / bootmap / secretredact
                        │
                        ├─ DIAGNOSTICS suite
                        │       hawkdoctor / aidoctor / evntmap / evntaudit / diskaudit / resmap
                        │
                        ├─ ENVIRONMENT suite
                        │       fwmap / envmap / pathaudit / portmap / nettriage
                        │
                        ├─ AI & WORKSPACE suite
                        │       ai / ggl / projaudit / proj / hawkreport / dash / reload / hawkman
                        │
                        └─ REPORT ENGINE
                                New-HawkReport → ConvertTo-HawkReportMarkdown → Reports/*.md
```

## Data Flow: Web-to-AI Pipeline

```
ggl "query" -AI
     │
     ├─ POST https://lite.duckduckgo.com/lite/
     │        │
     │        └─ Extract result-link hrefs
     │                │
     │                └─ Resolve DuckDuckGo redirect URLs
     │
     ├─ Invoke-WebRequest each URL (up to 10 successful reads)
     │        ├─ Strip <style>, <script>, HTML tags
     │        └─ Truncate to 3000 chars per source
     │
     └─ POST http://127.0.0.1:11434/api/generate  (streaming)
               Model: HawkPowershell
              Prompt: Instruction + aggregated source content
              Response: streamed token-by-token to console
```

## Design Decisions

| Principle | Rationale |
|---|---|
| **All logic in `.psm1`; profile is only a loader** | Thin loader means the profile never breaks; the module is independently testable |
| **Module manifest (`.psd1`)** | Enables versioning, dependency declarations, and `Export-ModuleMember` control |
| **Prefix every function with `Hawk`** | Prevents collisions with system cmdlets; predictable tab-completion (`Get-Hawk<Tab>`) |
| **Short aliases in `Set-HawkAliases`** | Users type `ghostaudit`, not `Get-HawkGhostPortAudit`; aliases live in one place |
| **`$script:` scope for module state** | Prevents globals leaking out |
| **`$global:` only for user-facing config** | `$global:HawkProjectRoot` is intentionally global for any script to reference |

## Known Limitations

- **Windows only** — relies on `Get-NetFirewallRule`, `Get-WinEvent`, CIM/WMI, and registry paths
- **Admin recommended** — some registry and firewall cmdlets return limited results in non-admin sessions
- **Nerd Font required** — dashboard icons and Git prompt symbols need a [Nerd Font](https://www.nerdfonts.com)
- **Ollama must be running** — AI features degrade with a clear warning if Ollama is unreachable on `127.0.0.1:11434`
- **Web-to-AI** uses DuckDuckGo Lite — results depend on DDG availability
