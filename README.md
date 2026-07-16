<div align="center">

# PowershellOps

**Advanced Operational Intelligence & Security Auditing Suite for Windows.**  
*Private. High-Performance. Local AI Integration.*

[![PowerShell](https://img.shields.io/badge/PowerShell-7.2%2B-0078D4?logo=powershell&logoColor=white)](#)
[![AI](https://img.shields.io/badge/AI-Ollama_(local)-8A2BE2?logo=ollama&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-green)](#)
[![Status](https://img.shields.io/badge/Version-11.3-orange)](#)

---

**81 Enterprise Utilities · 7 Automated Workflows · Local LLM Integration · Zero Cloud Dependencies**  
*Muted, professional precision for the modern System Administrator.*

[Features](#-key-capabilities) • [Installation](#-provisioning) • [Quick Start](#-interface) • [AI & Memory](#-local-intelligence) • [Security](#-security-audit)

</div>

---

## ── PHILOSOPHY ────────────────────────────────────────────────────────────

PowershellOps is a professional technical studio for Windows SysOps, designed for specialists who demand privacy, execution speed, and deep system insights. It provides a dense ecosystem of diagnostics, security audits, and network tools that operate entirely within your local perimeter.

- **INTELLIGENT TELEMETRY**: High-density system health reporting in a refined ANSI interface.
- **SECURITY SUBSTRATE**: Local auditing of firewalls, listeners, and persistence vectors.
- **LOCAL INTELLIGENCE**: Integrated pipeline for local LLMs (Ollama) to perform real-time data analysis.
- **PORTABLE & CLEAN**: A self-contained module architecture that respects your existing environment.

---

## ── PROVISIONING ──────────────────────────────────────────────────────────

Deploy the core operational environment directly from **PowerShell 7**:

```powershell
irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/install.ps1 | iex
```

*Requirements: PowerShell 7.2+, Git, and Ollama (optional for AI features).*

---

## ── INTERFACE ─────────────────────────────────────────────────────────────

The operational dashboard features a strictly aligned 16-character grid with a professional pastel palette.

```text
  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │  Ops : CORE   v11.3   AI: ACTIVE                                                                                  │
  ├────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────┤
  │ • SYSTEM           │ corehealth      sysspec         sysuptime       ramstats        battstatus      gpuview      │
  │ • SECURITY         │ adminaudit      shieldstatus    fwcheck         bootmap         taskrisk        ghostports   │
  │ • NETWORK          │ netping         wificheck       peerscheck      dnsbench        netspeed        smbshares    │
  │ • AI/MEM           │ askai           websearch       aistatus        aiintent        aiprofile       airemember   │
  │ • RUN              │ dailycheck      sysreview       secaudit        netreview       threathunt      changeaudit  │
  └────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ── QUICK REFERENCE ──────────────────────────────────────────────────────

### 🖥️ SYSTEM DIAGNOSTICS
| Alias | Description | Technical Metric |
|:---|:---|:---|
| `corehealth`| Real-time system health | CPU, RAM, Procs, Handles |
| `sysspec`   | Hardware specifications | Processor, Cores, GPU |
| `sysuptime` | System availability | Continuous run-time tracking |
| `ramstats`  | Physical memory map | Bank labels, Speed, Manufacturer |
| `diskpressure`| Storage capacity audit | Free space % and volume state |

### 🛡️ SECURITY AUDIT
| Alias | Description | Audit Focus |
|:---|:---|:---|
| `adminaudit`| Administrator group audit | Access control & membership |
| `shieldstatus`| Windows Defender state | Endpoint protection health |
| `fwcheck`   | Firewall & port cross-ref | Rule gap detection |
| `bootmap`   | Startup persistence | Registry run keys |
| `threathunt`| Heuristic anomaly triage | Suspicious files & ports |

### 🌐 NETWORK TRIAGE
| Alias | Description | Connectivity Info |
|:---|:---|:---|
| `netping`   | Internet reachability | ICMP latency & state |
| `wificheck` | WLAN diagnostics | SSID, Signal intensity |
| `dnsbench`  | Multi-resolver benchmark | Resolution performance |
| `smbshares` | Network share audit | Exposed directory vectors |

### 🧠 LOCAL INTELLIGENCE
Powered by **Ollama**. Secure, offline AI for data synthesis and research.

| Alias | Description | Synthesis Level |
|:---|:---|:---|
| `askai`    | Direct LLM query | Local reasoning core |
| `websearch` | Scrape + AI Synthesis | Real-time local research |
| `airemember`| Local memory storage | Knowledge persistence |
| `airecall`  | Semantic memory search | Context retrieval |

---

## ── AUTOMATED WORKFLOWS ──────────────────────────────────────────────────

High-density scored reports combining multi-vector diagnostics into actionable intelligence.

- **`dailycheck`**: The standard morning triage. Health, disk, network, and event storms.
- **`sysreview`**: Comprehensive hardware and resource utilization audit.
- **`secaudit`**: Security hardening and persistence hook verification.
- **`netreview`**: Advanced network stack and DNS performance diagnostics.
- **`threathunt`**: Targeted scan for suspicious artifacts and ghost listeners.
- **`compliancecheck`**: CIS-aligned baseline validation for Windows workstations.

---

## ── DATA INTEGRITY ────────────────────────────────────────────────────────

- **100% Private**: No data ever leaves your machine. No telemetry, no cloud logging.
- **Local Reasoning**: LLM operations are performed via local Ollama instances.
- **Privacy Filters**: Integrated `secretmask` technology automatically redacts sensitive tokens before processing.

---

<div align="center">
  <sub>Developed for Professionals by <a href="https://github.com/shahriarhaqueabir">Shahriar Haque Abir</a></sub>
</div>
