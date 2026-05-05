# Hawkward Sentinel — GitHub Project Details

## Project Description (for GitHub repository settings)

> A battle-hardened PowerShell 7 ops toolkit — Sentinel Edition. Security auditing, system diagnostics, local AI pipeline via Ollama, and a full-screen dashboard. Everything accessed through short memorable aliases. No cloud dependencies.

## Repository Topics / Tags

```
powershell  powershell-profile  terminal  ollama  local-ai  security  diagnostics
windows  windows11  sysadmin  devops  productivity  nerd-fonts  psreadline
```

## Short Bio (for the GitHub "About" sidebar)

```
🦅 PowerShell 7 profile — Sentinel Edition. Security audits, system diagnostics,
local AI via Ollama, and a responsive dashboard. 100% offline. No telemetry.
```

---

## Release History

| Version | Highlights |
|---|---|
| **11.2** | Hardened firewall audit, streaming AI engine, event storm detection, Git prompt cache |
| **11.1** | Web-to-AI pipeline (`ggl -AI`), Nerd Font dashboard icons, registry scraper fix |
| **11.0** | Module-backed architecture (`.psm1` / `.psd1`), alias system, report generator |
| **< 11** | Single-file monolith profile era |

---

## Planned Enhancements

- [ ] `Update-HawkModule` — one-command self-update via `git pull`
- [ ] Pester test suite for all audit functions
- [ ] `Watch-HawkDashboard` — live auto-refreshing dashboard mode
- [ ] JSON schema for `hawkreport` output to enable diff-over-time comparisons
- [ ] SSH / remote host support for running audits against remote machines

---

## Known Limitations

- **Windows only** — relies on `Get-NetFirewallRule`, `Get-WinEvent`, `CimInstance Win32_LogicalDisk`, and registry paths
- **Admin recommended** — some registry and firewall cmdlets return limited results in non-admin sessions (a warning is shown automatically)
- **Nerd Font required** — dashboard icons and Git prompt symbols require a [Nerd Font](https://www.nerdfonts.com) installed and selected in your terminal
- **Ollama must be running** — AI features gracefully degrade with a clear warning if Ollama is not reachable on `127.0.0.1:11434`
- **Web-to-AI** uses DuckDuckGo Lite — results depend on DDG availability and may vary

---

## Architecture Overview

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

---

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
              Model: hawk-reasoning
              Prompt: Instruction + aggregated source content
              Response: streamed token-by-token to console
```
