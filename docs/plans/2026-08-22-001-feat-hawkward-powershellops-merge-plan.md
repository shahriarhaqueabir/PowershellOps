---
title: Merge Hawkward Hybrid into PowershellOps (Modular, llama.cpp, Workflows, Memory)
type: feat
status: active
date: 2026-08-22
origin: docs/brainstorms/2026-08-22-hawkward-powershellops-merge-requirements.md
---

# Merge Hawkward Hybrid into PowershellOps

## Overview

Merge the Hawkward Hybrid toolkit (deep hardware/OS introspection, llama.cpp AI backend, thermal/fan sensors, IFEO/registry audits, storage forensics) into the PowershellOps repository as a modular v12 release. Adopt PowershellOps' modular architecture (Public/, Private/, Patterns/, Tests/) while preserving Hawkward's llama.cpp integration and unique introspection capabilities. Add dispatch verbs, TTL caching, 7 scenario workflows, simple memory system, guided onboarding, and quality/injection scoring.

## Problem Frame

Two complementary PowerShell toolkits exist:
- **Hawkward Hybrid (local)**: Monolithic 4656-line module, llama.cpp backend, 72 aliases, deep hardware introspection (thermal, fan, battery health, licensing, IFEO, registry snapshots, sparse/compressed/locked files), security audits (ghost ports, firewall gaps, persistence), storage forensics. Hardened profile with try/catch phases, ConsoleHost guard.
- **PowershellOps (GitHub)**: Modular architecture (Public/, Private/, Patterns/, Tests/), Ollama backend, 103 exported functions, 7 scenario workflows (dailyops, sysreview, secaudit, netdiag, threat, change, compliance), 4 dispatch verbs, memory system (JSONL), guided onboarding, quality/injection scoring, TTL caching.

**Goal**: Single repo (PowershellOps) with modular architecture, llama.cpp primary backend, Hawkward's introspection + PowershellOps' workflows/memory/dispatch/onboarding.

## Requirements Trace

- R1. Modular architecture: Public/, Private/, Patterns/, Tests/ directories
- R2. llama.cpp as primary AI backend (port 8081, GGUF models, auto-start, model switching)
- R3. All Hawkward introspection aliases preserved (temps, fans, battery, license, IFEO, regsnap, sparse, compress, locked, drivehealth, dumps, badfiles, links, clipcheck, recent)
- R4. All Hawkward security aliases preserved (ghostaudit, fwaudit, susaudit, diskaudit, taskaudit, evntaudit, defendermap, regaudit, ifeoaudit, shield, admins, apps, patchhistory, driveraudit, certs)
- R5. Dispatch verbs: sysdiag, auditdiag, netview, envdiag
- R6. TTL caching layer for expensive WMI/CIM queries
- R7. 7 scenario workflows: dailyops, sysreview, secaudit, netdiag, threat, change, compliance
- R8. Simple memory system (JSONL, remember/recall/memmap, auto-redact)
- R9. Guided onboarding wizard (6 steps: project root, memory root, llama.cpp endpoint, model selection, Modelfile generation, ollama create)
- R10. Quality/injection scoring for ggl -AI pipeline
- R11. Hardened profile (try/catch phases, ConsoleHost guard, layout contract, loud missing-module warnings)
- R12. Updated installer (staging tests, version pins, profile template)
- R13. Updated tests (modular test structure, staging E2E, profile smoke)
- R14. Documentation: README with shields/badges, MANUAL.md, AGENTS.md, CONTRIBUTING.md

## Scope Boundaries

- **In scope**: Full merge as described above
- **Out of scope**: Ollama backend (keep as optional future), vector embeddings, hexagonal architecture refactor, mermaid diagrams in README
- **Deferred to Separate Tasks**:
  - Ollama as secondary backend: separate PR after v12
  - Vector memory/embeddings: future iteration
  - CI/CD pipeline: separate infra task

## Context & Research

### Relevant Code and Patterns

