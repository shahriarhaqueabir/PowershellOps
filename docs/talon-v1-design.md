# Talon v1 — Strategic Design Document

> **Date:** 2026-06-26
> **Status:** Approved for implementation
> **Runtime:** PowerShell 7 (Windows only)
> **Distribution:** GitHub Releases + PowerShell Gallery

---

## 1. Product Vision

Talon is a featherweight PowerShell 7 ops shell that loads faster than a stock prompt, puts 50 diagnostic + AI superpowers at your fingertips, and costs zero dollars — all running locally through Ollama.

**Positioning:** There are PowerShell profiles. There are diagnostics tools. There are terminal AI assistants. Nothing combines all three in a single, fast-loading, zero-config package for Windows.

**Target audience:** Windows sysadmins, security analysts, DevOps engineers, power users.

---

## 2. Architecture — Three-Tier Progressive Loading

### Tier 0: Shell Core (~200ms, always loaded)

**Module:** `Talon.psm1` (~150 lines)

Loaded on every session start. Contains only the essentials:

| Component | Purpose |
|---|---|
| `Initialize-Talon` | Entry point — prompt, aliases, config, dashboard |
| `Set-TalonPrompt` | Compact prompt with cached git segment |
| `Set-TalonAliases` | Central alias map |
| `Update-TalonProfile` | `reload` — dot-source without restart |
| `Test-InteractiveSession` | CI / output-redirect detection |
| `Show-TalonDashboard` | TUI stub (lazy-loads render helpers) |
| `Invoke-TalonCachedData` | Thread-safe cache engine |
| `Write-TalonHeader` | Section header for rendered output |

### Tier 1: Commands (auto-loaded on first use)

**Module:** `Talon.Commands.psd1` + `Talon.Commands.psm1` (~800 lines)

Holds all 35 diagnostic, security, network, environment, and report functions. PowerShell's native module auto-loading handles import: export function names from the manifest, and the module loads the first time any exported function is called. ~60ms one-time tax.

### Tier 2: AI Engine (zero cost until invoked)

**Module:** `Talon.AI.psd1` + `Talon.AI.psm1` (~400 lines)

Loaded only when the user types `ai`, `ggl`, `remember`, or `recall`. Contains the streaming Ollama client, web scraper, memory system, and sensitive-text redactor. If Ollama isn't installed, commands show a helpful install message and degrade gracefully — no errors.

---

## 3. Function Inventory — The 50

### System Diagnostics (7)
| Function | Alias | Description |
|---|---|---|
| `Get-TalonHealth` | `health` | Profile health, module status, Ollama ping |
| `Get-TalonSpec` | `spec` | CPU, RAM, motherboard, disk model |
| `Get-TalonUptime` | `uptime` | Boot time + uptime duration |
| `Get-TalonRamInfo` | `ram` | Slots, capacity, usage |
| `Get-TalonDiskPressure` | `disk` | Per-drive free space and usage |
| `Get-TalonResourceMap` | `hog` | Top 10 processes by RAM/CPU |
| `Get-TalonBattery` | `battery` | Charge, health, design capacity |

### Security / Sentinel (7)
| Function | Alias | Description |
|---|---|---|
| `Get-TalonFirewallAudit` | `fwaudit` | Ports with no matching inbound allow rule |
| `Get-TalonBootMap` | `boot` | Registry Run keys persistence |
| `Get-TalonScheduledTaskRisk` | `taskaudit` | Tasks invoking pwsh/cmd from temp |
| `Get-TalonGhostPortAudit` | `ghostaudit` | Orphaned TCP listeners |
| `Get-TalonSuspiciousProcessAudit` | `susaudit` | Processes from AppData/Temp |
| `Get-TalonEventStormAudit` | `evntaudit` | >5 same EventIDs in 30 min window |
| `Get-TalonAdmin` | `admin` | Local admin group membership |

### Network (5)
| Function | Alias | Description |
|---|---|---|
| `Get-TalonNetCheck` | `netcheck` | Connectivity to common endpoints |
| `Get-TalonWifi` | `wifi` | SSID, signal, band |
| `Get-TalonDnsBench` | `dnsbench` | Resolver response time comparison |
| `Get-TalonDnsCache` | `dnscache` | Cache contents and statistics |
| `Get-TalonNetworkTriage` | `nettriage` | Port + PID + process + firewall rule |

