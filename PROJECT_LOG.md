# 🦅 Hawkward Sentinal — Project Build Log

> A complete record of how this project was developed: the rules, the prompts, the pitfalls, and the optimal workflow from blank terminal to Sentinel Edition v11.2.

---

## Part 1 — The Do's ✅

### Architecture & Structure

| Rule | Rationale |
|---|---|
| **Keep all logic in `HawkwardHybrid.psm1`; use the profile only as a loader** | A thin `Microsoft.PowerShell_profile.ps1` that just calls `Import-Module` and `Initialize-HawkProfile` means the profile itself almost never breaks, and the module can be tested independently |
| **Use a module manifest (`.psd1`)** | Enables versioning, dependency declarations, and proper `Export-ModuleMember` control |
| **Prefix every function with `Hawk`** | Prevents collisions with system cmdlets and makes tab-completion predictable (`Get-Hawk<Tab>`) |
| **Expose everything via short aliases in `Set-HawkAliases`** | Users type `ghostaudit`, not `Get-HawkGhostPortAudit`; aliases live in one place, easy to audit |
| **Use `$script:` scope for module-level state** | Prevents globals leaking out; `$script:HawkVersion`, `$script:HawkReportRoot`, etc. |
| **Use `$global:` only for values the user must be able to read** | `$global:HawkProjectRoot` is intentionally global so any script in the session can reference it |

### Coding Standards

| Rule | Rationale |
|---|---|
| **Always use `[CmdletBinding()]` on non-trivial functions** | Enables `-Verbose`, `-WhatIf` (with `SupportsShouldProcess`), and `-ErrorAction` |
| **Prefer `[PSCustomObject]@{}` for output objects** | Structured output pipes cleanly into `Format-Table`, `ConvertTo-Json`, and the Markdown converter |
| **`-ErrorAction SilentlyContinue` on read-only system calls, `Stop` on writes** | Audit functions must not crash the session; writes should surface errors |
| **Always `Dispose()` `HttpClient`, streams, and readers in `finally` blocks** | `Invoke-HawkAI` streams from Ollama — leaking handles causes memory pressure over long sessions |
| **Cache the Git prompt result for 2 seconds** | `Get-HawkPromptGitSegment` caches per-path/per-time to avoid invoking `git` on every keystroke |
| **Suppress the dashboard in non-interactive sessions** | Check `[Environment]::UserInteractive` and `[Console]::IsOutputRedirected` before rendering |
| **UTF-8 encoding at startup** | `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` — Nerd Font icons and emoji break without this |

### AI Integration

| Rule | Rationale |
|---|---|
| **Always ping `http://127.0.0.1:11434/api/tags` before sending a request** | Fail fast with a human-readable message rather than a 30-second timeout |
| **Use streaming (`stream: true`) and `HttpClient` directly** | `Invoke-RestMethod` buffers the entire response; streaming lets AI output appear token-by-token |
| **Pipe through `secretredact` before AI for sensitive data** | `envmap -IncludeSensitive | secretredact | ai` — never send raw secrets to any model |
| **Retry logic with back-off** | `Invoke-HawkAI` supports `-MaxRetries` with a 3-second sleep between attempts |
| **Model name in the custom `hawk-reasoning` Modelfile** | Using a named model means the Modelfile system prompt is always applied; avoids raw `ollama run` calls |

### Security Audit Functions

| Rule | Rationale |
|---|---|
| **Cross-reference ports against firewall rules, not just list them** | `fwaudit` / `nettriage` — a listener without a matching inbound allow rule is a gap worth knowing |
| **Fall back gracefully (`netstat`) when `Get-NetTCPConnection` fails** | Some restrictive environments block the Net cmdlets; `netstat -ano` works everywhere |
| **Filter `PS*` properties from registry key enumeration** | `Get-ItemProperty` injects `PSPath`, `PSChildName`, etc. — filter them or your startup list is noise |
| **Scheduled task risk: flag `powershell`, `pwsh`, `cmd`, `AppData`, `Temp`** | These are the most common persistence and LOLBin patterns |

### Report Generation