- **HawkwardHybrid.psm1** (local): 4656 lines, 102 functions, 72 aliases, single monolith. Key patterns: `$script:` module-scoped vars, `Set-Alias -Scope Global`, `Export-ModuleMember -Function @(...) -Alias @(...)`, comment-based help on every function, `Set-HawkAliases` registers all aliases, `Initialize-HawkProfile` bootstraps.
- **PowershellOps.psm1** (GitHub): Modular — `Public/` (103 functions), `Private/` (helpers), `Patterns/` (reusable), `Tests/` (Pester-style). Manifest exports `FunctionsToExport` and `AliasesToExport` from Public/.
- **Profile (local)**: 45 lines, hardened — ConsoleHost guard, try/catch phases, layout contract comment, loud warnings.
- **Profile (GitHub)**: 40 lines, simpler — direct module import, `Initialize-OpsProfile`.
- **Installer (local)**: `hawk-installer/` with staging, version pins (`vars.ps1`), 6 steps, hermetic test harness (`run-tests.ps1` 14 tests).
- **Installer (GitHub)**: Single `install.ps1` — git clone, profile copy, `Install-OpsPrerequisite`.
- **Tests (local)**: `run-tests.ps1` — staging-root hermetic tests, profile smoke test, 14 tests.
- **Tests (GitHub)**: `Modules/PowershellOps/Tests/` — Pester-style unit tests.

### Institutional Learnings

- **From local**: Hardened profile pattern (try/catch + ConsoleHost guard) prevents shell-start crashes. Staging-root tests catch wiring regressions. llama.cpp auto-start + model switching works well.
- **From GitHub**: Modular structure enables parallel development and clearer API surface. Workflows aggregate existing functions — zero refactoring needed. TTL cache dramatically reduces WMI latency on repeated calls. Memory system (JSONL) is simple and effective.

### External References

- llama.cpp server API: `http://127.0.0.1:8081/v1/` (compatible with OpenAI-compatible endpoints)
- GGUF model management: `llama download -hf`, `llama create`
- PowerShell module best practices: `Export-ModuleMember`, `Public/`/`Private/` split, `Tests/` with Pester

## Key Technical Decisions

- **Modular restructure**: Split HawkwardHybrid.psm1 into `Public/` (user-facing), `Private/` (helpers), `Patterns/` (reusable), `Tests/`. Manifest exports from Public/.
- **llama.cpp primary**: Keep `Invoke-HawkAI` → llama.cpp `/v1/` endpoint. Rename to `Invoke-OpsAI` for consistency but keep `ai` alias.
- **Dispatch verbs**: Implement as `Get-OpsSystem`/`Get-OpsAudit`/`Get-OpsNetwork`/`Get-OpsEnv` with `-Type` parameter.
- **TTL cache**: Thread-safe hashtable `$script:OpsCache` with per-key expiry. Apply to sysview (30s), fw audit (60s), portmap (10s), bootmap (300s), schedtask (300s).
- **Workflows**: New functions in `Public/Workflows/` — each aggregates existing Public functions, applies scoring (start 100, deduct), returns `[PSCustomObject]` with Score/Recommendations/Health.
- **Memory**: JSONL at `~\Documents\PowerShell\Memory\ops-memory.jsonl`. `remember`/`recall`/`memmap`/`readmem`/`memfile`. Auto-redact via existing `Protect-OpsSensitiveText`.
- **Onboarding**: `Invoke-OpsOnboard` + 6 `Invoke-OpsOnboardStep*` functions. Generates Modelfile, runs `llama create`.
- **Quality scoring**: `Get-OpsSourceQualityScore` (0-100 heuristic), `Test-OpsPromptInjection` (regex). Integrate into `Invoke-OpsSearch -AI`.
- **Profile**: Adopt local hardened pattern (try/catch, ConsoleHost guard, layout contract, loud warnings). Call `Initialize-OpsProfile`.
- **Installer**: Merge local `hawk-installer/` staging test harness into repo. Keep `vars.ps1` pins. Update profile template to hardened version.
- **Tests**: Adopt modular `Tests/` structure. Keep staging E2E + profile smoke. Add unit tests for new workflows/memory/quality.

## Open Questions

### Resolved During Planning

- **Q: Keep `HawkwardHybrid` module name or rename to `PowershellOps`?** → Rename to `PowershellOps` for repo consistency. Keep `Hawkward` as internal codename in comments.
- **Q: Alias naming — keep `ai`/`dash`/`ggl` or adopt `Ops-*` prefix?** → Keep short aliases (`ai`, `dash`, `ggl`, `sysview`, `hawkcheck`...) for UX. Add `Ops-*` prefixed canonical names for discoverability.
- **Q: Module version — v11.4 or v12?** → v12.0.0 (major: architecture change + backend unification).

### Deferred to Implementation

- **Exact Modelfile template** for `llama create` — depends on selected model quantization defaults.
- **TTL values per function** — tune based on real-world latency measurements.
- **Workflow scoring thresholds** — calibrate after integration testing.
- **Memory file rotation/retention policy** — decide after usage patterns observed.

## Implementation Units

- [ ] **Unit 1: Modular Restructure — Public/Private/Patterns/Tests Split**

