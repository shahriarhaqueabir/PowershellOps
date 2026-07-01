<div align="center">

# 🦅 Hawkward Hybrid

**PowerShell 7 Ops Toolkit** — Security auditing, system diagnostics, local AI via Ollama, and a live dashboard.  
All in your terminal. 100% offline. No telemetry. No cloud.

[![PowerShell 7.0+](https://img.shields.io/badge/PowerShell-7.0%2B-blue?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows_10%2F11-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com)
[![AI Engine](https://img.shields.io/badge/AI-Ollama_(local)-8A2BE2?logo=ollama&logoColor=white)](https://ollama.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-11.3-orange)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](#contributing)

---

**103 exported functions · 81 safe hawk-* aliases · 4 consolidated dispatch verbs · 7 scenario workflows**  
Load time: ~137ms (module) · ~2.3s (full profile)

</div>

---

## ✨ What You Get

- **🔍 Security audit suite** — port maps, firewall rules, startup persistence, scheduled tasks, suspicious processes, credential redaction
- **🖥️ System diagnostics** — CPU/RAM/disk, event logs, network listeners, battery health, display info, driver validation
- **🤖 Local AI pipeline** — pipe any command output into Ollama for instant analysis; web-to-AI search via DuckDuckGo
- **📊 Full-screen dashboard** — renders on session start with all commands organized into category grids
- **🔄 Scenario workflows** — 7 scored, color-coded diagnostic workflows: daily ops, system review, security audit, network diag, threat hunt, change audit, compliance
- **🎯 Safe aliases** — type `hawk-audit`, `hawk-net`, `hawk-ghostaudit`, `hawk-dash` without shadowing standard commands
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
hawk-ai "Verify the local model works"
```

### 5. Reload

```powershell
hawk-reload
```

The dashboard appears automatically on every new session.

---

## 🎮 Dashboard Preview

```
╭──────────────────────────────────────────────────────────────────────╮
│ 🦅 HAWKWARD HYBRID 11.3 · ALL COMMANDS                               │
├──────────────────────────────────────────────────────────────────────┤
│ AI: ACTIVE    |    Workspace: <derived from checkout or env>         │
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
                    admin                  🔄 WORKFLOWS (7)
                    secretredact           ─────────────
                                           dailyops
                                           sysreview
                                           secaudit
                                           netdiag
                                           threat
                                           change
                                           compliance
```

---

## 📋 Command Reference

Every command is accessible through a safe `hawk-*` alias. Full reference in [`MANUAL.md`](MANUAL.md).

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

### 🧠 Memory & Reports

| Alias | Function | What It Does |
|---|---|---|
| `remember` | `Add-HawkMemory` | Save notes, preferences, runbooks |
| `recall` | `Search-HawkMemory` | Search saved memory |
| `hawkreport` | `New-HawkReport` | Full system snapshot → Markdown/JSON |
| `dash` | `Show-HawkDashboard` | Re-render the dashboard |

### 🤖 AI & Search

| Alias | Function | What It Does |
|---|---|---|
| `ai` | `Invoke-HawkAI` | Pipe command output to Ollama for analysis |
| `ggl` | `Invoke-HawkSearch` | Web search; add `-AI` for web-to-AI synthesis, `-DryRun` to preview URLs, `-Sandbox` for background processing |

### 🔄 Workflows (v11.3)

| Alias | Function | What It Does |
|---|---|---|
| `dailyops` | `Invoke-HawkDailyOps` | Health + uptime + disk + network + events — scored daily operations scan |
| `sysreview` | `Invoke-HawkSystemReview` | Spec + RAM + CPU + disk + ports + temp + license — full hardware/performance review |
| `secaudit` | `Invoke-HawkSecurityAudit` | Defender + firewall + startup + tasks + admins + anomalies — scored security posture audit |
| `netdiag` | `Invoke-HawkNetworkDiagnostics` | Connectivity + DNS + interfaces + shares + hosts — scored network health check |
| `threat` | `Invoke-HawkThreatHunt` | Suspicious processes + ghost ports + file anomalies + event correlation + firewall gaps |
| `change` | `Invoke-HawkChangeAudit` | Recent files + updates + drivers + crash dumps + startup + certs — scored stability review |
| `compliance` | `Invoke-HawkComplianceCheck` | 9 CIS-inspired checks — admin count, defender, firewall, tasks, boot, patches, license, hypervisor, ports — pass/fail summary |

---

## 🤖 AI Features

**Local and private.** All inference runs on your machine via Ollama. No data leaves your PC.

```powershell
# Analyze system state
hawk-hog | hawk-ai "Which processes consume the most memory and why?"

# Web-to-AI search (scrapes top results, synthesizes an answer)
hawk-ggl "powershell firewall best practices" -AI

# Save context for future AI calls
hawk-remember "Prefer fast answers unless I ask for deep analysis." -Type preference -Pinned
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full data flow.

### What's New in v11.3

- **🔥 7 scenario-driven diagnostic workflows** — `dailyops`, `sysreview`, `secaudit`, `netdiag`, `threat`, `change`, `compliance` — each combines complementary single-purpose functions into a rich, color-coded, scored report with actionable recommendations
- **Scored summaries** — every workflow returns an overall score (0–100) with color-coded severity (🟢/🟡/🔴) and categorized recommendations
- **Data caching** — workflows share a cross-workflow cache via `Invoke-HawkCachedData` (per-key TTL), so repeated runs don't re-query expensive WMI data
- **CIS-inspired compliance check** — `compliance` runs 9 security baseline checks with pass/fail tally and percentage score
- **Stronger prompt injection guard** — `Test-HawkPromptInjection` now uses 4-layer detection: token-boundary keywords, encoded payloads (base64/hex/unicode), structural anomalies, and optional LLM-based heuristic via Ollama
- **`-DryRun` switch on `Invoke-HawkSearch`** — Preview which URLs would be scraped before making any requests
- **`-Sandbox` switch on `Invoke-HawkSearch`** — Spawns a detached background `Start-Job` process for isolated web scraping
- **First-run notice** — First-time users see a clear warning about aliases and prompt changes before loading
- **Legacy aliases removed** — 29 deprecated short names (e.g. `specs`, `ports`, `hog`) removed per the v12 deprecation plan. Use their `hawk-*` prefix equivalents instead.
- **All 103 functions verified** against latest PowerShell 7 documentation

---

## 🗂️ Repository Structure

```
PowerShell/
├── Microsoft.PowerShell_profile.ps1     ← Profile bootstrap (thin loader)
├── Modules/HawkwardHybrid/
│   ├── HawkwardHybrid.psm1              ← Main module (~1550 lines)
│   ├── HawkwardHybrid.psd1              ← Module manifest (v11.3)
│   ├── Public/
│   │   ├── *.ps1                        ← 70+ single-purpose functions
│   │   └── Workflows.ps1                ← 7 scenario workflows + display helpers
│   ├── Private/
│   │   └── *.ps1                        ← Internal helpers
│   └── Tests/
│       └── HawkwardHybrid.Tests.ps1     ← Pester test suite (78 tests)
├── AI/                                  ← Ollama model files
├── Scripts/                             ← PSResourceGet metadata
├── Reports/                             ← Generated snapshots (gitignored)
├── docs/
│   ├── ARCHITECTURE.md                  ← Design decisions & data flow
│   └── PROJECT_LOG.md                   ← Development history
└── MANUAL.md                            ← Full command reference (15 sections)
```

---

## ⚙️ Configuration

| Variable | Default | Description |
|---|---|---|
| `$HawkDefaultProjectRoot` | checkout/profile root or `$HAWK_PROJECT_ROOT` | `proj` jump target |
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