| Rule | Rationale |
|---|---|
| **Always save a Markdown file even in Console mode** | Console output truncates; the `.md` file is the full artefact |
| **Timestamped file names (`hawkreport-YYYYMMDD-HHmmss.md`)** | Makes diffing reports over time trivial |
| **`$script:HawkSuppressHeaders = $true` during report data collection** | The `Write-HawkHeader` calls inside each audit function are for interactive use; suppress them in batch collection |

---

## Part 2 — The Don'ts ❌

| Anti-Pattern | Why It Bites You |
|---|---|
| **Don't dot-source a giant profile directly** | A single syntax error in a 1500-line file halts the entire shell. Module-backed = isolated failure |
| **Don't use `Invoke-RestMethod` for streaming AI responses** | It buffers everything; the user sees nothing until the model finishes. Use `HttpClient` + `StreamReader` |
| **Don't use `$global:` for everything** | Pollutes the session namespace; use `$script:` inside the module |
| **Don't run `git status` in the prompt without caching** | Even a 50ms `git` call makes every Enter keypress feel sluggish. Cache per-path for ≥2 seconds |
| **Don't pipe sensitive env vars to AI without redacting first** | `envmap -IncludeSensitive | ai` would send API keys and connection strings to the model |
| **Don't hardcode your personal project path as the only option** | `$HawkDefaultProjectRoot = 'E:\Projects'` is a default; `Initialize-HawkProfile -ProjectRoot` overrides it |
| **Don't ignore `$LASTEXITCODE` after `git` calls** | `rev-parse --is-inside-work-tree` exits non-zero outside a repo; check it before using the output |
| **Don't catch and swallow all exceptions silently** | Use `Write-Warning` or `Write-Verbose` — silent failure makes debugging impossible |
| **Don't commit generated reports** | They contain live system data (PIDs, paths, installed software). Add `Reports/` to `.gitignore` |
| **Don't commit the third-party modules** | `Terminal-Icons`, `PSReadLine`, etc. are Gallery modules. Document them; don't vendor them |
| **Don't strip `PS*` from registry output manually after-the-fact** | Filter at the `Where-Object` stage: `Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*' }` |
| **Don't use `Format-Table` in functions that output objects** | Let the caller decide formatting; return `[PSCustomObject]` and let the pipeline handle it |
| **Don't render the dashboard in CI or piped sessions** | `$env:CI` and `[Console]::IsOutputRedirected` gates prevent garbage output in automated pipelines |

---

## Part 3 — Optimal Build Steps (Start to Finish)

### Phase 0 — Environment Setup

```powershell
# 1. Install PowerShell 7 (if not already present)
winget install Microsoft.PowerShell

# 2. Install Git
winget install Git.Git

# 3. Install Ollama (optional — for AI features)
winget install Ollama.Ollama

# 4. Install a Nerd Font (e.g. JetBrainsMono Nerd Font) via your terminal settings
# https://www.nerdfonts.com/font-downloads

# 5. Set your terminal to use the Nerd Font
```

### Phase 1 — Repository Bootstrap

```powershell
# Clone into the PowerShell profile directory
git clone https://github.com/YOUR_USERNAME/hawkward-hybrid "$HOME\Documents\PowerShell"

# Or init from scratch:
Set-Location "$HOME\Documents\PowerShell"
git init
git remote add origin https://github.com/YOUR_USERNAME/hawkward-hybrid
```

### Phase 2 — Module Scaffold

```
Documents\PowerShell\
├── Microsoft.PowerShell_profile.ps1   ← create first (thin loader)
└── Modules\
    └── HawkwardHybrid\
        ├── HawkwardHybrid.psd1        ← create second (manifest)
        └── HawkwardHybrid.psm1        ← create third (all logic)