**Goal:** Split monolithic HawkwardHybrid.psm1 into modular structure matching PowershellOps conventions.

**Requirements:** R1, R3, R4

**Dependencies:** None

**Files:**
- Create: `Modules/PowershellOps/Public/*.ps1` (one per user-facing function)
- Create: `Modules/PowershellOps/Private/*.ps1` (helpers: `Get-HawkPromptGitSegment`, `Write-HawkHeader`, `Test-HawkInteractiveSession`, `Build-HawkAIContextPacket`, etc.)
- Create: `Modules/PowershellOps/Patterns/*.ps1` (reusable: `ConvertTo-HawkMarkdownTable`, `Write-HawkReportTable`, `Format-OpsReportCell`, etc.)
- Create: `Modules/PowershellOps/Tests/Unit/*.ps1` (unit test stubs)
- Create: `Modules/PowershellOps/Tests/Integration/*.ps1` (staging E2E)
- Modify: `Modules/PowershellOps/PowershellOps.psd1` (update FunctionsToExport/AliasesToExport from Public/)
- Modify: `Modules/PowershellOps/PowershellOps.psm1` (root module: dot-source Public/Private/Patterns, export manifest)

**Approach:**
- Each user-facing function (`Get-HawkSysView`, `Invoke-HawkAI`, `Get-HawkGhostPortAudit`, etc.) → own `.ps1` in `Public/`
- Private helpers → `Private/`
- Reusable formatters/report builders → `Patterns/`
- Root `PowershellOps.psm1` dot-sources all three directories, then calls `Export-ModuleMember` using manifest data
- Preserve all 102 functions, 72 aliases, comment-based help

**Patterns to follow:**
- GitHub `Modules/PowershellOps/Public/` structure (one function per file)
- GitHub `Modules/PowershellOps/Private/` for internal helpers
- Local `HawkwardHybrid.psm1` function signatures and help

**Test scenarios:**
- Happy path: `Import-Module PowershellOps` loads all 102 functions, 72 aliases resolve
- Edge case: Missing `Private/` helper throws clear error
- Integration: `Initialize-OpsProfile` registers all 72 aliases globally

**Verification:**
- `Get-Command -Module PowershellOps` returns 102 functions
- `Get-Alias | Where-Object Definition -like '*Hawk*'` returns 72 aliases
- `Test-HawkSetup -SkipAI` passes

- [ ] **Unit 2: llama.cpp AI Backend — Invoke-OpsAI + Model Management**

**Goal:** Port llama.cpp integration as primary AI backend. Rename `Invoke-HawkAI` → `Invoke-OpsAI`, keep `ai` alias. Add model management (`Get-OpsModel`, `Switch-OpsModel`).

**Requirements:** R2

**Dependencies:** Unit 1 (Public/ structure)

**Files:**
- Create: `Modules/PowershellOps/Public/Invoke-OpsAI.ps1` (streaming, auto-start, retry, redact)
- Create: `Modules/PowershellOps/Public/Get-OpsModel.ps1` (list GGUFs, mark active, `-Switch`)
- Create: `Modules/PowershellOps/Public/Start-OpsLlamaServer.ps1` / `Stop-OpsLlamaServer.ps1`
- Create: `Modules/PowershellOps/Public/Get-OpsLlamaStatus.ps1` / `Invoke-OpsLlamaDoctor.ps1`
- Modify: `Modules/PowershellOps/Public/Invoke-OpsChat.ps1` (multi-turn chat, 16-turn history)
- Modify: `Modules/PowershellOps/Public/Invoke-OpsSearch.ps1` (ggl -AI pipeline)
- Modify: `Modules/PowershellOps/PowershellOps.psd1` (export new functions/aliases)

**Approach:**
- Port `Invoke-HawkAI` logic: streaming via `HttpClient`, auto-start llama-server on connection failure, retry logic, `-RedactSensitive`
- Port `Get-HawkModel`: scan `$env:USERPROFILE\Models\GGUF` for `*.gguf`, mark active from config, `-Switch` persists to config + restarts server
- Port `Start-OpsLlamaServer`: hidden process, configured model/port/context/threads, logs to `%LOCALAPPDATA%\llama-app\logs`
- Keep `ai` alias → `Invoke-OpsAI`; add `OpsAI` canonical alias

**Patterns to follow:**
- Local `Invoke-HawkAI` (lines 1373-1570) for streaming + auto-start logic
- Local `Get-HawkModel` for model discovery/switching
- GitHub `Invoke-OpsAI` structure for parameter naming consistency

