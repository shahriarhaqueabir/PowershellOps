<div align="center">

# PowershellOps

**A high-performance technical utility suite for Windows SysOps.**  
*100% Private. 100% Local. 0% Telemetry.*

[![Engine](https://img.shields.io/badge/PowerShell-7.2%2B-0078D4?logo=powershell&logoColor=white)](#)
[![AI](https://img.shields.io/badge/AI-Ollama_(local)-8A2BE2?logo=ollama&logoColor=white)](#)
[![Status](https://img.shields.io/badge/Status-v11.3-orange)](#)
[![License](https://img.shields.io/badge/License-MIT-green)](#)

---

**81 Utilities · 7 Workflows · Local AI · Zero Cloud**  
*Muted, professional precision for modern system operations.*

[Philosophy](#-philosophy) • [Installation](#-provisioning) • [Quick Reference](#-quick-reference-manual) • [AI & Memory](#-ai--search) • [Security](#-security)

</div>

---

## ── PHILOSOPHY ────────────────────────────────────────────────────────────

PowershellOps is a modern creative studio suite for SysOps, built for those who value privacy, speed, and technical depth. It provides a dense ecosystem of system, security, and network tools that run entirely on your local hardware.

- **STATUS REPORTING**: High-density health summaries in a professional pastel interface.
- **SECURITY SUBSTRATE**: Audit firewalls, listeners, and persistence hooks locally.
- **LOCAL INTELLIGENCE**: Integrated Ollama pipeline for data analysis and research.
- **PORTABLE**: Self-contained module that respects your global environment.

---

## ── PROVISIONING ──────────────────────────────────────────────────────────

Initialize the core environment from **PowerShell 7**:

```powershell
irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/provision.ps1 | iex
```

*Requirements: PowerShell 7+ and Git.*

---

## ── INTERFACE ─────────────────────────────────────────────────────────────

The interface follows a refined 14-character fixed-width strategy with an 8-bit ANSI pastel palette.

```text
 Ops : CORE > v11.3 > AI: ACTIVE >

 SYSTEM       > corehealth      sysspec         sysuptime       ramstats
                battstatus      gpuview         powertriage     vmcheck
                liccheck        diskpressure    tempcheck       clipcheck
                smartstatus     resourcemap     portmap         sysdiag

 SECURITY     > adminaudit      shieldstatus    fwcheck         bootmap
                taskrisk        ghostports      susprocs        eventstorm
                certaudit       dumpmap         filecheck       shortcutcheck
                lockcheck       sparsecheck     compresscheck   patchhistory
                driveraudit     recentfiles     secretmask      auditdiag

 NETWORK      > netping         wificheck       peerscheck      dnsbench
                netspeed        smbshares       hostscheck      dnsmap
                nettriage       netview

 AI/MEM       > askai           websearch       aistatus        aiintent
                aiprofile       sourcequality   safetycheck     airemember
                airecall        memorymap       memoryread      memoryfile

 RUN          > dailycheck      sysreview       secaudit        netreview
                threathunt      changeaudit     compliancecheck fullreport

 ENVIRONMENT  > envmap          pathaudit       applist         apploc
                envdiag

 CORE         > projview        projset         openhere        corecache
                coreindex       watchindex      corereload      coreinit
                coremanual
```

---

## ── QUICK REFERENCE MANUAL ──────────────────────────────────────────────

### 🖥️ SYSTEM
| Alias | Description | Use Case |
|:---|:---|:---|
| `health` | Core health (CPU, RAM, Procs) | Fast status check |
| `spec` | Hardware specifications | Asset inventory |
| `uptime` | System uptime counter | Reliability tracking |
| `ram` | Detailed physical memory map | Hardware audit |
| `disk` | Storage pressure & free space | Capacity planning |
| `res` | Top resource consumers | Troubleshooting slowdowns |
| `port` | Active listening ports | Network mapping |

### 🛡️ SECURITY
| Alias | Description | Use Case |
|:---|:---|:---|
| `admin` | Administrator group audit | Access control review |
| `shield` | Windows Defender status | Endpoint protection |
| `fw` | Firewall & listener cross-ref | Rule gap analysis |
| `boot` | Persistence (Run keys) audit | Startup inspection |
| `sus` | Suspicious process detection | Threat hunting |
| `storm` | Event log volume analysis | Log anomaly detection |
| `secretredact`| Mask sensitive tokens | Privacy/Logging |

### 🌐 NETWORK
| Alias | Description | Use Case |
|:---|:---|:---|
| `ping` | Internet reachability test | Connectivity check |
| `wifi` | WLAN signal & SSID info | Wireless diagnostics |
| `dns` | Multi-resolver benchmark | Optimization |
| `smb` | Active network shares | Lateral movement audit |
| `hosts` | Hosts file integrity check | Redirection audit |

### 🧠 AI & MEMORY
Integrated with **Ollama** for local-only LLM processing. No data ever leaves your machine.

| Alias | Description | Use Case |
|:---|:---|:---|
| `ai` | Local LLM query | Data analysis / Synthesis |
| `ggl` | Web search + AI synthesis | Localized research |
| `remember` | Store data in local memory | Persistence |
| `recall` | Search local memory store | Knowledge retrieval |
| `aistatus` | List local LLM models | Engine status |

---

## ── SCENARIO WORKFLOWS ────────────────────────────────────────────────────

High-density scored reports (0–100) combining multiple diagnostics.

- **`dailyops`**: The morning brew. Health, disk, network, and event storms.
- **`sysreview`**: Deep hardware and resource consumption audit.
- **`secaudit`**: Hardening check. Defender, Firewall, and Persistence.
- **`netdiag`**: Connectivity, DNS benchmarking, and interface triage.
- **`threathunt`**: Hunt for suspicious files, ports, and processes.
- **`compliance`**: CIS-inspired pass/fail validation.

---

## ── DATA INTEGRITY ────────────────────────────────────────────────────────

- **Privacy First**: All processing happens on your machine. No telemetry, no clouds.
- **Local AI**: Direct integration with local LLMs via Ollama for intelligent analysis.
- **Masking**: Built-in redaction filters (`secretmask`) ensure sensitive tokens never leak into reports.

---

<div align="center">
  <sub>MIT © 2026 · <a href="https://github.com/shahriarhaqueabir">Shahriar Haque Abir</a> · powershell-ops</sub>
</div>