```

**Manifest minimum (`HawkwardHybrid.psd1`):**
```powershell
@{
    RootModule        = 'HawkwardHybrid.psm1'
    ModuleVersion     = '11.2.0'
    GUID              = '<new-guid>'          # [guid]::NewGuid()
    Author            = 'your-name'
    PowerShellVersion = '7.0'
    FunctionsToExport = '*'
    AliasesToExport   = '*'
}
```

**Profile loader (`Microsoft.PowerShell_profile.ps1`):**
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$hawkModuleManifest = Join-Path $PSScriptRoot 'Modules\HawkwardHybrid\HawkwardHybrid.psd1'
if (-not (Test-Path $hawkModuleManifest)) {
    Write-Warning "Hawkward Hybrid module not found: $hawkModuleManifest"; return
}
try {
    Import-Module $hawkModuleManifest -Force -ErrorAction Stop
    Initialize-HawkProfile -ProjectRoot 'E:\Projects' -ShowDashboard
}
catch {
    Write-Warning "Hawkward Hybrid failed to initialize: $($_.Exception.Message)"
}
```

### Phase 3 — Module Development Order

Build the module in this order — each layer depends on the previous:

1. **Module-level variables** (`$script:HawkVersion`, `$script:HawkDefaultProjectRoot`, etc.)
2. **Internal helpers** (`Write-HawkHeader`, `Test-HawkInteractiveSession`, `Format-HawkReportCell`)
3. **Prompt functions** (`Get-HawkPromptGitSegment` → `Get-HawkPromptText` → `Set-HawkPrompt`)
4. **Prerequisite management** (`Install-HawkPrerequisites`, `Import-HawkPrerequisites`, `Set-HawkReadLine`)
5. **Audit functions** (Sentinel + Diagnostics + Environment suites)
6. **AI engine** (`Invoke-HawkAI`, `Invoke-HawkSearch`, `Protect-HawkSensitiveText`)
7. **Report engine** (`New-HawkReport`, `ConvertTo-HawkReportMarkdown`, `Write-HawkReportConsole`)
8. **Dashboard** (`Show-HawkDashboard`)
9. **Aliases** (`Set-HawkAliases`) — add each alias as you build its function
10. **Init entry point** (`Initialize-HawkProfile`) — wire everything together last
11. **`Export-ModuleMember -Function * -Alias *`** — final line of the module

### Phase 4 — Install Dependencies

```powershell
# Load the module temporarily
Import-Module .\Modules\HawkwardHybrid\HawkwardHybrid.psd1 -Force

# Install Gallery modules
Install-HawkPrerequisites

# Verify
Import-HawkPrerequisites
```

### Phase 5 — AI Model Setup

```powershell
# Ensure Ollama is running (system tray or: ollama serve)

# Create the custom hawk-reasoning model
ollama create hawk-reasoning -f .\AI\distilledqwen.modelfile

# Verify
aidoctor

# Quick smoke test
"What is Get-Process?" | ai
```

### Phase 6 — Verification

```powershell
# 1. Profile parser check + module availability + Ollama status
hawkdoctor

# 2. Full system audit
ghostaudit
susaudit
fwaudit
taskaudit
diskaudit
evntaudit

# 3. Generate a full report and inspect it
hawkreport
# Opens: Reports\hawkreport-YYYYMMDD-HHmmss.md

# 4. AI smoke test
resmap | ai 'Which process is using the most RAM?'
ggl "powershell best practices" -AI
```

### Phase 7 — Git Hygiene Before Push

```powershell
# Verify .gitignore is working
git status
# Should NOT show: Reports/, Help/, Scripts/InstalledScriptInfos/, or Modules/Terminal-Icons/ etc.

# Stage only owned files
git add Microsoft.PowerShell_profile.ps1
git add Modules/HawkwardHybrid/
git add AI/
git add README.md
git add .gitignore
git add PROJECTDETAILS.md
git add PROJECT_LOG.md

# Commit
git commit -m "feat: Hawkward Hybrid v11.2 - Sentinel Edition"

# Push
git push -u origin main
```

---

## Part 4 — Key Prompts That Drove This Project

These are the high-signal prompts used during development sessions to get the best AI-assisted results.

### Architectural prompts

```
"Refactor this single-file PowerShell profile into a proper module (psm1/psd1).
Keep the profile loader thin. All logic goes in the module."

"Add an Initialize-HawkProfile function that wires up PSReadLine, the custom 
prompt, all aliases, and optionally shows the dashboard. Call it from the profile."
```