**Test scenarios:**
- Happy path: `Get-Process | ai "top memory"` returns streamed answer
- Edge case: Server down → auto-starts, retries, succeeds
- Edge case: `-RedactSensitive` scrubs `api_key=xxx` from input
- Integration: `hawkchat` starts REPL, `/exit` quits, history persists 16 turns

**Verification:**
- `ai "2+2"` returns `4`
- `Get-OpsModel` lists local GGUFs
- `Get-OpsModel -Switch qwen` switches model, restarts server

- [ ] **Unit 3: Dispatch Verbs — sysdiag, auditdiag, netview, envdiag**

**Goal:** Four single-entry verbs dispatching to existing aliases via `-Type` parameter.

**Requirements:** R5

**Dependencies:** Unit 1 (all target aliases exist in Public/)

**Files:**
- Create: `Modules/PowershellOps/Public/Get-OpsSystem.ps1` (`-Type health|spec|uptime|ram|battery|display|disk|res|port`)
- Create: `Modules/PowershellOps/Public/Get-OpsAudit.ps1` (`-Type fw|boot|schedtask|ghost|sus|storm|admin|shield|temp|clip`)
- Create: `Modules/PowershellOps/Public/Get-OpsNetwork.ps1` (`-Type ping|wifi|dns|linkspeed|shares|hosts|dnscache|established|nettriage`)
- Create: `Modules/PowershellOps/Public/Get-OpsEnv.ps1` (`-Type envmap|path|app`)
- Modify: `Modules/PowershellOps/PowershellOps.psd1` (export + aliases `sysdiag`, `auditdiag`, `netview`, `envdiag`)

**Approach:**
- Each function: `switch ($Type) { 'health' { Get-OpsHealth } ... }`
- Validate `-Type` against allowed set, throw on invalid
- Output objects (not formatted) for pipeline composability

**Patterns to follow:**
- GitHub `Get-OpsSystem`/`Get-OpsAudit`/`Get-OpsNetwork`/`Get-OpsEnv` dispatch pattern
- Local alias mapping: `health`→`Get-HawkSysView`, `spec`→`Get-HawkSpecs`, `fw`→`Get-HawkFirewallAudit`, etc.

**Test scenarios:**
- Happy path: `sysdiag -Type disk` → `Get-HawkDiskPressureAudit` output
- Edge case: `sysdiag -Type invalid` → throws validation error
- Integration: `sysdiag -Type res | ai "analyze"` works

**Verification:**
- `sysdiag -Type health` == `sysview`
- `auditdiag -Type fw` == `fwaudit`
- `netview -Type ping` == `ping`
- `envdiag -Type path` == `pathaudit`

- [ ] **Unit 4: TTL Caching Layer**

**Goal:** Thread-safe per-key TTL cache for expensive WMI/CIM queries.

**Requirements:** R6

**Dependencies:** Unit 1 (Private/ helpers location)

**Files:**
- Create: `Modules/PowershellOps/Private/Get-OpsCached.ps1` (core cache helper)
- Modify: `Modules/PowershellOps/Public/Get-OpsSysView.ps1` (cache 30s)
- Modify: `Modules/PowershellOps/Public/Get-OpsFirewallAudit.ps1` (cache 60s)
- Modify: `Modules/PowershellOps/Public/Get-OpsPortMap.ps1` (cache 10s)
- Modify: `Modules/PowershellOps/Public/Get-OpsBootMap.ps1` (cache 300s)
- Modify: `Modules/PowershellOps/Public/Get-OpsScheduledTaskRiskAudit.ps1` (cache 300s)

**Approach:**
- `$script:OpsCache = [hashtable]::Synchronized(@{})`
- `Get-OpsCached -Key -ExpirySeconds -ScriptBlock` → returns cached or computes + stores
- Cache key includes function name + relevant params (e.g., `Get-OpsPortMap-Listen`)
- Invalidate on explicit `-Force` or cache expiry

**Patterns to follow:**
- GitHub `Invoke-OpsCachedData` pattern
- Local `$script:` module-scoped vars for state

**Test scenarios:**
- Happy path: Second `sysview` within 30s returns cached (measure latency < 50ms vs ~500ms cold)
- Edge case: `-Force` bypasses cache, re-queries WMI
- Edge case: Cache expiry → re-queries
- Integration: `fwmap` called twice in workflow uses cache

**Verification:**
- Measure-Command shows 10x speedup on cached calls
- `$script:OpsCache.Count` increases on first call, stable on cached

- [ ] **Unit 5: 7 Scenario Workflows**

**Goal:** Seven aggregation workflows with scoring (0-100) and recommendations.

**Requirements:** R7

