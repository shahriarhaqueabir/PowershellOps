# Harnessing an Agentic IDE: The PowershellOps Lifecycle

*A practical walkthrough of building a real project with an AI coding agent — every phase, prompt shape, parameter, guardrail, and human-in-the-loop decision, reconstructed from the actual repository history.*

**Project:** `E:\Projects\PowershellOps` — v12.0.0, "Advanced Operational Intelligence & Universal AI Companion for Windows"
**Stack:** PowerShell 5.1 module (~6,215 lines), llama.cpp local LLM backend (`127.0.0.1:8081`, OpenAI-compatible `/v1/chat/completions`), GGUF models under `~\Models\GGUF`
**Final surface:** 126 exported functions · 108 global aliases · 10 suites · 7 workflows · 5 semantic-recall commands · 4 dispatch verbs · hermetic test suite (14 tests) · PSScriptAnalyzer lint gate · scripted installer
**Timeline:** May 2 → Aug 22, 2026 · 30 commits on `main` · one uncommitted convergence wave

Everything below is drawn from git history, plan documents, and archived agent-review artifacts inside this repo. Commit SHAs are cited so you can verify each claim yourself.

---

## Table of Contents

1. [The Thesis](#1-the-thesis)
2. [Phase Map](#2-phase-map)
3. [Phase 0 — Rig the Harness Before Writing Code](#3-phase-0--rig-the-harness-before-writing-code)
4. [Phase 1 — Genesis: Seed With a Real Artifact](#4-phase-1--genesis-seed-with-a-real-artifact)
5. [Phase 2 — Expansion Loops](#5-phase-2--expansion-loops)
6. [Phase 3 — Structural Refactor](#6-phase-3--structural-refactor)
7. [Phase 4 — Purification Day](#7-phase-4--purification-day)
8. [Phase 5 — Feature Sprint + Agent-Facing Docs](#8-phase-5--feature-sprint--agent-facing-docs)
9. [Phase 6 — Plan-First Convergence](#9-phase-6--plan-first-convergence)
10. [Phase 7 — The Gated Review-Fix Loop](#10-phase-7--the-gated-review-fix-loop)
11. [Guardrails Catalog](#11-guardrails-catalog)
12. [What to Track](#12-what-to-track)
13. [Prompt Pattern Appendix](#13-prompt-pattern-appendix)
14. [Failure Museum](#14-failure-museum)
15. [Final Checklist](#15-final-checklist)

---

## 1. The Thesis

An agentic IDE is not a autocomplete toy and not an autopilot. Across this project it behaved like a **junior developer pair**: fast, tireless, occasionally sloppy in predictable ways (hardcoded paths, manifest drift, debris files, non-hermetic tests). The human's job was never typing code — it was **architecture, constraints, verification, and taste**.

The lifecycle that emerged has a repeatable shape:

```
harness setup → seed artifact → expansion loops → structural refactor
→ purification → sprint → plan-first rewrite → gated review → fix rounds
```

Each phase has a distinct *prompt style*, a distinct *risk profile*, and a distinct *human checkpoint*. Learn the phases and you can reuse the whole workflow on any project.

---

## 2. Phase Map

| # | Phase | Dates | Commits | Theme | Human role |
|---|-------|-------|---------|-------|------------|
| 0 | Harness | before May 2 | — | Agent config, custom auditors, memory dirs | Architect |
| 1 | Genesis | May 2–5 | `bb5fc30`…`0b5350a` | Seed monolith + modelfiles + log | Vision holder |
| 2 | Expansion | June | `22917a3`, `65ab9a9` | Feature bursts, tests, CI, debug scripts | Direction setter |
| 3 | Organization | Jul 1–5 | `18558fc` | Monolith → Public/Private split | Reviewer |
| 4 | Purification | Jul 15 | **15 commits in one day** | Delete dead weight, rebrand, redact | Gatekeeper |
| 5 | Sprint | Jul 16–28 | `ad8ccde`, `f21b7af` | Onboarding wizard, patterns, `.memory/` | Prioritizer |
| 6 | Convergence | Aug 22 | uncommitted tree | Brainstorm → plan → full rebuild | Approver |
| 7 | Gated review | Aug 22 | run `20260822-220044` | 17 findings, 8 auto-fixed, 6 residual | Judge |

Notice the rhythm: **create fast, then delete hard, then formalize, then re-create deliberately.** That oscillation is normal for agentic work — the agent generates volume cheaply, so your leverage shifts entirely to curation.

---

## 3. Phase 0 — Rig the Harness Before Writing Code

> **Lesson: the highest-leverage agentic work happens before any feature exists.**

Before the first commit, three pieces of infrastructure were put in place. None of them contain product code; all of them shaped every later interaction.

### 3.1 Custom read-only auditor agents (`.opencode/agent/*.md`)

Three subagent definitions were authored, each pinned to a *cheap free model* and stripped of dangerous permissions:

```yaml
# hawk-audit-incomplete.md (excerpt of frontmatter intent)
mode: subagent
model: opencode/mimo-v2.5-free
permission:
  edit: deny
  bash: deny
```

| File | Model | Mission |
|------|-------|---------|
| `hawk-audit-incomplete.md` | `opencode/mimo-v2.5-free` | Hunt stub bodies, swallowed failures, ignored params, help-vs-reality mismatch, dead branches |
| `hawk-audit-redundancy.md` | `opencode/hy3-free` | Map duplication across layers; classify each overlap IDENTICAL/PARTIAL/SUPERSEDED/UNIQUE |
| `hawk-audit-arch.md` | — | Architecture/consistency advisory |

**Why this matters — copy these decisions:**

- **`edit: deny` + `bash: deny`.** Auditors must never mutate anything. A reviewer that can edit is a reviewer that can hide its own mistakes.
- **Cheap models for broad scans.** Completeness/redundancy sweeps are pattern-matching work, not reasoning work. Route them to free-tier models; save the expensive model for synthesis.
- **Seeded hypotheses.** The redundancy agent wasn't told "find duplicates" — it was handed a *known duplicate* (`Win32_PnPSignedDriver` queried in both modules, ~line 231 vs ~line 4473) and a *suspected pair* (`Test-HawkNerdFont` vs `Test-HawkNerdFontPresent`) plus a concrete method: inventory capabilities → grep for the same `Win32_*` classes → diff core query lines → quantify % superseded.
- **Mandated return format.** Both agents specify exact output tables ("classify EACH of 35 legacy Ops-* functions COMPLETE/PARTIAL/STUB with one-line evidence", "spot-check 15 random Hawk-*"). Structured output = diffable, trackable results.

### 3.2 Working-state directories

- `.context/systematic/ce-review/<run-id>/` — every code-review run archives its metadata, synthesized findings, and the **full diff patch** (371 KB in the final run). Reviews become reproducible artifacts, not chat scrollback.
- `.memory/` (later committed at `f21b7af`) — `index.md`, `todo/`, `topics/`. Institutional memory the agent can consult across sessions.
- `docs/plans/`, `docs/brainstorms/` — design documents live beside code but outside the tracked tree once `dc4c896` stopped tracking `docs/`.

### 3.3 Session-level constraint

One rule governed this entire project's agent sessions: **no subagents for execution work** (recorded verbatim in the review metadata: `"execution": "inline-no-subagents (user constraint)"`). Research could fan out; edits happened inline where the human could watch. This is a legitimate choice — inline execution trades speed for observability, and early in a project observability wins.

**Checkpoint:** none needed yet. You're configuring, not producing.

---

## 4. Phase 1 — Genesis: Seed With a Real Artifact

> **Lesson: don't ask the agent to invent a project. Give it a nucleus and let it elaborate.**

Commit `bb5fc30` (May 2, "Initial commit") is not a skeleton — it's a working organism:

| Seeded artifact | Size | Purpose |
|---|---|---|
| `Modules/HawkwardHybrid/HawkwardHybrid.psm1` | 1,551 lines | Working monolith |
| `PROJECTDETAILS.md` | 106 lines | Intent statement |
| `PROJECT_LOG.md` | 343 lines | Running narrative |
| `AI/{qwen,gemma,distilledqwen}.modelfile` | ×3 | Local model configs |
| profile snippet | 27 lines | Shell integration |
| `.gitignore` | 71 lines | Hygiene from day one |

**Prompt shape that produces this:** not "build me a PowerShell AI toolkit" but something closer to *"here is my working module and my model files; absorb them into a project."* The agent's job was organization and elaboration, which it does far more reliably than invention.

The follow-up commits show tight iteration loops:

- `9e42f6d` "Ai refactoring" — **+21/−1 lines.** Tiny, surgical. When commits are this small, the human was steering at function granularity.
- `dc63b48` "case study rewrite" — +488 module lines, README born at 161 lines. A themed expansion pass.
- `b682a9e`, `0b5350a` — doc-only tweaks. Cheap commits; no reason to batch them.

**What to track here:** commit size distribution. A healthy genesis phase looks like one big seed followed by a tail of small, legible commits — exactly what the log shows.

---

## 5. Phase 2 — Expansion Loops

> **Lesson: expansion commits should arrive as *themed bundles*, and each theme should carry its own safety net.**

June produced two large waves:

**Wave 1 — `22917a3` "further funtions" (Jun 7).** One commit containing:

- psm1 rewritten via a **2,897-line diff** (the monolith roughly doubles)
- `Tests/HawkwardHybrid.Tests.ps1` — **474 lines of Pester tests, added in the same commit as the features they cover**
- `MANUAL.md` — 337 lines of user documentation
- `Invoke-HawkBuild.ps1` — 77-line build script
- `LICENSE` (MIT)

Note the typo in the message ("funtions") — humans typed some of these messages, agents others. That's fine; what matters is the bundle discipline: **feature + test + doc + build tooling land together**, so every commit is runnable.

**Wave 2 — `65ab9a9` "gist workflows" (Jun 27).** Process infrastructure:

- `.github/workflows/ci.yml` (28 lines)
- `CONTRIBUTING.md` (42 lines)
- `Scripts/add-module-init.ps1`, `check-duplicate.ps1`, `check-psm1-tail.ps1`, `check-talon-state.ps1`, `check-talon.ps1` — throwaway debug scripts, committed anyway

That last bullet is deliberate: **commit your scaffolding.** You can't purify what you never captured, and Phase 4 proves the value of having it in history.

**Prompt shape for expansion waves:** *"Add X, Y, Z capabilities to the module; extend the test suite to cover them; update the manual."* One sentence of intent, agent fills in hundreds of lines, human reviews the diff.

**Human checkpoint:** after each wave, run the tests and skim the manual. If the manual's claims drift from behavior, correct immediately — drift compounds.

---

## 6. Phase 3 — Structural Refactor

> **Lesson: let the agent do mechanical splits; keep naming authority yourself.**

`18558fc` "code organization" (Jul 1) split the monolith:

```
Modules/PowershellOps/
├── Private/Helpers.ps1        (198 lines)
├── Public/AI.ps1              (100)
├── Public/Memory.ps1          (87)
├── Public/Network.ps1         (232)
├── Public/Profile.ps1         (369)
└── …                          (+ psd1 rework, 112-line diff)
```

This is the ideal refactor delegation: the *partition* (Public vs Private, domain-based files) was decided by the human; the *mechanical move* of 1,000+ lines was executed by the agent. The psd1 export list was regenerated in the same commit — the agent handles manifest bookkeeping well *when told to do it in the same change*.

**Risk to watch:** split commits are where export drift is born. If `FunctionsToExport` isn't touched in the same commit as the file layout, it silently rots. (This exact failure resurfaces in Phase 7 as finding #1.)

---

## 7. Phase 4 — Purification Day

> **Lesson: schedule a deletion day. Agents accumulate; only you can subtract.**

July 15 produced **fifteen commits** — the densest curation session of the project:

| Commit | Action | Why it matters |
|---|---|---|
| `ca6771f` | **Deletes** `.github/workflows/ci.yml` (−28) + AI modelfiles | Killing CI you can't maintain beats keeping a lying green check |
| `c792985` | Removes all `Scripts/dev/*` debug scripts | Scaffolding served its purpose |
| `dc4c896` | Stops tracking `docs/` | Design docs become local working state |
| `b032144` | README SEO pass | Presentation matters |
| `108f76e` | CONTRIBUTING PR flow | Process doc |
| `246d4fb` | **Branding realignment** Hawkward→PowershellOps via `git mv` | Renames preserve history |
| `6ab78ed` | Hostname redaction + dashboard syntax fix | Privacy hygiene |
| `db5af50` | Untracks ignored sentinels | Gitignore promises kept |
| `7047d4e` | Deletes a stray file named `}` | See Failure Museum |
| `836dc73` | Dashboard UI refactor (+65/−30, table grids) | Polish |
| `dadd025` | Final sweep | — |

**Prompt shapes for a purification day:**

- *"List everything in the repo that is dead, duplicated, or embarrassing. Don't fix anything yet."*
- *"Delete X, Y, Z. Use git mv for renames. Show me the resulting tree before committing."*
- One commit per concern — the fifteen-commit day is the output of *sequential, single-purpose instructions*, not one mega-prompt.

**Why atomicity matters here specifically:** when `ca6771f` deleted CI, that decision stayed reversible and legible forever. Had it been buried in a cleanup mega-commit, nobody would later know CI was *deliberately removed* rather than lost.

---

## 8. Phase 5 — Feature Sprint + Agent-Facing Docs

> **Lesson: the most underrated artifacts in an agentic repo are the ones written *for the agent*, not for humans.**

Two commits define this phase:

**`ad8ccde` "wip" (Jul 16)** — honest label, big content: `Onboarding.ps1` +335 lines (a 6-step interactive wizard), Helpers +192, Tests +85, README rewritten (162), Modelfile renamed to `OpsIntelligence.Modelfile`.

**`f21b7af` "CI/CD fixes" (Jul 28)** — the message is wrong and instructive: there is no CI (it was deleted Jul 15). What actually landed:

- `.memory/index.md`, `.memory/todo/2026-07-28-codebase-indexer.md`, `.memory/topics/sota-research-2026.md`
- `AGENTS.md` (69 lines) — **standing instructions for every future agent session**
- `Patterns/DailyBrief.md`, `Patterns/SystemAnalyst.md` — reusable workflow recipes
- `AI.ps1` +118, `Memory.ps1` +111
- `.gitignore` reworked (81-line diff)

`AGENTS.md` is the keystone. It encodes conventions (naming, structure, testing expectations) so that every subsequent session starts pre-aligned instead of re-deriving the rules. Write it early; this project wrote it five months in and paid for it — the Phase 7 review explicitly flagged its absence as a gap.

**What to track:** misleading commit messages. "CI/CD fixes" adding zero CI is noise in your history. When delegating commits to the agent, require it to describe *what changed*, not what it intended.

---

## 9. Phase 6 — Plan-First Convergence

> **Lesson: for big moves, force the sequence brainstorm → plan → approve → execute. The plan document is the contract.**

On Aug 22 the project did its boldest thing: replacing the GitHub modular codebase with the hardened local monolith, rebranded as PowershellOps v12. It did **not** start with a prompt like "merge the two codebases." It started with documents.

### 9.1 Brainstorm → requirements

`docs/brainstorms/2026-08-22-hawkward-powershellops-merge-requirements.md` captured the raw problem: two real toolkits existed — the local Hawkward Hybrid monolith (4,656 lines, 102 functions, 72 aliases, battle-tested) and the GitHub PowershellOps modular tree (103 functions, 7 workflows, JSONL memory, TTL cache). Which survives? What gets inherited from each?

### 9.2 The plan document

`docs/plans/2026-08-22-001-feat-hawkward-powershellops-merge-plan.md` — **566 lines** — is worth studying section by section, because it is the template for delegating large work safely:

| Section | Content | Why it exists |
|---|---|---|
| YAML frontmatter | `type: feat`, `status: active`, `origin:` → brainstorm doc | Machine-readable state; provenance chain |
| Problem Frame | Side-by-side comparison of both toolkits | Forces honest inventory before choosing |
| Requirements Trace R1–R14 | R1 modular dirs · R2 llama.cpp primary :8081 · R3/R4 preserve all aliases · R5 dispatch verbs · R6 TTL caching · R7 seven workflows · R8 JSONL memory w/ auto-redact · R9 onboarding wizard · R10 quality/injection scoring · R11 hardened profile · R12 installer · R13 tests · R14 docs | Every requirement numbered = every later claim checkable |
| Scope Boundaries | Explicit out-of-scope (Ollama secondary backend, vector embeddings) and deferred (CI) | Prevents scope creep mid-execution |
| Key Technical Decisions | Thread-safe `$script:OpsCache` with per-key TTLs (sysview 30s, fw 60s, portmap 10s, bootmap 300s); workflows score from 100 and deduct; JSONL memory at `Documents\PowerShell\Memory`; rename `Invoke-HawkAI`→`Invoke-HawkAI` but **keep alias `ai`**; version v12.0.0 | Decisions recorded with rationale = future sessions don't relitigate |
| Open Questions | Split into *Resolved-During-Planning* vs *Deferred-To-Implementation* (TTL tuning, scoring thresholds, memory rotation) | Distinguishes "decided" from "we'll see" honestly |
| 11 Implementation Units | Each with Goal / Requirements / Dependencies / Files(create+modify) / Approach / Patterns-to-follow / Test-scenarios(happy+edge+integration) / Verification commands | The actual work orders |
| System-Wide Impact | Interaction graph, cache-successes-only policy, API parity promise (72 aliases preserved), unchanged invariants | Blast-radius analysis before code moves |
| Risks & Dependencies | e.g., autostart race → mitigation retry + doctor command; flaky CI profile smoke → ConsoleHost guard | Pre-mortem |
| Rollout | Tag v12.0.0, migration = re-run installer, breaking changes with compat shim | Exit strategy |

### 9.3 Execution

Only after the plan existed did the working tree change — and then all at once: every old `Modules/PowershellOps/**` deleted, legacy top-level scripts deleted, and the new `hawk-installer/` tree (steps `01-engine` through `06-update-check`, `lib/common.ps1`, hermetic `tests/run-tests.ps1`, `build.ps1` with an export-parity gate) assembled untracked.

**Human checkpoints in this phase — all mandatory:**

1. Approve the problem frame (which toolkit wins).
2. Approve the requirement list and scope boundaries.
3. Approve the technical decisions (especially compatibility promises like "keep alias `ai`").
4. Approve the unit breakdown before implementation begins.

The agent drafted all four; the human signed off on each. **Never let the plan and its approval collapse into one step.**

---

## 10. Phase 7 — The Gated Review-Fix Loop

> **Lesson: a code review you can archive, score, route, and partially automate is worth ten ad-hoc "review my diff" prompts.**

The final act ran the systematic review pipeline (`ce-review`), archived at `.context/systematic/ce-review/20260822-220044-57a58856/`. Its mechanics are the most transferable part of this whole walkthrough.

### 10.1 Setup facts worth copying

- **Diff base:** because the new tree was uncommitted, the review computed the diff against the empty-tree hash (`4b825dc642cb6eb9a060e54bf8d69288fbee4904`) — i.e., it reviewed the freshly assembled v12 as an all-new codebase. Archiving the 371 KB patch made the review reproducible.
- **Reviewer roster (run inline per the no-subagents constraint):** correctness, testing, maintainability, project-standards, agent-native, learnings, security, reliability, adversarial, cli-readiness.
- **Confidence gating:** findings below 0.60 confidence are suppressed outright; borderline ones (like a dead fallback version pin, conf 0.60) get marked suppressed-borderline rather than deleted. This kills nitpick floods without losing signal.

### 10.2 Findings and routing

17 findings, each routed by confidence and risk class:

| Route | Meaning | Examples from this run |
|---|---|---|
| `safe_auto` | Fix immediately, no discussion | #10: wrap `[Console]::OutputEncoding` in try/catch (psm1:4527) — applied ✅ |
| `requires_verification` | Fix, then prove the fix | #1 P1: psd1↔psm1 export drift (conf 0.90) — fixed by adding `Invoke-HawkHelp`/`Get-HawkThermals`/`Get-HawkFans` + aliases, **verified by importing the psd1 and replaying the alias flow** |
| `manual` | Human must decide/execute | #3 staging purity (persistent `HF_HOME` env var); #9 winget id `llama.cpp` not `ggml.llamacpp` |
| `advisory` | Record, don't block | #7 checksum pinning for downloaded llama binaries (domain verified legitimate ggml-org first); #13 `LlamaPort` param validation |
| `human` | Judgment call surfaced to owner | #15 plan gaps (R1/R5–R8/R10 units not yet implemented); #17 README describing v12 ahead of code — **user confirmed intentional, closed with no action** |

Applied fixes (#1, #2 staging isolation via `HAWK_CONFIG_PATH`, #4 null-model + TCP race guards in `Start-HawkLlamaServer`, #6 replace hardcoded `E:\Projects`/`E:\Models` defaults with `$env:USERPROFILE` derivation, #8 exit codes on failed uninstall/update steps, #11 delete `test-parse*.ps1` debris, #12 strengthen build parity gate from `>=48` to full set-equality + add a parity test) — **eight fixes, one round, verdict: Ready.**

### 10.3 The requirements-completeness line

The review ends by scoring the plan against reality:

```
R11✅ R12✅ R4✅ R3⚠(broken via #1) R2◐ R13◐ R14◐ R9 n/a
NOT addressed: R1, R5, R6, R7, R8, R10
```

This is the single most valuable tracking artifact in the project: a machine-checked mapping of *plan promises → code reality*. Copy it. Every plan phase should end with one.

### 10.4 Human-in-the-loop moments in review

- The P1 fix was auto-applied but **verification was demanded** (import test) before the verdict flipped.
- Security finding #7 was *validated then downgraded*: the agent checked the download domain's legitimacy before deciding pinning was advisory rather than blocking. Validation before severity.
- Finding #17 (docs ahead of code) went to the human, who said "intentional" — the only correct resolver for an intent question.

---

## 11. Guardrails Catalog

Every guardrail actually used in this project, with the failure it prevents:

| Guardrail | Where | Prevents |
|---|---|---|
| `permission: {edit: deny, bash: deny}` on auditor agents | `.opencode/agent/*.md` | Reviewers tampering with evidence |
| Cheap/free models for scan work, strong model for synthesis | `.opencode/agent/*.md` model pins | Cost blowout on broad sweeps |
| No-subagents-for-edits session rule | user constraint, logged in review metadata | Unobservable mutations |
| Tests added in the same commit as features | `22917a3` | Untested expansion |
| Hermetic test root (`Set-HawkStagingRoot`, staged import, `HAWK_CONFIG_PATH` isolation) | `tests/run-tests.ps1`, fix #2 | Tests touching your real profile/config/models |
| Export-parity gate (psm1 ↔ psd1 set equality) | `build.ps1` + dedicated test, fix #12 | Silent manifest drift |
| Version pins in `vars.ps1`; engine/model install steps separated | `hawk-installer/steps/01-engine`, `02-model` | Undocumented dependency drift |
| Hardened profile template (try/catch phases, ConsoleHost guard) | profile | Broken shell on agent-generated errors |
| `.gitignore` covering models, binaries, reports, stage dirs | since `bb5fc30` | Committing gigabytes of GGUF |
| Atomic single-concern commits | Purification day | Unrecoverable cleanup decisions |
| Confidence-gated findings (suppress <0.60) | ce-review config | Nitpick floods burying real bugs |
| Archived review runs (metadata + findings + full patch) | `.context/systematic/ce-review/` | Irreproducible reviews |
| `AGENTS.md` standing conventions | `f21b7af` | Every session re-litigating style |
| Redaction passes (hostname removal `6ab78ed`, memory auto-redact R8) | git history, plan R8 | Leaking machine identity into a public repo |

---

## 12. What to Track

If you adopt one section of this document, adopt this one. These are the artifacts whose presence or absence predicted project health:

1. **Commit-size distribution per phase.** Big seed → small steering commits → themed bundles → atomic deletions. Deviations signal lost control.
2. **Plan-to-code traceability line** (`R11✅ R3⚠ NOT addressed: R1,R5…`). Regenerate after every milestone.
3. **Review run archives** — id, timestamp, verdict, findings count, fixes applied, residual list. The final run: `20260822-220044-57a58856`, 17 findings, 8 fixed, 6 residual, verdict Ready.
4. **Residual-work ledger.** Six items survived the final review with explicit routes (manual/advisory/human). Unresolved-but-recorded beats resolved-but-forgotten.
5. **Alias/API parity counts.** 126 exports, 108 aliases, promised preservation of 72 legacy aliases — numbers you can assert in tests, not vibes.
6. **Debris sightings.** The stray `}` file, `test-parse*.ps1`, stale `__pycache__` gitignore entries in a PowerShell repo — each one is a canary for agent sloppiness. Log them; patterns emerge.
7. **Doc-vs-code drift.** MANUAL.md claims vs actual behavior; README describing v12 while code lags (tracked, confirmed intentional).
8. **Session constraints log.** "No subagents," model choices, permission denials — written down so post-mortems know what rules were in play.

---

## 13. Prompt Pattern Appendix

Recurring prompt shapes reconstructed from the artifacts, generalized:

**Seed absorption (Genesis):**
> "Here is my working module `<path>` and my model files. Organize them into a project: add a README explaining what it does, a project log, and a .gitignore. Don't change module behavior."

**Expansion wave (P2):**
> "Add `<capabilities>` to the module. Extend the Pester suite to cover each new function. Update MANUAL.md sections for anything user-visible. Add a build script if one doesn't exist."

**Mechanical refactor (P3):**
> "Split the monolith into Public/ and Private/ files by domain: AI, Memory, Network, Profile. Keep function bodies byte-identical. Regenerate the psd1 export list in the same change."

**Inventory-before-action (Purification):**
> "List everything dead, duplicated, debug-only, or embarrassing in this repo. Classify each item. Do not delete anything yet."

**Atomic deletion (Purification):**
> "Delete `<items>` as separate commits, one concern each. Use git mv for the renames `<old>`→`<new>` so history follows. Show me the tree before each commit."

**Plan-first (Convergence):**
> "Draft a merge plan comparing `<toolkit A>` and `<toolkit B>`: requirements trace, scope boundaries, key technical decisions, implementation units with test scenarios and verification commands, risks with mitigations, rollout steps. Mark open questions as resolved-in-planning or deferred."

**Gated review (Phase 7):**
> "Run the structured review pipeline against the working tree. Archive metadata, synthesized findings, and the full diff under `.context/`. Apply safe_auto fixes; verify requires_verification fixes by executing their proof commands; route the rest manual/advisory/human with reasons."

**Auditor dispatch (any time):**
> "Using the `<audit-agent>` definition: classify every legacy function COMPLETE/PARTIAL/STUB with one-line evidence; return only the mandated tables."

---

## 14. Failure Museum

Mistakes actually made, preserved because each one teaches a guardrail:

1. **The stray `}` file** (`7047d4e` deletes a file literally named `}`). An agent once wrote redirection output to a filename instead of stdout. Guardrail: review `git status` after every session; commit nothing you can't explain.
2. **Manifest↔module export drift** (P1 finding #1, conf 0.90). Functions existed in the psm1 but not the psd1 — invisible until someone imported via the manifest. The old build gate (`>=48` exports) passed anyway. Guardrail: set-equality parity checks, not threshold checks; test the *user-visible* import path.
3. **Hardcoded absolute paths** (`E:\Projects`, `E:\Models` baked into defaults; fix #6). The agent copied the author's machine into the product. Guardrail: derive from `$env:USERPROFILE`; grep for drive letters before review.
4. **Non-hermetic tests** (finding #5, conf 0.80). Early test runs could hit real downloads and real installs. Guardrail: staging roots + env isolation (`HAWK_CONFIG_PATH`), and treat "test touched the network" as a defect.
5. **Deleted CI left a misleading commit message later** ("CI/CD fixes" at `f21b7af` added no CI). Guardrail: agent-written commit messages describe the diff, not the intention.
6. **Remote-script execution unpinned** (finding #7). Installer fetched binaries over the network; checksum pinning was advisory, domain legitimacy had to be verified manually. Guardrail: pin hashes for anything executed; verify domains before downgrading severity.
7. **Docs written ahead of code** (finding #17). Harmless here because the human declared it intentional staging — but only because someone *asked*. Guardrail: route intent questions to humans; never let the agent resolve them by assumption.
8. **Plan units deferred without tracking** (finding #15: R1, R5–R8, R10 unimplemented). The plan promised eleven units; reality shipped fewer. Guardrail: regenerate the requirements-completeness line after every milestone.

---

## 15. Final Checklist

Running an agentic project end-to-end? In order:

- [ ] Author auditor agents with `edit/bash: deny` and pinned cheap models
- [ ] Create `.context/`, `.memory/`, `docs/plans/` working dirs
- [ ] Decide and log session constraints (subagents? inline edits?)
- [ ] Seed with a real artifact, not a blank slate
- [ ] Expansion waves: features + tests + docs in the same commit
- [ ] Refactors: human picks partition, agent moves bytes, manifest updated same-commit
- [ ] Schedule purification days; one concern per commit; `git mv` for renames
- [ ] Write `AGENTS.md` *early*
- [ ] Big moves: brainstorm → plan (requirements trace, units, risks) → approve each stage → execute
- [ ] Gated review: archive run, confidence-gate findings, route by risk, demand proof for fixes
- [ ] Publish the requirements-completeness line
- [ ] Keep a residual-work ledger with explicit routes
- [ ] Maintain the failure museum — every incident becomes a guardrail

---

*Sources: git log `main` (`bb5fc30`…`e1336b1` + working tree), `docs/plans/2026-08-22-001-feat-hawkward-powershellops-merge-plan.md`, `.context/systematic/ce-review/20260822-220044-57a58856/{metadata.json,synthesized-findings.md}`, `.opencode/agent/hawk-audit-{incomplete,redundancy,arch}.md`, `MANUAL.md`, `README.md`, `hawk-installer/**`.*