### Audit function prompts

```
"Write a Get-HawkFirewallAudit function that cross-references Get-NetTCPConnection 
listeners against Get-NetFirewallPortFilter rules, flagging ports with no matching 
inbound allow rule. Fall back to netstat if Get-NetTCPConnection fails."

"Write Get-HawkSuspiciousProcessAudit that flags any running process whose 
executable path contains AppData or Temp. Use try/catch around $proc.Path."

"Write Get-HawkEventStormAudit that groups System log events by ID in the last 
30 minutes and returns any ID with more than 5 occurrences."

"Write Get-HawkBootMap to scrape HKLM and HKCU Run registry keys. Filter out 
PS* properties from Get-ItemProperty output."
```

### AI engine prompts

```
"Write Invoke-HawkAI that:
1. Pings Ollama on 127.0.0.1:11434 first and fails fast with a clear message
2. Streams the response token-by-token using HttpClient + StreamReader
3. Accepts pipeline input and buffers it
4. Supports -MaxRetries with 3-second back-off
5. Always Dispose() HttpClient in a finally block"

"Write Invoke-HawkSearch that:
- Without -AI: opens the browser
- With -AI: POSTs to DuckDuckGo Lite, extracts result-link hrefs, 
  resolves DDG redirects, scrapes up to 10 pages (3000 chars each), 
  strips HTML/script/style, then pipes to Invoke-HawkAI"
```

### Dashboard / prompt prompts

```
"Write a Show-HawkDashboard function that renders a box-drawing border header, 
then a 4-column grid of command suites (Sentinel, Diagnostics, Environment, 
AI & Workspace). Adapt column count to console width."

"Write Get-HawkPromptGitSegment that shows branch name and dirty/clean status 
with color. Cache the result per-path for 2 seconds to avoid git calls on 
every keypress."
```

### Report generator prompts

```
"Write New-HawkReport that collects all audit function outputs into an ordered 
hashtable, sets HawkSuppressHeaders during collection to silence Write-HawkHeader 
calls, then renders to Console (table) + saves Markdown. Support -Format Json too."

"Write ConvertTo-HawkMarkdownTable that auto-calculates column widths from data, 
truncates long cells with … , and escapes pipe characters in cell values."
```

### Hardening / cleanup prompts

```
"Audit every function for silent failure. Replace empty catch blocks with 
Write-Verbose or Write-Warning."

"Add Protect-HawkSensitiveText that regex-redacts key=value and JSON 'key':'value' 
patterns for: secret, token, password, passwd, pwd, credential, connectionstring, 
sas, bearer, apikey, privatekey."

"The dashboard should not render in CI environments or when output is redirected. 
Add Test-HawkInteractiveSession checking $env:CI and [Console]::IsOutputRedirected."
```

---

## Part 5 — Lessons Learned

| Session | Key Lesson |
|---|---|
| Early single-file era | A profile parse error = no shell. Moving to a module means a bad module = warning, but the session still starts |
| Adding AI streaming | `Invoke-RestMethod` buffers silently. Switch to `HttpClient.PostAsync` + `StreamReader.ReadLine` loop for token streaming |
| Git prompt performance | Calling `git status` on every prompt render caused noticeable lag. A 2-second path-keyed cache eliminated it |
| Web-to-AI scraping | DuckDuckGo Lite redirects links through `uddg=` encoded query params. `Resolve-HawkDuckDuckGoHref` handles this |
| Firewall audit | `Get-NetFirewallPortFilter` can throw in restricted environments. Store the error in `$script:HawkLastFirewallFilterError` and surface it in the output row |
| Registry scraping | `Get-ItemProperty` injects `PSPath`, `PSChildName`, `PSParentPath`, `PSProvider` — filter them with `$_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*'` |
| Report Markdown | `ConvertTo-HawkMarkdownTable` must escape `|` in cell values or it breaks the table. Use `.Replace('|', '\|')` |
| Modelfile system prompt | Adding the system prompt to a named Modelfile instead of inline in the payload means every `ai` call uses it without the caller having to think about it |