### Environment (5)
| Function | Alias | Description |
|---|---|---|
| `Get-TalonEnvMap` | `envmap` | Env var audit (auto-redacts sensitive names) |
| `Get-TalonPathAudit` | `pathaudit` | Validates every `$env:Path` entry |
| `Get-TalonApp` | `app` | Installed applications and versions |
| `Get-TalonPatchHistory` | `patch` | Windows update history + pending reboots |
| `Get-TalonDriverAudit` | `driveraudit` | Driver signing status and known issues |

### AI & Memory (7)
| Function | Alias | Description |
|---|---|---|
| `Invoke-TalonAI` | `ai` | Pipe data to local Ollama model (streaming) |
| `Invoke-TalonSearch` | `ggl` | Web search, `-AI` flag for AI synthesis |
| `Protect-TalonSensitiveText` | `secretredact` | Regex-redact secrets before AI pipeline |
| `Add-TalonMemory` | `remember` | Save local preferences and notes |
| `Search-TalonMemory` | `recall` | Query local memory store |
| `Get-TalonMemoryMap` | `memmap` | List recent or pinned memory entries |
| `Test-TalonPromptInjection` | — | Security gate for AI pipeline |

### Reports & Dashboard (5)
| Function | Alias | Description |
|---|---|---|
| `Show-TalonDashboard` | `dash` | Full TUI startup dashboard |
| `Watch-TalonDashboard` | `watch` | Auto-refresh live dashboard mode |
| `New-TalonReport` | `report` | Full system snapshot → Markdown/JSON |
| `ConvertTo-TalonMarkdownTable` | — | Table formatter for reports |
| `ConvertTo-TalonReportMarkdown` | — | Report document builder |

### Module & Shell (8)
| Function | Alias | Description | Tier |
|---|---|---|---|
| `Initialize-Talon` | — | Entry point, wires everything | 0 |
| `Set-TalonReadLine` | — | PSReadLine prediction config | 0 |
| `Set-TalonPrompt` | — | Custom prompt with git segment | 0 |
| `Set-TalonAliases` | — | All short aliases | 0 |
| `Update-TalonProfile` | `reload` | Dot-source without restart | 0 |
| `Install-TalonPrerequisite` | — | First-run dependency installer | 0 |
| `Get-TalonPromptGitSegment` | — | Cached git branch/status | 0 |
| `Test-InteractiveSession` | — | CI/output-redirect detection | 0 |

### Consolidated Dispatchers (4)
| Function | Available `-Type` Values |
|---|---|
| `Get-TalonSystem` | Health, Spec, Uptime, Ram, Disk, Resource |
| `Get-TalonAudit` | Firewall, Boot, ScheduledTask, Ghost, Suspicious, EventStorm, Admin |
| `Get-TalonNetwork` | NetCheck, Wifi, DnsBench, DnsCache, Triage |
| `Get-TalonEnv` | Env, Path, App, Patch, Driver |

### Utility (2)
`Invoke-TalonCachedData`, `Write-TalonHeader`

---

## 4. Onboarding & Configuration

### First-Run Flow

1. **Install:** `Install-Module Talon` or `iex (iwr ghost.talon.dev/install)`
2. **Shell starts:** `Initialize-Talon` runs, shows welcome dashboard with status
3. **New user:** Types `tutorial` → interactive 5-step walkthrough (~90 seconds)
4. **Power user:** Types `manual` or `dash` → immediate productivity

### Configuration Model (three layers)

```
Layer 1: Environment variables     $env:TALON_PROJECT_ROOT, $env:TALON_NO_DASH
Layer 2: Config file              ~/.talon/config.json
Layer 3: Profile overrides        Initialize-Talon -ProjectRoot D:\Work
```

**Config file defaults created on first run:**

```json
{
  "version": "1",
  "projectRoot": "C:\\Users\\<you>\\Projects",
  "theme": "auto",
  "dashboardEnabled": true,
  "ollama": {
    "model": "talon-default",
    "endpoint": "http://127.0.0.1:11434",
    "contextSize": 8192
  },
  "modules": { "system": true, "security": true, "network": true, "ai": true },
  "gitPromptCacheMs": 2000,
  "suppressBranding": false
}
```