**Dependencies:** Unit 1 (all source functions in Public/), Unit 4 (cache for perf)

**Files:**
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsDailyOps.ps1`
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsSystemReview.ps1`
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsSecurityAudit.ps1`
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsNetworkDiagnostics.ps1`
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsThreatHunt.ps1`
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsChangeAudit.ps1`
- Create: `Modules/PowershellOps/Public/Workflows/Invoke-OpsComplianceCheck.ps1`
- Create: `Modules/PowershellOps/Private/Workflows/Write-OpsWorkflowBanner.ps1` (shared)
- Create: `Modules/PowershellOps/Private/Workflows/Write-OpsWorkflowSection.ps1` (shared)
- Create: `Modules/PowershellOps/Private/Workflows/Write-OpsRecommendations.ps1` (shared)
- Modify: `Modules/PowershellOps/PowershellOps.psd1` (export workflow functions + aliases `dailyops`, `sysreview`, `secaudit`, `netdiag`, `threat`, `change`, `compliance`)

**Approach:**
- Each workflow: calls source functions via cache, applies scoring (start 100, deduct per finding), returns `[PSCustomObject]@{ Score; Recommendations; Health }`
- Scoring: start 100, deduct per threshold breach (e.g., disk <10% free → -20), floor at 0
- Thresholds: ≥80 🟢, 50-79 🟡, <50 🔴
- `compliance` uses pass-rate % instead of 100-point scale
- Shared helpers for banner/section/recommendation rendering

**Workflows & Sources:**
| Workflow | Sources | Sections |
|----------|---------|----------|
| `dailyops` | health, uptime, disk, network, dns, events, temp, power | 8 |
| `sysreview` | spec, health, uptime, ram, disk, res, port, temp, hyperv, power, license | 11 |
| `secaudit` | fw, boot, schedtask, ghost, sus, storm, admin, shield | 8 |
| `netdiag` | ping, wifi, dns, dnscache, linkspeed, shares, hosts, established, nettriage | 9 |
| `threat` | sus, ghost, storm, badfiles, locked, sparse, compress, fw | THREATS/WARNINGS/INFO buckets |
| `change` | recent, patches, drivers, dumps, boot, certs | 6 |
| `compliance` | admin, shield, fw gaps, non-MS tasks, boot, patches, license, hyperv, ports | 9 CIS-inspired checks |

**Patterns to follow:**
- GitHub workflow pattern: `Invoke-OpsDailyOps` etc. with shared helpers
- Local scoring: start 100, deduct, floor 0, thresholds

**Test scenarios:**
- Happy path: `dailyops` returns Score ≥80 on healthy machine
- Edge case: Disk 95% full → `dailyops` Score <50, 🔴 CRITICAL
- Edge case: `compliance` returns pass-rate % with tally
- Integration: `secaudit | ForEach-Object { $_.Score }` works

**Verification:**
- All 7 workflows execute without error
- Scores in 0-100 range (compliance 0-100%)
- Recommendations array populated with actionable items

- [ ] **Unit 6: Simple Memory System (JSONL)**

**Goal:** Persistent memory with remember/recall/memmap, auto-redact.

**Requirements:** R8

**Dependencies:** Unit 1 (Public/), existing `Protect-OpsSensitiveText`

**Files:**
- Create: `Modules/PowershellOps/Public/Add-OpsMemory.ps1` (`remember` alias)
- Create: `Modules/PowershellOps/Public/Search-OpsMemory.ps1` (`recall` alias)
- Create: `Modules/PowershellOps/Public/Get-OpsMemoryMap.ps1` (`memmap` alias)
- Create: `Modules/PowershellOps/Public/Read-OpsMemory.ps1` (`readmem` alias)
- Create: `Modules/PowershellOps/Public/Get-OpsMemoryFile.ps1` (`memfile` alias)
- Create: `Modules/PowershellOps/Private/Format-OpsMemoryId.ps1` / `Format-OpsMemorySnippet.ps1`
- Modify: `Modules/PowershellOps/PowershellOps.psd1` (export + aliases)

**Approach:**
- File: `~\Documents\PowerShell\Memory\ops-memory.jsonl` (JSONL, one entry per line)
- Entry: `Id` (`mem_{yyyyMMdd_HHmmss}_{guid[0:6]}`), `Type` (note/preference/runbook/session/web/sysops), `Tags`, `Text` (auto-redacted), `Source`, `Created` (ISO 8601), `Confidence` (low/medium/high/user), `Pinned`
- `remember` appends entry, supports `-WhatIf`
- `recall` reads file, parses JSONL, filters by `-Query`/`-Pinned`/`-First`, scores by term hits (+2 if pinned), sorts desc
- `memmap` lists all with `-Tag`/`-Pinned`/`-First` filters
- Auto-redact via `Protect-OpsSensitiveText` on `Text` field

