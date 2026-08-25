# PowershellOps v12.0.0 — Hawkward Hybrid

The Hawkward Hybrid release turns PowershellOps from a profile script into a full local AI companion and operational intelligence toolkit for Windows — installed by a real installer, verified by a real test suite, documented end-to-end.

## Highlights

- **Staged installer** — one line on PowerShell 5.1 (`irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/hawk-installer/install.ps1 | iex`) bootstraps PowerShell 7, installs the module + hardened profile into `Documents\PowerShell`, wires config, and verifies. Matching uninstaller included.
- **126 functions / 90 one-word aliases** across 11 dashboard suites: Sentinel, Diagnostics, Environment, System Matrix, Net Intel, Security Scan, Storage, AI Engine, Workflows, Hub & Memory, Workspace.
- **`dash` command center** — every alias is a live emoji tile; nothing dead, nothing redundant. Drill in with one word (`specs`, `temps`, `wifi`, `shield`, `drivehealth`…).
- **Universal AI Companion Hub** — `ask`, `fix`, `stat`, `mem`, `hub` powered by a local llama.cpp server (Qwen3 GGUF). Sensitive text is redacted before it reaches the model. Zero cloud, zero telemetry.
- **Semantic memory** — JSONL-backed notes with typed entries, pinning, confidence scoring, and term-ranked recall.
- **7 scored workflows** — daily brief, system review, security audit, network triage, threat hunt, change audit, compliance check — each producing timestamped markdown reports.
- **Hermetic 27-test suite** — AST parse, PSScriptAnalyzer, staged install/uninstall E2E, export parity gates (functions ↔ manifest ↔ loader ↔ docs), profile smoke tests, memory sandbox, docs contracts.
- **Documentation overhaul** — MANUAL §1–21 including a sensors-and-cmdlets map for every diagnostic alias, plus an agentic IDE walkthrough in `docs/AGENTIC-IDE-TUTORIAL.md`.

## Install

```powershell
irm https://raw.githubusercontent.com/shahriarhaqueabir/PowershellOps/main/hawk-installer/install.ps1 | iex
```

Requirements: Windows 10/11, PowerShell 7.2+ (installer bootstraps it), optional NVIDIA/CPU llama.cpp runtime for AI features.

## Full changelog

See the [commit history](https://github.com/shahriarhaqueabir/PowershellOps/commits/main).
