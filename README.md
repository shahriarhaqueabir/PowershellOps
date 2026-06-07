# 🦅 Hawkward Hybrid

**Hawkward Hybrid turns your PowerShell 7 terminal into a fully-loaded ops toolkit** focused on auditing Windows security and monitoring system health. Integrated with a private local AI right in the terminal, tuned to the PowerShell 7 environment and also able to synthesise answers straight from the web using duckduckgo search. A live dashboard with tooltips and guides walks you through capabilities that security teams pay thousands for. All built into your profile — custom, free, offline, and completely private.

> **A battle-hardened PowerShell 7 profile — Ops Toolkit**  
> Security auditing · System diagnostics · Local AI integration · Developer workspace tooling

[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7.0%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?logo=windows)](https://www.microsoft.com)
[![AI](https://img.shields.io/badge/AI-Ollama%20(local)-8A2BE2?logo=ollama)](https://ollama.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-11.2-orange)](#)

---

## ✨ What Is This?

Hawkward Hybrid is a **custom PowerShell 7 module and profile** that transforms a plain terminal into a self-contained ops toolkit. It ships with:

- A **full-screen dashboard** that renders on every session startup
- A **multi-layer security audit suite** covering ports, firewall, startup persistence, scheduled tasks, and suspicious processes  
- **Real-time system diagnostics** for disk, CPU/RAM, event logs, and network listeners  
- A **local AI pipeline** powered by Ollama — analyze data, answer questions, and run web-to-AI searches without sending data to the cloud
- A **customised prompt** showing OS, PS version, user, path, and live Git branch status  
- A **Markdown report generator** that snapshots the entire system state to a timestamped file

Everything is accessed through short, memorable **aliases** — no typing long cmdlet names.

---

## 🖥️ Dashboard Preview

```
  ╭──────────────────────────────────────────────────────────────────────────╮
  │ 🦅 HAWKWARD HYBRID 11.2 · ALL COMMANDS                                   │
  ├──────────────────────────────────────────────────────────────────────────┤
  │ AI: ACTIVE    |    Workspace: E:\Projects                                │
  ╰──────────────────────────────────────────────────────────────────────────╯

  🖥️ SYSTEM (9)       🛡️ SECURITY (10)       🌐 NETWORK (8)       ⚙️ ENV & APPS (6)
  ─────────────       ───────────────       ──────────────       ────────────────
  Get-HawkHealth      Get-HawkBootMap        Get-HawkNetCheck      Get-HawkApp
  Get-HawkSpec        Get-HawkCert           Get-HawkWifi          Get-HawkEnvMap
  Get-HawkUptime      Get-HawkDump           Get-HawkDnsBench      Get-HawkPathAudit
  Get-HawkRamInfo     Get-HawkFirewallAudit  Get-HawkLinkSpeed     Get-HawkProject
  Get-HawkBattery     Get-HawkGhostPortAudit Get-HawkShare         Get-HawkDriverAudit
  Get-HawkDisplay     Get-HawkScheduled...   Get-HawkHostsCheck    Get-HawkPatchHistory
  Get-HawkDiskPres..  Get-HawkSuspicious..   Get-HawkDnsCache
  Get-HawkResourceMap Get-HawkShield         Get-HawkNetworkTri..
  Get-HawkPortMap     Get-HawkAdmin
                      Get-HawkEventStorm..
```

### Short Aliases

| Alias | Points To | Alias | Points To |
|---|---|---|---|
| `sys` | Get-HawkSystem | `health` | Get-HawkSystem Health |
| `audit` | Get-HawkAudit | `net` | Get-HawkNetwork |
| `env` | Get-HawkEnv | `ai` | Invoke-HawkAI |
| `ggl` | Invoke-HawkSearch | `recall` | Search-HawkMemory |
| `remember` | Add-HawkMemory | `memmap` | Get-HawkMemoryMap |
| `dash` | Show-HawkDashboard | `reload` | Update-HawkProfile |
| `hawkreport` | New-HawkReport | `hawkman` | Show-HawkManual |
| `ports` | Get-HawkPortMap | `hog` | Get-HawkResourceMap |
| `spec` | Get-HawkSpec | `etc.` | ... |

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version | Install |
|---|---|---|
| PowerShell | 7.0+ | [Download](https://github.com/PowerShell/PowerShell/releases) |
| Git | Any | [Download](https://git-scm.com) |
| Ollama | Latest | [Download](https://ollama.com) *(optional — for AI features)* |
| Nerd Font | Any | [Nerd Fonts](https://www.nerdfonts.com) *(for icons)* |

### 1 — Clone the repository

```powershell
git clone https://github.com/YOUR_USERNAME/hawkward-hybrid.git "$HOME\Documents\PowerShell"
```

> **Note:** If your `$HOME\Documents\PowerShell` folder already exists, clone to a temp location and copy the contents across manually.

### 2 — Install module dependencies

Open PowerShell 7 and run:

```powershell
Import-Module "$HOME\Documents\PowerShell\Modules\HawkwardHybrid\HawkwardHybrid.psd1" -Force
Install-HawkPrerequisite
```

This installs: `Terminal-Icons`, `PSReadLine`, `PSTree`.

### 3 — Wire up the profile

The profile bootstrap is already at `Microsoft.PowerShell_profile.ps1`. Verify the path PowerShell expects:

```powershell
$PROFILE.CurrentUserCurrentHost
```

If it points somewhere else, symlink or copy the file:

```powershell
Copy-Item ".\Microsoft.PowerShell_profile.ps1" $PROFILE.CurrentUserCurrentHost -Force
```

### 4 — (Optional) Set up local AI with Ollama

```powershell
# Install and run Ollama, then create the custom HawkPowershell model:
ollama create HawkPowershell -f .\AI\HawkPowershell.modelfile

# Verify it's working:
aidoctor
```

### 5 — Reload your profile

```powershell
reload
```

The dashboard will appear on every new session automatically.

---

## 📋 Command Reference

### 🖥️ System — Health & Diagnostics

| Alias | Full Function | What It Does |
|---|---|---|
| `health` | `Get-HawkHealth` | Profile check, module availability, project root, Ollama status |
| `spec` | `Get-HawkSpec` | Hardware and system specification summary |
| `uptime` | `Get-HawkUptime` | System boot time and uptime duration |
| `ram` | `Get-HawkRamInfo` | RAM usage, slots, and capacity details |
| `battery` | `Get-HawkBattery` | Battery status, charge level, and health |
| `display` | `Get-HawkDisplay` | Connected displays, resolution, and adapter info |
| `diskaudit` | `Get-HawkDiskPressureAudit` | Disk usage by drive with free space percentage |
| `hog` | `Get-HawkResourceMap` | Top 10 processes by RAM/CPU consumption |
| `ports` | `Get-HawkPortMap` | All TCP listeners with owning process and company name |

### 🛡️ Security — Audits & Persistence

| Alias | Full Function | What It Does |
|---|---|---|
| `ghostaudit` | `Get-HawkGhostPortAudit` | Detects orphaned TCP listeners with no owning process |
| `susaudit` | `Get-HawkSuspiciousProcessAudit` | Flags processes running from `AppData` or `Temp` |
| `fwaudit` | `Get-HawkFirewallAudit` | Cross-references open ports against inbound firewall allow rules |
| `taskaudit` | `Get-HawkScheduledTaskRiskAudit` | Finds scheduled tasks invoking `powershell`, `cmd`, or temp paths |
| `bootmap` | `Get-HawkBootMap` | Scrapes `HKLM` and `HKCU` Run registry keys for startup persistence |
| `evntaudit` | `Get-HawkEventStormAudit` | Detects event storms (>5 occurrences in a 30-minute window) |
| `shield` | `Get-HawkShield` | Security posture overview and hardening suggestions |
| `certs` | `Get-HawkCert` | Enumerates certificates in trusted stores |
| `dump` | `Get-HawkDump` | Lists crash dump files and minidump locations |
| `admin` | `Get-HawkAdmin` | Local admin group membership and privileged users |
| `secretredact` | `Protect-HawkSensitiveText` | Redacts secrets, tokens, passwords, and keys from pipeline output |

### 🌐 Network — Connectivity & Diagnostics

| Alias | Full Function | What It Does |
|---|---|---|
| `nettriage` | `Get-HawkNetworkTriage` | Port + PID + process + matched firewall rule in one view |
| `netcheck` | `Get-HawkNetCheck` | Tests connectivity to common endpoints |
| `wifi` | `Get-HawkWifi` | Wi-Fi profile and signal strength details |
| `dnsbench` | `Get-HawkDnsBench` | Benchmarks DNS resolver response times |
| `linkspeed` | `Get-HawkLinkSpeed` | Network adapter link speed and status |
| `share` | `Get-HawkShare` | Lists active SMB shares and sessions |
| `hostscheck` | `Get-HawkHostsCheck` | Validates `hosts` file for suspicious entries |
| `dnscache` | `Get-HawkDnsCache` | DNS cache contents and statistics |

### ⚙️ Environment — State & Config

| Alias | Full Function | What It Does |
|---|---|---|
| `envmap` | `Get-HawkEnvMap` | Environment variable audit — auto-redacts sensitive names |
| `pathaudit` | `Get-HawkPathAudit` | Validates every `$env:Path` entry (missing, duplicate, empty) |
| `proj` | `Get-HawkProject` | Lists Git repos or cd to project root |
| `driveraudit` | `Get-HawkDriverAudit` | Checks driver signing status and known issues |
| `patch` | `Get-HawkPatchHistory` | Windows update history and pending reboots |
| `app` | `Get-HawkApp` | Lists installed applications and versions |

### 🤖 AI & Workspace

| Alias | Full Function | What It Does |
|---|---|---|
| `ai` | `Invoke-HawkAI` | Pipe any data to the local Ollama model for analysis |
| `ggl` | `Invoke-HawkSearch` | Search any engine in-browser, or add `-AI` for web-to-AI synthesis |
| `remember` | `Add-HawkMemory` | Save local preferences, runbooks, and useful notes |
| `recall` | `Search-HawkMemory` | Search local memory |
| `memmap` | `Get-HawkMemoryMap` | List recent or pinned memory entries |
| `hawkreport` | `New-HawkReport` | Full system snapshot → console table + timestamped Markdown file |
| `dash` | `Show-HawkDashboard` | Re-render the startup dashboard |
| `reload` | `Update-HawkProfile` | Dot-source the profile without restarting the terminal |
| `hawkman` | `Show-HawkManual` | Print the quick reference workflow guide |
| `audit` | `Get-HawkAudit` | Consolidated security audit dispatch |
| `sys` | `Get-HawkSystem` | Consolidated system info dispatch |
| `net` | `Get-HawkNetwork` | Consolidated network diagnostics dispatch |
| `env` | `Get-HawkEnv` | Consolidated environment dispatch |

---

## 🤖 AI Features In Depth

### Pipe anything to the local model

```powershell
# Analyze system resources
resmap | ai 'Which processes are consuming the most memory and why?'

# Redact secrets before sending to AI
envmap -IncludeSensitive | secretredact | ai 'Summarize the environment configuration.'

# Direct question
"Explain PSReadLine prediction modes" | ai

# Save a high-value preference for future AI calls
remember "Prefer fast answers unless I ask for deep analysis." -Type preference -Pinned

# Save a useful AI answer as session memory
resmap | ai "What is using the most memory?" -Remember
```

### Web-to-AI search synthesis

```powershell
# Opens a browser
ggl "powershell scheduled tasks best practices"

# Fetches top DuckDuckGo results, scrapes content, synthesizes with AI
ggl "powershell scheduled tasks best practices" -AI

# Default AI search is fast; use Deep when more sources matter
ggl "powershell scheduled tasks best practices" -AI -Deep

# Use a specific engine for browser search
ggl "windows firewall hardening" -Engine bing
```

### Custom AI model

The `AI/` directory contains Ollama `Modelfile`s for the `HawkPowershell` model. The model is configured to:

- Default to PowerShell 7 syntax
- Skip chain-of-thought reasoning output
- Be concise, practical, and efficient
- Respect the user's project root (`E:\Projects`)

---

## 📄 Report Generation

```powershell
# Console output + save Markdown to Reports/
hawkreport

# Export as Markdown only
hawkreport -Format Markdown -Path .\my-report.md

# Export as JSON
hawkreport -Format Json -Path .\my-report.json
```

Reports are saved to the `Reports/` directory as `hawkreport-YYYYMMDD-HHmmss.md`.

---

## 🗂️ Repository Structure

```
PowerShell/
├── Microsoft.PowerShell_profile.ps1   ← Profile bootstrap (loader)
│
├── Modules/
│   └── HawkwardHybrid/
│       ├── HawkwardHybrid.psm1        ← Main module (~1550 lines)
│       └── HawkwardHybrid.psd1        ← Module manifest (v11.2)
│
├── AI/
│   └── HawkPowershell.modelfile       ← HawkPowershell (LFM2.5-8B-A1B)
│
├── Reports/                           ← Auto-generated system snapshots (gitignored)
│
└── Scripts/
    └── InstalledScriptInfos/          ← PSResourceGet metadata (gitignored)
```

---

## ⚙️ Configuration

| Variable | Default | Description |
|---|---|---|
| `$HawkDefaultProjectRoot` | `E:\Projects` | Default `proj` jump target |
| `$HawkRequiredModules` | `Terminal-Icons, PSReadLine, PSTree` | Auto-imported on load |
| `$HawkReportRoot` | `<ProfileRoot>\Reports` | Where report files are saved |
| `$env:HAWK_NO_DASH` | *(unset)* | Set to any value to suppress the dashboard |
| `$env:CI` | *(unset)* | Automatically suppresses dashboard in CI environments |

To use a different project root:

```powershell
Initialize-HawkProfile -ProjectRoot 'D:\Work' -ShowDashboard
```

---

## 🔒 Security Notes

- **`secretredact`** / `Protect-HawkSensitiveText` automatically masks values for keys matching: `secret`, `token`, `password`, `passwd`, `pwd`, `credential`, `connectionstring`, `sas`, `bearer`, `apikey`, `privatekey`
- All AI inference runs **100% locally** via Ollama — no data leaves your machine
- Local memory is stored under `Memory/` as JSONL and ignored by git
- The profile detects non-admin sessions and warns when registry access may be limited
- The dashboard and interactive features are **suppressed in CI** (`$env:CI`) and redirected-output sessions automatically

---

## 🧩 Dependencies

These modules are managed by `Install-HawkPrerequisite`:

| Module | Purpose |
|---|---|
| [`Terminal-Icons`](https://github.com/devblackops/Terminal-Icons) | File/folder icons in directory listings |
| [`PSReadLine`](https://github.com/PowerShell/PSReadLine) | IntelliSense history prediction with `ListView` mode |
| [`PSTree`](https://github.com/santisq/PSTree) | Tree-view directory display |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-new-audit`
3. Keep functions in the `Verb-HawkNoun` naming pattern
4. Add an alias in `Set-HawkAliases` and a dashboard entry in `Show-HawkDashboard`
5. Test with `health` before submitting a PR

---

## 📜 License

MIT © 2026 shahr / Hawkward

---

<div align="center">
  <sub>Built in PowerShell 7 · Runs entirely on your machine · No telemetry · No cloud dependencies</sub>
</div>