**Patterns to follow:**
- GitHub memory system (JSONL, `remember`/`recall`/`memmap`)
- Local `Protect-HawkSensitiveText` for redaction

**Test scenarios:**
- Happy path: `remember "prefer Q4_K_M" -Tag preference -Pinned` → entry in JSONL
- Happy path: `recall "quantization" -First 3` returns matching entries
- Edge case: `recall -Pinned` returns only pinned entries
- Edge case: Secret in text → auto-redacted in stored entry
- Integration: `remember (resmap | ai "summary") -Type runbook` stores AI summary

**Verification:**
- `memfile` returns valid path
- JSONL parses cleanly
- Redaction works on `api_key=xxx` in remembered text

- [ ] **Unit 7: Guided Onboarding Wizard**

**Goal:** 6-step interactive onboarding for project root, memory root, llama.cpp endpoint, model selection, Modelfile generation, `llama create`.

**Requirements:** R9

**Dependencies:** Unit 1, Unit 2 (llama.cpp functions)

**Files:**
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboard.ps1` (main entry)
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboardStep1.ps1` (project root)
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboardStep2.ps1` (memory root)
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboardStep3.ps1` (llama.cpp endpoint)
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboardStep4.ps1` (model selection)
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboardStep5.ps1` (Modelfile generation)
- Create: `Modules/PowershellOps/Public/Invoke-OpsOnboardStep6.ps1` (`llama create`)
- Modify: `Modules/PowershellOps/PowershellOps.psd1` (export + `opsonboard` alias)

**Approach:**
- `Invoke-OpsOnboard` prints planner, reviews/sets config, discovers local GGUFs via filesystem scan, prints full command chain for copy/paste
- Supports `-Apply` (execute steps) and `-WhatIf` (dry-run)
- Step 1: Project root → saves to config + `$global:OpsProjectRoot`
- Step 2: Memory root → creates `Memory/` dir, saves to config
- Step 3: llama.cpp endpoint → verifies `http://127.0.0.1:8081/v1/models`, stores
- Step 4: Model selection → lists local GGUFs, user picks, persists
- Step 5: Modelfile generation → from bundled template + selected model
- Step 6: `llama create powershell-ops -f <modelfile>` → builds optimized model
- Config persisted to `~\Documents\PowerShell\ops-settings.json`

**Patterns to follow:**
- GitHub `Invoke-OpsOnboard` + 6 `Invoke-OpsOnboardStep*` pattern
- Local `Get-HawkConfig` / `Get-HawkModel` for config/model discovery

**Test scenarios:**
- Happy path: `opsonboard -WhatIf` prints full plan without changes
- Happy path: `opsonboard -Apply` runs all 6 steps, config persisted
- Edge case: Step 3 fails (llama.cpp not running) → prompts to start or skip
- Edge case: Step 4 no GGUFs found → guides to download

**Verification:**
- `opsonboard -WhatIf` prints 6 steps
- Config file created with all 4 settings
- `llama create` succeeds, model usable via `ai`

- [ ] **Unit 8: Quality/Injection Scoring for ggl -AI**

**Goal:** Heuristic quality scoring (0-100) and prompt injection detection for web content.

**Requirements:** R10

**Dependencies:** Unit 1 (Public/), Unit 2 (Invoke-OpsSearch)

**Files:**
- Create: `Modules/PowershellOps/Public/Get-OpsSourceQualityScore.ps1`
- Create: `Modules/PowershellOps/Public/Test-OpsPromptInjection.ps1`
- Modify: `Modules/PowershellOps/Public/Invoke-OpsSearch.ps1` (integrate scoring + injection filter in -AI pipeline)

**Approach:**
- `Get-OpsSourceQualityScore`: base 50, +20 if content >200 chars, +15 if >800 chars, +15 if URL from `.gov`/`.edu`/`.org`, cap 100
- `Test-OpsPromptInjection`: regex for `ignore (previous|above|all) instructions`, `you are now`, `system prompt`, `DAN.*mode` → returns `$true`/`$false`
- In `Invoke-OpsSearch -AI`: score each scraped page, filter injection positives, only synthesize from clean pages above threshold (e.g., ≥50)

**Patterns to follow:**
- GitHub `Get-OpsSourceQualityScore` / `Test-OpsPromptInjection`
- Local `Invoke-HawkSearch` -AI pipeline (DDG Lite scrape → resolve → synthesize)

