<div align="center">

<img src="icon.png" alt="PowershellOps" width="110"/>

# PowershellOps

**Advanced Operational Intelligence & Universal AI Companion for Windows.**
*Private. High-Performance. Local Agentic Stack.*

[![PowerShell](https://img.shields.io/badge/PowerShell-7.6_LTS-0078D4?logo=powershell&logoColor=white)](#)
[![AI](https://img.shields.io/badge/AI-llama.cpp_(local)-8A2BE2?logo=llama&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-green)](#)
[![Status](https://img.shields.io/badge/Version-12.0.0-orange)](#)

**126 Functions · 90 Aliases · 7 Operational Workflows · Zero Cloud Dependencies**

</div>

<div align="center">
  <img src="showcase.png" alt="The PowershellOps dashboard: 90 operational tools organized across 11 color-coded suites" width="100%"/>
  <p><em>The live <strong>dash</strong> command center — every tool one keystroke away.</em></p>
</div>

---

## What is PowershellOps?

A professional **Agentic Stack** for Windows that turns the terminal into an Intelligent Companion Hub. It audits your system, diagnoses problems, and reasons over local context using a local LLM — everything stays inside your perimeter.

- 🤖 **Agentic workflows** — multi-step AI reasoning for system repair and data analysis
- 🎯 **Situational awareness** — time, date, and system load injected into every AI query
- 🛡️ **Security substrate** — firewall gaps, ghost ports, persistence vectors, Defender health
- 🔒 **100% private** — no telemetry, no cloud logging, local llama.cpp reasoning, auto-redaction of secrets

[Features](#whats-inside) • [Installation](#installation) • [Daily Flow](#your-day-with-powershellops) • [Hub](#the-companion-hub-hub) • [Workflows](#operational-workflows) • [Walkthrough](docs/AGENTIC-IDE-TUTORIAL.md)

---

## Installation

One line from **PowerShell 7**:

```powershell
irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/hawk-installer/install.ps1 | iex
```

*Requirements: PowerShell 7.2+, Git. Optional: llama.cpp + a local GGUF model for AI features. Piped invocations auto-download the installer bundle to `%TEMP%` and relaunch from disk.*

<details>
<summary><b>Manual installation (no installer)</b></summary>

```powershell
# 0. Source checkout
git clone https://github.com/shahriarhaqueabir/PowershellOps.git
cd PowershellOps\hawk-installer

# 1. Resolve the PS7 home (same paths the installer uses)
$psHome = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'

# 2. Module → user module path
New-Item -ItemType Directory -Force "$psHome\Modules\HawkwardHybrid" | Out-Null
Copy-Item .\modules\HawkwardHybrid\* "$psHome\Modules\HawkwardHybrid\" -Force

# 3. Profile template → $PROFILE  (replaces your profile — back it up first)
if (Test-Path $PROFILE) { Copy-Item $PROFILE "$PROFILE.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" }
Copy-Item .\profile\Microsoft.PowerShell_profile.ps1 $PROFILE -Force

# 4. User-scope dependencies
Install-Module Terminal-Icons, PSTree -Scope CurrentUser

# 5. Optional AI engine (llama.cpp + local GGUF), guided:
pwsh -NoProfile    # restart into the wired profile, then:
onboard -Apply
```

**Notes**

- Step 3 mirrors the installer's wiring step: it **replaces** `$PROFILE`. Merge your customizations back in from the `.bak-*` backup.
- Config persists to `~\Documents\PowerShell\hawk.config.json` and `hawk-settings.json` — created automatically on first run / onboarding.
- All targets are user-scoped; no admin rights required.

</details>

---

## Your day with PowershellOps

```powershell
hawkdaily            # morning brief: health, uptime, disk, network, events → scored report
dash                 # open the command center (screenshot above)

temps                # drill into anything you see on a tile...
shield
drivehealth

hub stat             # one-page pulse when something feels off
fix                  # feed the last PowerShell error to the local model for a concrete fix
resmap | ai "which process eats the most RAM?"   # pipeline any tool output into the LLM

hawkreport           # everything so far → timestamped markdown report
```

Every tile on the dashboard is an alias like the ones above — see the [alias index](#alias-index) below for all 90.

---

## What's inside

| Domain | Tools | Description |
|:---|:---|:---|
| 🤖 **AI & Workspace** | 13 | Local LLM chat, web search synthesis, model management, project navigation |
| 🛡️ **Security Audit** | 11 | Firewall gaps, ghost ports, persistence sweeps, Defender health, registry/IFEO scans |
| 🩺 **Diagnostics** | 5 | One-shot health views, stack health checks, integration tests, event mapping |
| 🌍 **Environment** | 6 | Firewall maps, env vars, PATH audit, port maps, network triage, boot maps |
| 🦙 **Llama Server** | 4 | Start/stop/status/doctor for the local llama.cpp server |
| 🖥️ **System Matrix** | 10 | CPU, RAM, battery, thermals, fans, displays, hypervisor, power, licensing |
| 🌐 **Network Intel** | 6 | Wi-Fi, DNS bench, link speed, SMB shares, hosts file, DNS cache |
| 🔍 **Security Scan** | 6 | Defender shield, admins, apps, patches, drivers, certificates |
| 💾 **Storage Forensics** | 9 | SMART health, crash dumps, zero-byte files, symlinks, locked/sparse/compressed files |
| 🧰 **Utilities** | 3 | App location, Explorer here, legacy matrix dashboard |

---

## The Companion Hub (`hub`)

The central brain of your terminal — a single entry point for high-speed operational tasks.

| Shortcut | Command | Action |
|:---|:---|:---|
| **`fix`** | `Invoke-HawkShortFix` | **Self-Healing**: AI-driven remediation of the last error |
| **`stat`** | `Invoke-HawkShortStat` | **Instant Pulse**: 1-page health/resource snapshot |
| **`ask`** | `Invoke-HawkShortAsk` | **Pipable Research**: analyze pipeline data with local LLMs |
| **`mem`** | `Invoke-HawkShortMem` | **Semantic Recall**: save personal notes/preferences |

---

## Semantic Recall (Memory)

Persistent JSONL at `~\Documents\PowerShell\Memory\hawk-memory.jsonl`. Every entry is auto-redacted through `Protect-HawkSensitiveText` before write.

| Alias | Canonical | Description |
|:---|:---|:---|
| `remember` | `Add-HawkMemory` | Append entry: Id, Type, Tags, Text, Source, Created, Confidence, Pinned |
| `recall` | `Search-HawkMemory` | Filter by `-Query`, `-Pinned`, `-First`; scores by term hits (+2 if pinned) |
| `memmap` | `Get-HawkMemoryMap` | List all with `-Tag`, `-Pinned`, `-First` filters |
| `readmem` | `Read-HawkMemory` | Return all entries as `[HawkMemoryEntry]` objects |

```powershell
remember "Prefer Q4_K_M for 1.7B models" -Tag preference -Pinned
recall "quantization" -First 5
memmap -Pinned
```

---

## Operational Workflows

Seven scenario-driven workflows with scoring (0–100) and actionable recommendations.

| Workflow | Alias | Sources | Scoring |
|:---|:---|:---|:---|
| `Invoke-HawkDaily` | `hawkdaily` | health, uptime, disk, network, dns, events, temp, power | 8 sub-functions |
| `Invoke-HawkSystemReview` | `sysreview` | spec, health, uptime, ram, disk, res, port, temp, hyperv, power, license | 11 sub-functions |
| `Invoke-HawkSecurityAudit` | `secaudit` | fw, boot, schedtask, ghost, sus, storm, admin, shield | 8 sub-functions |
| `Invoke-HawkNetworkDiagnostics` | `netdiag` | ping, wifi, dns, dnscache, linkspeed, shares, hosts, established, nettriage | 9 sub-functions |
| `Invoke-HawkThreatHunt` | `threathunt` | sus, ghost, storm, badfiles, locked, sparse, compress, fw | THREATS/WARNINGS/INFO |
| `Invoke-HawkChangeAudit` | — | recent, patches, drivers, dumps, boot, certs | 6 sub-functions |
| `Invoke-HawkComplianceCheck` | — | admin, shield, fw gaps, non-MS tasks, boot, patches, license, hyperv, ports | 9 CIS-inspired checks |

**Thresholds:** ≥80 🟢 | 50–79 🟡 | <50 🔴

```powershell
# Workflows emit per-check objects with .Score and .Recommendations
secaudit | ForEach-Object { $_.Score }
```

---

## Dispatch Verbs

Four umbrella commands organize related queries under a single verb:

| Verb | Alias | Types |
|:---|:---|:---|
| `Get-HawkSystem` | `sysdiag` | `health`, `spec`, `uptime`, `ram`, `battery`, `display`, `disk`, `res`, `port`, `temp`, `fans`, `hyperv`, `power`, `license` |
| `Get-HawkAudit` | `auditdiag` | `fw`, `boot`, `schedtask`, `ghost`, `sus`, `storm`, `admin`, `shield`, `temp`, `clip`, `defender`, `reg`, `ifeo`, `pathaudit` |
| `Get-HawkNetwork` | `netview` | `ping`, `wifi`, `dns`, `linkspeed`, `shares`, `hosts`, `dnscache`, `established`, `nettriage`, `portmap` |
| `Get-HawkEnv` | `envdiag` | `envmap`, `path`, `app` |

```powershell
sysdiag disk        # → Get-HawkDiskPressureAudit
netview portmap     # → Get-HawkPortMap
```

---

## Architecture

PowershellOps uses a **Hexagonal (Ports & Adapters)** design for maximum portability and low-latency execution:

```mermaid
graph TD
    User([User Shortcut]) --> Ports[Public Ports: hawkdaily, fix, ask, stat, mem]
    Ports --> Service[Service Orchestrator: Invoke-HawkCompanion]
    Service --> Context[Ambient Context: Time, Health, Error]
    Service --> Adapters{Infrastructure Adapters}
    Adapters --> Web[Web Search: Scrape + Synthesis]
    Adapters --> CIM[System: CIM/WMI Diagnostics]
    Adapters --> AI[Intelligence: Local llama.cpp LLM]
    Adapters --> Memory[Memory: Local JSONL Store]
```

---

## Documentation

| Document | Contents |
|:---|:---|
| 📗 [MANUAL.md](MANUAL.md) | Full reference: every function, parameter, sensor, and workflow |
| 🚀 [Agentic IDE Walkthrough](docs/AGENTIC-IDE-TUTORIAL.md) | Using PowershellOps as an AI agent's toolkit |

---

<a id="alias-index"></a>
<details>
<summary><b>📖 Complete alias index</b></summary>

> All aliases are global. Run `dash` for the interactive menu.

### 🤖 AI & Workspace
`ai` · `proj` · `reload` · `dash` · `hawkman` · `hawkhelp` · `ggl` · `hawkchat` · `hawkmodel` · `hawkdaily` · `hawkwatch` · `projaudit` · `hawkreport`

### 🛡️ Security Audit
`ghostaudit` · `fwaudit` · `susaudit` · `diskaudit` · `taskaudit` · `evntaudit` · `defendermap` · `regaudit` · `ifeoaudit` · `regsnap` · `secretredact`

### 🩺 Diagnostics
`sysview` · `hawkdoctor` · `hawkcheck` · `evntmap` · `resmap`

### 🌍 Environment
`fwmap` · `envmap` · `pathaudit` · `portmap` · `nettriage` · `bootmap`

### 🦙 Llama Server
`llamastart` · `llamastop` · `aidoctor` · `llamadoctor`

### 🖥️ System Matrix
`specs` · `uptime` · `raminfo` · `battery` · `temps` · `fans` · `displays` · `hypervisor` · `power` · `license`

### 🌐 Network Intel
`wifi` · `dnsbench` · `linkspeed` · `shares` · `hostscheck` · `dnscache`

### 🔍 Security Scan
`shield` · `admins` · `apps` · `patchhistory` · `driveraudit` · `certs`

### 💾 Storage
`clipcheck` · `recent` · `drivehealth` · `dumps` · `badfiles` · `links` · `locked` · `sparse` · `compress`

### 🧰 Utilities
`locate` · `open`

### ⚡ Short Verbs & Hub
`ask` · `fix` · `stat` · `mem` · `hub`

### 🎯 Dispatch Verbs
`sysdiag` · `auditdiag` · `netview` · `envdiag`

### 📋 Workflows
`hawkdaily` · `sysreview` · `secaudit` · `netdiag` · `threathunt`

### 🧠 Memory
`remember` · `recall` · `memmap` · `readmem`

### 🧭 Onboarding
`onboard` (interactive 6-step planner; steps also callable as `Invoke-HawkOnboardStep1..6`)

### 🔍 Quality
`Get-HawkSourceQualityScore` · `Test-HawkPromptInjection`

</details>

<details>
<summary><b>🔬 Sensors & cmdlets map — what each alias touches</b></summary>

CIM/WMI classes, cmdlets, files, and endpoints behind every primitive. Workflows (`hawkdaily`, `secaudit`, …) and dispatch verbs (`sysdiag`, …) are pure aggregators that fan out to these.

### 🤖 AI & Workspace
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `ai` | `Invoke-HawkAI` | HTTP POST → llama.cpp `/v1/chat/completions` |
| `ggl` | `Invoke-HawkSearch` | `Invoke-WebRequest` (DuckDuckGo Lite / Google News RSS) |
| `hawkmodel` | `Get-HawkModel` | Filesystem scan `%USERPROFILE%\Models\GGUF\*.gguf` |
| `projaudit` | `Get-HawkProjectAudit` | Git CLI walk of `projectRoot` |

### 🛡️ Security Audit
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `ghostaudit` | `Get-HawkGhostPortAudit` | `Get-NetTCPConnection` (Listen) × process table |
| `fwaudit` | `Get-HawkFirewallAudit` | `Get-NetTCPConnection` + `Get-NetFirewallRule` + `Get-NetFirewallPortFilter` |
| `susaudit` | `Get-HawkSuspiciousProcessAudit` | `Get-Process` (Path filter: AppData/Temp) |
| `diskaudit` | `Get-HawkDiskPressureAudit` | CIM `Win32_LogicalDisk` (DriveType=3) |
| `taskaudit` | `Get-HawkScheduledTaskRiskAudit` | `Get-ScheduledTask` |
| `evntaudit` | `Get-HawkEventStormAudit` | `Get-WinEvent` (System/Application, Level 2–3) |
| `defendermap` | `Get-HawkDefenderAudit` | `Get-MpComputerStatus` / `Get-MpPreference` / `Get-MpThreatDetection` |
| `regaudit` | `Get-HawkRegAudit` | HKLM/HKCU Run keys + `Get-AuthenticodeSignature` |
| `ifeoaudit` | `Get-HawkIfeoAudit` | IFEO registry `Debugger` values |
| `regsnap` | `Save-HawkRegistrySnapshot` | `reg.exe export` |
| `secretredact` | `Protect-HawkSensitiveText` | Regex scrubbing (no system access) |

### 🩺 Diagnostics
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `sysview` | `Get-HawkSysView` | CIM `Win32_OperatingSystem`, `Win32_LogicalDisk`, services, ICMP ping, Defender state |
| `hawkdoctor` | `Get-HawkDoctor` | Profile parse + module availability checks |
| `hawkcheck` | `Test-HawkSetup` | Integration tests incl. AI known-answer round-trip |
| `evntmap` | `Get-HawkEventMap` | `Get-WinEvent` |
| `resmap` | `Get-HawkResourceMap` | `Get-Process` (WorkingSet/CPU) |

### 🌍 Environment
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `fwmap` | `Get-HawkFirewallMap` | `Get-NetFirewallRule` |
| `envmap` | `Get-HawkEnvMap` | Env scopes Process/Machine/User (REG_EXPAND_SZ expanded) |
| `pathaudit` | `Get-HawkPathAudit` | PATH segment validation + persisted registry PATH |
| `portmap` | `Get-HawkPortMap` | `Get-NetTCPConnection` + owning-process enrichment |
| `nettriage` | `Get-HawkNetworkTriage` | Listeners + owning proc + firewall rule (+ ICMP 1.1.1.1) |
| `bootmap` | `Get-HawkBootMap` | HKLM/HKCU Run-key startup entries |

### 🦙 Llama Server
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `llamastart` / `llamastop` | `Start/Stop-HawkLlamaServer` | Hidden process launch / kill by port |
| `aidoctor` / `llamadoctor` | `Get-HawkLlamaStatus` | REST `http://127.0.0.1:8081/v1/models` |

### 🖥️ System Matrix
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `specs` | `Get-HawkSpecs` | CIM `Win32_Processor`, `Win32_ComputerSystem`, `Win32_VideoController` |
| `uptime` | `Get-HawkUptime` | CIM `Win32_OperatingSystem.LastBootUpTime` |
| `raminfo` | `Get-HawkRamInfo` | CIM `Win32_PhysicalMemory` (per-slot) |
| `battery` | `Get-HawkBattery` | CIM `Win32_Battery` (design vs full-charge health %) |
| `temps` | `Get-HawkThermals` | ACPI `root/wmi MSAcpi_ThermalZoneTemperature` |
| `fans` | `Get-HawkFans` | CIM `Win32_Fan` |
| `displays` | `Get-HawkDisplays` | CIM `Win32_VideoController` video modes |
| `hypervisor` | `Get-HawkHypervisor` | CIM `Win32_ComputerSystem` virtualization flags |
| `power` | `Get-HawkPower` | `powercfg /getactivescheme` |
| `license` | `Get-HawkLicense` | CIM `Win32_SoftwareLicensingProduct` (PartialProductKey) |

### 🌐 Network Intel
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `wifi` | `Get-HawkWifi` | `netsh wlan show interfaces` (parsed SSID/signal) |
| `dnsbench` | `Get-HawkDnsBench` | `Measure-Command { Resolve-DnsName google.com }` latency |
| `linkspeed` | `Get-HawkLinkSpeed` | `Get-NetAdapter` (Status=Up, LinkSpeed) |
| `shares` | `Get-HawkShares` | `Get-SmbShare` (excl. hidden admin shares) |
| `hostscheck` | `Get-HawkHostsCheck` | `%windir%\System32\drivers\etc\hosts` active lines |
| `dnscache` | `Get-HawkDnsCache` | `Get-DnsClientCache` (first 20) |

### 🔍 Security Scan
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `shield` | `Get-HawkShield` | `Get-MpComputerStatus` (real-time + signature age) |
| `admins` | `Get-HawkAdmins` | `Get-LocalGroupMember -Group Administrators` |
| `apps` | `Get-HawkApps` | HKLM uninstall registry (first 30 with DisplayName) |
| `patchhistory` | `Get-HawkPatchHistory` | `Get-HotFix` (latest 15 by InstalledOn) |
| `driveraudit` | `Get-HawkDriverAudit` | CIM `Win32_PnPSignedDriver` where DeviceStatus ≠ OK |
| `certs` | `Get-HawkCerts` | `Cert:\LocalMachine\My` expiry scan |

### 💾 Storage Forensics
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `clipcheck` | `Get-HawkClipCheck` | `Get-Clipboard -Raw` length + preview |
| `recent` | `Get-HawkRecent` | Documents/Downloads recursive 24h LastWriteTime scan |
| `drivehealth` | `Get-HawkDriveHealth` | CIM `MSFT_PhysicalDisk` (Storage namespace health status) |
| `dumps` | `Get-HawkDumps` | `%windir%\Minidump` listing |
| `badfiles` | `Get-HawkBadFiles` | Zero-byte file scan (Documents top level) |
| `links` | `Get-HawkLinks` | Reparse points at profile root (`Attributes -match ReparsePoint`) |
| `locked` | `Get-HawkLocked` | Recursive walk with `-ErrorVariable` access-denied capture |
| `sparse` / `compress` | `Get-HawkSparse` / `Get-HawkCompress` | NTFS SparseFile / Compressed attribute scans |

### 🧰 Utilities
| Alias | Canonical | Sensor / Cmdlet |
|:---|:---|:---|
| `locate` | `Get-HawkAppLocation` | `Get-Command <name>` resolution trace |
| `open` | `Invoke-ExplorerHere` | `Invoke-Item .` opens Explorer here |

</details>

<details>
<summary><b>⚙️ Configuration, pipelines & performance</b></summary>

### Guided onboarding

```powershell
onboard          # Interactive planner (prints steps, supports -WhatIf)
onboard -Apply   # Execute all 6 steps
```

| Step | Command | Action |
|:---|:---|:---|
| 1 | `Invoke-HawkOnboardStep1` | Set project root → saves to config + `$global:HawkProjectRoot` |
| 2 | `Invoke-HawkOnboardStep2` | Set memory root → creates `Memory/` dir, saves to config |
| 3 | `Invoke-HawkOnboardStep3` | Verify llama.cpp endpoint (`http://127.0.0.1:8081/v1/models`) |
| 4 | `Invoke-HawkOnboardStep4` | Select local GGUF model (filesystem scan) |
| 5 | `Invoke-HawkOnboardStep5` | Generate Modelfile from template + selected model |
| 6 | `Invoke-HawkOnboardStep6` | Run `llama create powershellops -f <modelfile>` |

### Configuration

```powershell
Initialize-HawkProfile -ProjectRoot 'D:\Work' -ShowDashboard   # change project root at init
Initialize-HawkProfile -SkipModules                            # skip prereq module import
$env:HAWK_NO_DASH = '1'                                        # suppress dashboard
```

| Variable | Default | Purpose |
|:---|:---|:---|
| `$env:HAWK_NO_DASH` | unset | Set `1` to suppress dashboard |
| `$env:CI` | unset | Auto-suppresses dashboard |
| `$global:HawkProjectRoot` | derived checkout/profile root | Project root for `proj` |
| `~\Documents\PowerShell\hawk.config.json` | optional | Persists projectRoot, hfHome, llamaPort, modelPath |
| `~\Documents\PowerShell\hawk-settings.json` | optional | Persists onboarding settings |
| `$script:HawkSensitiveNamePattern` | regex | Pattern for `secretredact` |

### Pipeline tips

```powershell
portmap | Format-Table -AutoSize                 # chain with native cmdlets
diskaudit | Where-Object { $_.FreePercent -lt 10 }
bootmap | Export-Csv startup.csv

resmap | ai "Which process is using the most RAM?"     # pipe tool output to AI
envmap -IncludeSensitive | secretredact | ai "Summarize"

ggl "windows firewall hardening" -AI              # web search + local synthesis
hub ask "best way to trim TEMP folders?"
Invoke-HawkComplianceCheck | Export-Csv compliance-report.csv
```

### Quality & injection scoring

| Command | Description |
|:---|:---|
| `Get-HawkSourceQualityScore` | Heuristic 0–100: base 50, +20 if content >200 chars, +15 if >800 chars, +15 if `.gov`/`.edu`/`.org`. Cap 100. |
| `Test-HawkPromptInjection` | Regex detection: `ignore (previous|above|all) instructions`, `you are now`, `system prompt`, `DAN.*mode`. Returns `$true`/`$false`. |

Both are integrated into `ggl -AI`: pages are scored, injection positives filtered, synthesis runs only on clean pages ≥50.

### Performance

| Operation | Time |
|:---|:---|
| Module import (bare) | ~150ms |
| Init with prerequisites check | ~400ms |
| Full profile load | ~2.5s |
| Dashboard render | ~50ms |
| First audit run | ~500ms–2s (depends on WMI queries) |
| AI query (llama.cpp, first) | ~5–20s (model load) |
| AI query (llama.cpp, cached) | ~500ms–5s |

### Caching behavior

The only session cache is the git prompt segment (`$global:HawkPromptGitCache`, 2-second TTL per working directory) so the prompt stays snappy inside large repositories. Audit and map commands query WMI/CIM live on every invocation — no result caching, no `-Force` bypass needed.

</details>

---

<div align="center">
  <sub>Developed for Professionals by <a href="https://github.com/shahriarhaqueabir">Shahriar Haque Abir</a></sub>
</div>
