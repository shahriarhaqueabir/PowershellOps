<div align="center">

# 🦅 Hawkward Hybrid

**PowerShell 7 Ops Toolkit** — Security auditing, system diagnostics, local AI via Ollama, and a live dashboard.  
All in your terminal. 100% offline. No telemetry. No cloud.

[![PowerShell 7.0+](https://img.shields.io/badge/PowerShell-7.0%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows_10%2F11-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com)
[![AI Engine](https://img.shields.io/badge/AI-Ollama_(local)-8A2BE2?logo=ollama&logoColor=white)](https://ollama.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-11.2-orange)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](#contributing)

---

**95 exported functions · 60+ aliases · 4 consolidated dispatch verbs**  
Load time: ~137ms (module) · ~2.3s (full profile)

</div>

---

## ✨ What You Get

- **🔍 Security audit suite** — port maps, firewall rules, startup persistence, scheduled tasks, suspicious processes, credential redaction
- **🖥️ System diagnostics** — CPU/RAM/disk, event logs, network listeners, battery health, display info, driver validation
- **🤖 Local AI pipeline** — pipe any command output into Ollama for instant analysis; web-to-AI search via DuckDuckGo
- **📊 Full-screen dashboard** — renders on session start with all commands organized into category grids
- **🎯 Short aliases** — type `audit`, `net`, `ghostaudit`, `dash` — never type long cmdlet names again
- **📄 Report generator** — snapshot your entire system to a timestamped Markdown or JSON file

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version | Install |
|---|---|---|
| PowerShell | **7.0+** | [Download](https://github.com/PowerShell/PowerShell/releases) |
| Git | Any | [Download](https://git-scm.com) |
| Ollama | Latest | [Download](https://ollama.com) *(optional — AI only)* |
| Nerd Font | Any | [Nerd Fonts](https://www.nerdfonts.com) *(for icons)* |

### 1. Clone

```powershell
git clone https://github.com/shahriarhaqueabir/PowershellOps.git "$HOME\Documents\PowerShell"
```

> If `$HOME\Documents\PowerShell` already exists, clone elsewhere and copy files across.

### 2. Install dependencies

```powershell
Import-Module "$HOME\Documents\PowerShell\Modules\HawkwardHybrid\HawkwardHybrid.psd1" -Force
Install-HawkPrerequisite
```

Installs: `Terminal-Icons`, `PSReadLine`, `PSTree`.

### 3. Wire the profile

```powershell
Copy-Item ".\Microsoft.PowerShell_profile.ps1" $PROFILE.CurrentUserCurrentHost -Force
```

### 4. (Optional) Set up AI

```powershell
ollama create HawkPowershell -f .\AI\HawkPowershell.modelfile
aidoctor    # verify it works
```

### 5. Reload

```powershell
reload
```

The dashboard appears automatically on every new session.

---

## 🎮 Dashboard Preview

```
╭──────────────────────────────────────────────────────────────────────╮
│ 🦅 HAWKWARD HYBRID 11.2 · ALL COMMANDS                               │
├──────────────────────────────────────────────────────────────────────┤
│ AI: ACTIVE    |    Workspace: E:\Projects                            │
╰──────────────────────────────────────────────────────────────────────╯

🖥️ SYSTEM (9)       🛡️ SECURITY (10)       🌐 NETWORK (8)       ⚙️ ENV (6)
─────────────       ───────────────       ──────────────       ──────────
health              ghostaudit             nettriage             envmap
spec                susaudit               netcheck              pathaudit
uptime              fwaudit                wifi                  proj
ram                 taskaudit              dnsbench              driveraudit
disk                bootmap                linkspeed             patch
battery             evntaudit              share                 app
ports               shield                 hostscheck
display             certs                  dnscache
hog                 dump
                    admin
                    secretredact
```

---

## 📋 Command Reference

Every command is accessible through a short alias. Full reference in [`MANUAL.md`](MANUAL.md).

### 🖥️ System

| Alias | Function | What It Does |
|---|---|---|
| `health` | `Get-HawkHealth` | CPU load, RAM free, process count, module checks |
| `spec` | `Get-HawkSpec` | Hardware summary (CPU, GPU, RAM) |
| `ports` | `Get-HawkPortMap` | All TCP listeners with owning process |
| `hog` | `Get-HawkResourceMap` | Top 10 processes by RAM/CPU |
| `ram` | `Get-HawkRamInfo` | RAM slots, speed, capacity |
| `disk` | `Get-HawkDiskPressureAudit` | Drive usage % by volume |

### 🛡️ Security

| Alias | Function | What It Does |
|---|---|---|
| `ghostaudit` | `Get-HawkGhostPortAudit` | Orphaned TCP listeners |
| `susa udit` | `Get-HawkSuspiciousProcessAudit` | Processes in AppData/Temp |
| `fwaudit` | `Get-HawkFirewallAudit` | Open ports vs. firewall rules |
| `taskaudit` | `Get-HawkScheduledTaskRiskAudit` | Risky scheduled tasks |
| `bootmap` | `Get-HawkBootMap` | Registry startup persistence |
| `shield` | `Get-HawkShield` | Security posture overview |
| `secretredact` | `Protect-HawkSensitiveText` | Redact secrets from output |

### 🌐 Network

| Alias | Function | What It Does |
|---|---|---|
| `nettriage` | `Get-HawkNetworkTriage` | Port + PID + process + firewall rule |
| `netcheck` | `Get-HawkNetCheck` | Connectivity to common endpoints |
| `dnsbench` | `Get-HawkDnsBench` | DNS resolver benchmarks |
| `hostscheck` | `Get-HawkHostsCheck` | Suspicious hosts file entries |

### ⚙️ Environment

| Alias | Function | What It Does |
|---|---|---|
| `envmap` | `Get-HawkEnvMap` | Env variable audit (auto-redacts secrets) |
| `pathaudit` | `Get-HawkPathAudit` | Validates every $env:Path entry |
| `proj` | `Get-HawkProject` | Jump to project root / list Git repos |
| `patch` | `Get-HawkPatchHistory` | Windows update history |

### 🤖 AI & Workspace

| Alias | Function | What It Does |
|---|---|---|
| `ai` | `Invoke-HawkAI` | Pipe command output to Ollama for analysis |
| `ggl` | `Invoke-HawkSearch` | Web search; add `-AI` for web-to-AI synthesis |
| `remember` | `Add-HawkMemory` | Save notes, preferences, runbooks |
| `recall` | `Search-HawkMemory` | Search saved memory |
| `hawkreport` | `New-HawkReport` | Full system snapshot → Markdown/JSON |
| `dash` | `Show-HawkDashboard` | Re-render the dashboard |

---

## 🤖 AI Features

**Local and private.** All inference runs on your machine via Ollama. No data leaves your PC.

```powershell
# Analyze system state
hog | ai "Which processes consume the most memory and why?"

# Web-to-AI search (scrapes top results, synthesizes an answer)
ggl "powershell firewall best practices" -AI

# Save context for future AI calls
remember "Prefer fast answers unless I ask for deep analysis." -Type preference -Pinned
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full data flow.

---

## 🗂️ Repository Structure

```
PowerShell/
├── Microsoft.PowerShell_profile.ps1     ← Profile bootstrap (thin loader)
├── Modules/HawkwardHybrid/
│   ├── HawkwardHybrid.psm1              ← Main module (~1550 lines)
│   └── HawkwardHybrid.psd1              ← Module manifest (v11.2)
├── AI/                                  ← Ollama model files
├── Scripts/                             ← PSResourceGet metadata
├── Reports/                             ← Generated snapshots (gitignored)
├── docs/
│   ├── ARCHITECTURE.md                  ← Design decisions & data flow
│   └── PROJECT_LOG.md                   ← Development history
└── MANUAL.md                            ← Full command reference
```

---

## ⚙️ Configuration

| Variable | Default | Description |
|---|---|---|
| `$HawkDefaultProjectRoot` | `E:\Projects` | `proj` jump target |
| `$env:HAWK_NO_DASH` | *(unset)* | Set any value to suppress the dashboard |
| `$env:CI` | *(unset)* | Auto-suppresses dashboard in CI |

```powershell
Initialize-HawkProfile -ProjectRoot 'D:\Work' -ShowDashboard
```

---

## 🔒 Security

- **`secretredact`** auto-masks values matching: `secret`, `token`, `password`, `credential`, `apikey`, `privatekey`
- AI runs **100% locally** via Ollama — no data leaves your machine
- Dashboard and interactive features are **suppressed in CI and redirected-output sessions**
- Non-admin sessions show warnings when registry access is limited

---

## 🧩 Dependencies

Managed by `Install-HawkPrerequisite`:

| Module | Purpose |
|---|---|
| [`Terminal-Icons`](https://github.com/devblackops/Terminal-Icons) | File/folder icons |
| [`PSReadLine`](https://github.com/PowerShell/PSReadLine) | IntelliSense history prediction |
| [`PSTree`](https://github.com/santisq/PSTree) | Tree-view directory display |

---

## 🤝 Contributing

Contributions are welcome! See [`MANUAL.md`](MANUAL.md) for the full command reference, then:

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-thing`
3. Keep functions in the `Verb-HawkNoun` naming pattern
4. Add an alias in `Set-HawkAliases` and a dashboard entry in `Show-HawkDashboard`
5. Run `Invoke-HawkBuild.ps1` (requires PSScriptAnalyzer + Pester)
6. Open a pull request

---

## 📜 License

MIT © 2026 [Shahryar](https://github.com/shahriarhaqueabir). See [`LICENSE`](LICENSE).

---

<div align="center">
  <sub>Built entirely in PowerShell 7 · Runs on your machine · No telemetry · No cloud</sub>
  <br>
  <a href="#-hawkward-hybrid">↑ Back to top</a>
</div>