**Test scenarios:**
- Happy path: `.gov` page with 1000 chars → score 100
- Edge case: 50-char snippet from blog → score 50
- Edge case: Page contains `ignore all instructions` → injection detected, excluded from synthesis
- Integration: `ggl "test" -AI` only uses clean, scored pages

**Verification:**
- `Get-OpsSourceQualityScore` returns 0-100
- `Test-OpsPromptInjection` detects known patterns
- `ggl -AI` skips injected pages

- [ ] **Unit 9: Hardened Profile Template**

**Goal:** Adopt local hardened profile as installer template.

**Requirements:** R11

**Dependencies:** Unit 1 (module name `PowershellOps`)

**Files:**
- Modify: `hawk-installer/profile/Microsoft.PowerShell_profile.ps1` (replace with hardened version)
- Modify: `hawk-installer/steps/03-wiring.ps1` (copy hardened template)

**Approach:**
- ConsoleHost guard: `if ($Host.Name -eq 'ConsoleHost') { try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {} }`
- Layout contract comment: `$PSScriptRoot\HawkProfile\` expectation
- Phase 1: try/catch `Import-Module HawkModules`, `Set-Alias dash40`, catch → `Write-Warning`
- Phase 1 else: `Write-Verbose` missing legacy module
- Phase 2: try/catch `Import-Module PowershellOps`, `Initialize-OpsProfile -ShowDashboard`, catch → `Write-Warning`
- Phase 2 else: `Write-Warning` "PowershellOps not found — run installer wiring step"
- Keep `dash40` → `Show-HawkMatrixDashboard` (legacy)

**Patterns to follow:**
- Local `Microsoft.PowerShell_profile.ps1` (hardened, 45 lines)
- GitHub profile structure (simpler, but adopt hardening)

**Test scenarios:**
- Happy path: Fresh pwsh loads profile, `dash40` + `ai` resolve, no errors
- Edge case: Missing `HawkModules.psm1` → verbose warning, continues
- Edge case: Missing `PowershellOps` module → loud warning, shell usable
- Edge case: Non-ConsoleHost (SSH) → no encoding error

**Verification:**
- Profile smoke test passes (staged template loads, `dash40` + `ai` resolve, 0 errors)
- `Test-HawkSetup -SkipAI` passes

- [ ] **Unit 10: Installer Merge & Staging Test Harness**

**Goal:** Merge local `hawk-installer/` staging test harness into repo. Update `vars.ps1` pins, profile template, steps.

**Requirements:** R12

**Dependencies:** Unit 9 (hardened profile template)

**Files:**
- Create: `hawk-installer/` (entire directory from local)
- Modify: `hawk-installer/vars.ps1` (update pins if needed, use `$env:USERPROFILE` paths)
- Modify: `hawk-installer/steps/03-wiring.ps1` (copy hardened profile, module name `PowershellOps`)
- Modify: `hawk-installer/steps/04-config.ps1` (config keys: projectRoot, hfHome, llamaPort, modelPath)
- Modify: `hawk-installer/build.ps1` (refresh bundled payload from live `Modules/PowershellOps/`)
- Modify: `hawk-installer/tests/run-tests.ps1` (sanitized paths, modular test structure)

**Approach:**
- Copy local `hawk-installer/` wholesale (it's already hardened and tested)
- Update `vars.ps1`: `$script:HawkDefaultProjectRoot = Join-Path $env:USERPROFILE 'Projects'`, `$script:HawkDefaultHfHome = Join-Path $env:USERPROFILE 'Models\GGUF'`
- Update `build.ps1` to copy from `Modules/PowershellOps/` (new modular structure)
- Update `run-tests.ps1`: parameterized test paths (`$script:TestHfHome` etc.), modular test imports

**Patterns to follow:**
- Local `hawk-installer/` (already working, 14 tests pass)
- GitHub `install.ps1` simplicity for user-facing entry point

**Test scenarios:**
- Happy path: `pwsh -File tests\run-tests.ps1` → 14/14 PASS
- Edge case: Staging E2E installs to temp dir, all files land, profile smoke passes
- Edge case: Uninstall removes staged artifacts
- Integration: `build.ps1` refreshes bundled module from live `Modules/PowershellOps/`

**Verification:**
- Full test suite passes (14/14)
- `build.ps1` produces byte-identical bundled module
- Staged install produces working profile

- [ ] **Unit 11: Documentation Overhaul**

**Goal:** GitHub-ready README, MANUAL.md, AGENTS.md, CONTRIBUTING.md.

**Requirements:** R14

**Dependencies:** All prior units (features documented)

**Files:**
- Modify: `README.md` (shields, badges, SEO, alias tables, workflows, memory, onboarding, architecture)
- Modify: `MANUAL.md` (complete alias reference with sensors/data sources, all 7 workflows, memory, onboarding)
- Create: `AGENTS.md` (agent-facing instructions: modular structure, test-first, alias conventions)
- Create: `CONTRIBUTING.md` (PR process, test requirements, coding standards)

**Approach:**
- README: Shields (PowerShell 7+, llama.cpp, MIT, Tests passing, Version), structured alias tables with sensors column, workflows section, memory/onboarding sections, architecture diagram (mermaid), contributing link
- MANUAL.md: All 72+ aliases with function + description + sensors, 7 workflows with scoring, memory commands, onboarding steps, dispatch verbs, config reference
- AGENTS.md: Modular structure rules, test-first for new functions, alias naming conventions, comment-based help required
- CONTRIBUTING.md: Fork → branch → test → PR, `pwsh -File tests\run-tests.ps1` must pass

**Patterns to follow:**
- Local README.md (comprehensive alias tables with sensors)
- GitHub README.md (shields, mermaid, SEO)
- GitHub MANUAL.md (28KB quick-ref format)

**Test scenarios:**
- README renders on GitHub with shields visible
- MANUAL.md covers all exported functions/aliases
- AGENTS.md guides agent contributors
- CONTRIBUTING.md clear for external PRs

**Verification:**
- `README.md` validates as markdown
- All aliases in MANUAL.md match `Export-ModuleMember`
- Links resolve

## System-Wide Impact

- **Interaction graph:** `Initialize-OpsProfile` → imports module → `Set-OpsAliases` (72 aliases) → `Set-OpsPrompt` → optional `Show-OpsDashboard`. Workflows call cached Public functions. Memory system independent.
- **Error propagation:** Cache misses → WMI query → error → cached as failure? No — cache only successes. Failures propagate to caller.
- **State lifecycle risks:** Cache invalidation on `-Force`. Memory file append-only (no rotation yet). Config file written atomically.
- **API surface parity:** All 72 short aliases preserved. 4 dispatch verbs added. 7 workflow aliases added. 5 memory aliases added. `ai`/`ggl`/`hawkchat` preserved.
- **Integration coverage:** Staging E2E tests profile + module + installer. Profile smoke test validates alias resolution. Workflow tests validate scoring.
- **Unchanged invariants:** `ai`/`ggl`/`dash`/`sysview`/`hawkcheck` behavior identical. `llama.cpp` endpoint unchanged. Config file schema extended (memory root, onboarding steps) but backward compatible.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Modular restructure breaks alias resolution | Unit 1 verification: `Get-Command -Module` + alias count test |
| llama.cpp auto-start race condition | Unit 2: retry logic + `Invoke-OpsLlamaDoctor` health check |
| Workflow scoring thresholds uncalibrated | Deferred to implementation; start conservative, tune post-merge |
| Memory file grows unbounded | Deferred: add rotation policy post-v12 |
| Installer `build.ps1` fails on new modular structure | Unit 10: update `build.ps1` to dot-source Public/Private/Patterns |
| Profile smoke test flaky in CI (no ConsoleHost) | Unit 9: ConsoleHost guard + PSReadLine prediction tolerance |

## Documentation / Operational Notes

- **Rollout**: Tag v12.0.0. Update `README.md` version badge.
- **Migration**: Existing users re-run installer (`install.ps1 -Auto`) to get new modular module + hardened profile.
- **Breaking changes**: Module name `HawkwardHybrid` → `PowershellOps` (alias `Import-Module HawkwardHybrid` can be added as compat shim). Function renames: `Invoke-HawkAI` → `Invoke-OpsAI` (keep `ai` alias).
- **Monitoring**: `Test-HawkSetup -SkipAI` as health check.

## Sources & References

- **Origin document:** `docs/brainstorms/2026-08-22-hawkward-powershellops-merge-requirements.md`
- **Local codebase:** `C:\Users\Abir\Documents\PowerShell\Modules\HawkwardHybrid\HawkwardHybrid.psm1`, `C:\Users\Abir\Documents\WindowsPowerShell\hawk-installer\`
- **GitHub codebase:** `https://github.com/shahriarhaqueabir/PowershellOps` (Modules/PowershellOps/, install.ps1, README.md, MANUAL.md)
- **Related PRs/issues:** None yet
- **External docs:** llama.cpp server API, PowerShell module manifest spec