### Tutorial Walkthrough

The `tutorial` command runs an interactive guide:

```
1/5  health         →   "Your system at a glance"
2/5  disk           →   "Storage pressure check"
3/5  audit -Type all →  "One-command security review"
4/5  netcheck       →   "Network connectivity pulse"
5/5  "what's using my RAM?" | ai  →  "AI analysis"
```

---

## 5. Distribution

| Channel | Command | Notes |
|---|---|---|
| **GitHub Releases** | `iex (iwr github.com/.../install.ps1)` | Primary channel, no PS Gallery dependency |
| **PowerShell Gallery** | `Install-Module Talon -Scope CurrentUser` | For existing PS ecosystem users |
| **Scoop** (future) | `scoop bucket add talon; scoop install talon` | Developer toolchain |

Backward-compat aliases (`Get-Hawk*` → `Get-Talon*`) provided in a migration script for existing Hawkward Hybrid users.

---

## 6. Risk & Mitigation

| Risk | Mitigation |
|---|---|
| Module auto-loading fails on older PS | Fallback to explicit `Import-Module` in profile |
| Ollama API changes | Single internal wrapper function, easy to update |
| Windows cmdlet deprecation | Graceful fallbacks: `Get-NetTCPConnection` → `netstat` |
| Nerd Font not installed | Auto-detect, demote to ASCII, show one-time hint |
| Breaking Hawkward users | Migration script with alias map |
| Slow PS module path (network drives) | Detect during install, suggest `-Scope CurrentUser` |

---

## 7. Design Decisions

| Decision | Rationale |
|---|---|
| **PowerShell 7, not Python** | Windows system access (WMI, registry, firewall, event logs) is PowerShell's native domain. Rewriting would lose depth. |
| **Three-tier loading, not single module** | Single module parses all 50 functions on every startup (~800+ lines). Tiered loading keeps the prompt at ~200ms. |
| **Separate AI module** | AI is the heaviest dependency (Ollama HTTP client, streaming, web scraping). Zero cost until invoked. |
| **JSON config, not XML/PSD1** | JSON is editor-friendly, parseable by non-PS tools, and easy to document. |
| **GitHub Releases as primary channel** | No moderation gate, no version validation delay, full control over release artifacts. |

---

## 8. File Layout (Target)

```
~/.talon/                          ← Runtime directory (auto-created)
├── config.json                     ← User configuration
├── Memory/
│   └── talon-memory.jsonl          ← Local memory store

Documents/PowerShell/              ← PS profile directory
├── Microsoft.PowerShell_profile.ps1   ← Thin loader (<10 lines)
├── talon.psd1                     ← Module manifest
├── talon.psm1                     ← Tier 0 — Shell Core
├── talon.commands.psd1            ← Tier 1 manifest
├── talon.commands.psm1            ← Tier 1 — Commands
├── talon.ai.psd1                  ← Tier 2 manifest
├── talon.ai.psm1                  ← Tier 2 — AI engine
├── AI/                            ← Ollama Modelfiles
│   └── talon-default.modelfile
├── Scripts/
│   └── hawkward-to-talon.ps1      ← Migration script
└── Reports/                       ← Generated system snapshots
```

---

*End of design document.*

---

## Handoff Documents

The following implementation resources have been created:

| Document | Purpose |
|---|---|
| [`docs/handoffs/TALON-STRATEGIC-REPORT.md`](handoffs/TALON-STRATEGIC-REPORT.md) | Strategic analysis, function inventory, cut list, timeline |
| [`docs/handoffs/TALON-IMPLEMENTATION-WALKTHROUGH.md`](handoffs/TALON-IMPLEMENTATION-WALKTHROUGH.md) | **Phase-by-phase implementation walkthrough with full code** |

The walkthrough document contains ready-to-paste PowerShell code for all 6 phases: P0 (Skeleton), P1 (Core 50), P2 (AI Pipeline), P3 (Dashboard), P4 (Onboarding), P5 (Distribution), P6 (Migration). Each phase has step-by-step instructions, verification criteria, and exit checklists.
