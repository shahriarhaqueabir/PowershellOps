# 🦅 PowershellOps — Quick Reference Manual

> v11.3 · Ops Toolkit  
> Load time: **~137ms** (module) · **~2.3s** (full profile)  
> Total: **103 exported functions** · **safe `hawk-*` aliases** · **4 consolidated dispatch verbs** · **7 scenario workflows**

---

## 1. Dashboard

```
dash              # Re-render the startup dashboard
watch             # Live-refresh dashboard (Ctrl+C to exit)
```

The dashboard queries Ollama `/api/tags` (2s timeout) to report AI status (ACTIVE/STANDBY), reads `$global:HawkProjectRoot`, and renders commands organized into 7 sub-category groups. Columns auto-fit to console width (1/2/4). `watch` polls every 2 seconds (configurable via `-IntervalSeconds`).

---

## 2. 🖥️ SYSTEM

### System Health (`health`, `spec`, `uptime`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `health` | `Get-HawkHealth` | `Get-CimInstance Win32_OperatingSystem` → total RAM, free RAM; `Get-CimInstance Win32_Processor` → avg CPU load%; `(Get-Process).Count` → process count; handle count via `Measure-Object -Sum HandleCount` |
| `spec` | `Get-HawkSpec` | `Get-CimInstance Win32_Processor` (Name, Cores); `Get-CimInstance Win32_VideoController` (GPU Description). Cached 300s. |
| `uptime` | `Get-HawkUptime` | `(Get-CimInstance Win32_OperatingSystem).LastBootUpTime` → computes `(Get-Date) - $lastBoot`. Cached 10s. |

### System Hardware (`ram`, `battery`, `display`, `hyperv`, `powerplan`, `license`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `ram` | `Get-HawkRamInfo` | `Get-CimInstance Win32_PhysicalMemory` → BankLabel, CapacityGB (via `/1GB`), Speed (MHz), Manufacturer. Cached 600s. |
| `battery` | `Get-HawkBattery` | `Get-CimInstance Win32_Battery` → DesignCapacity, FullChargeCapacity, health% (`Full / Design * 100`). Returns `'No battery hardware tracked'` if absent. Cached 30s. |
| `display` | `Get-HawkDisplay` | `Get-CimInstance Win32_VideoController` → Description, VideoModeDescription. Cached 600s. |
| `hyperv` | `Get-HawkHypervisor` | `(Get-CimInstance Win32_ComputerSystem).Model` → matches `(VirtualBox\|VMware\|Virtual Machine\|Hyper-V\|QEMU\|KVM\|Xen)` → returns `'Virtual'` or `'Physical'` with Model name |
| `powerplan` | `Get-HawkPower` | `Get-CimInstance -Namespace root\cimv2\power Win32_PowerPlan -Filter "IsActive=True"` → ElementName |
| `license` | `Get-HawkLicense` | `Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId='55c92734-...'"` → LicenseStatus (Licensed/Unlicensed/N/A), PartialProductKey |

### System Storage (`disk`, `temp`, `clip`, `smarts`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `disk` | `Get-HawkDiskPressureAudit` | `Get-CimInstance Win32_LogicalDisk` (DriveType=3) → SizeGB, FreeGB, FreePercent (`Free / Max(1,Size) * 100`). Cached 30s. |
| `temp` | `Get-HawkTempCheck` | `[System.IO.Directory]::EnumerateFiles($env:TEMP, '*', AllDirectories)` → sums file lengths via `[System.IO.FileInfo]`. Returns total SizeMB. |
| `clip` | `Get-HawkClipCheck` | `Get-Clipboard -Raw` → character count. Returns 0 if unavailable or empty. |
| `smarts` | `Get-HawkDriveHealth` | `Get-CimInstance -Namespace root\wmi MSStorageDriver_FailurePredictStatus` → InstanceName, PredictFailure. May return empty on systems without SMART support via WMI. |

### System Performance (`res`, `port`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `res` | `Get-HawkResourceMap` | `Get-Process \| Sort-Object WorkingSet -Descending \| Select -First 10` → process name, PID, CPU (s), RAM (MB via `WorkingSet / 1MB`). Cached 5s. |
| `port` | `Get-HawkPortMap` | Prefers `Get-NetTCPConnection -State Listen` on Windows; falls back to `[IPGlobalProperties]::GetActiveTcpListeners()` → port, PID, process name (via `Get-Process` lookup). Fallback shows `'System Listen Stack'`. Cached 10s. |

---

## 3. 🛡️ SECURITY

### Access & Firewall (`admin`, `shield`, `fw`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `admin` | `Get-HawkAdmin` | `Get-LocalGroupMember -Group Administrators` → Name, PrincipalSource, ObjectClass |
| `shield` | `Get-HawkShield` | `Get-MpComputerStatus` → AntivirusEnabled, RealTimeProtectionEnabled, LastQuickScanTime, LastQuickScanResult, AMServiceEnabled |
| `fw` | `Get-HawkFirewallAudit` | `Get-HawkPortMap` for active listeners → `Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow` → extracts `LocalPort` via `Get-NetFirewallPortFilter` → cross-refs each listener; flags unmatched ports as `NO_MATCHING_INBOUND_ALLOW_RULE`. Falls back to `'NetSecurity Module Missing'` if cmdlets unavailable. Cached 60s. |

### Persistence & Anomalies (`boot`, `schedtask`, `ghost`, `sus`, `storm`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `boot` | `Get-HawkBootMap` | Enumerates `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run` and `HKCU:\...\Run` via `Get-ItemProperty` → filters out `PS*` properties → returns Hive, Name, Target. Cached 300s. |
| `schedtask` | `Get-HawkScheduledTaskRiskAudit` | `Get-ScheduledTask \| Where-Object State -ne Disabled -and TaskPath -notmatch '^\\\\Microsoft'` → returns TaskName, TaskPath (first 10). Does not inspect publishers or executable paths. Cached 300s. |
| `ghost` | `Get-HawkGhostPortAudit` | `Get-HawkPortMap \| Where-Object Process -in @('Unknown','System Listen Stack')` → ports whose owning PID has no matching process (orphaned). Handles both `Get-NetTCPConnection` and fallback paths. |
| `sus` | `Get-HawkSuspiciousProcessAudit` | `Get-Process \| Where-Object Path -match '(\\AppData\\\|\\Temp\\\|\\Windows\\Temp\\)'` → returns Name, Id, Path, CPU, RAMMB. |
| `storm` | `Get-HawkEventStormAudit` | `Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(15 min ago)} -MaxEvents 200` → groups by `ProviderName`, returns top 5 counts. Application log only, last 15 min. Cached 20s. |

### Inventory & Data Protection (`cert`, `dump`, `badfile`, `link`, `lock`, `sparse`, `compress`, `patch`, `driver`, `recent`, `secretredact`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `cert` | `Get-HawkCert` | `Get-ChildItem Cert:\CurrentUser\My` → Subject, Thumbprint, NotAfter |
| `dump` | `Get-HawkDump` | `Get-ChildItem "$env:windir\Minidump"` → lists all dump files with Name, Length |
| `badfile` | `Get-HawkBadFile` | `Get-ChildItem -File` → filters files >500MB; cross-refs known ransomware extensions (.encrypt, .locked, .crypt, .xyz, .zepto, .cerber). Returns counts and largest file size. |
| `link` | `Get-HawkLink` | `New-Object -ComObject WScript.Shell` → resolves each `.lnk` file in current directory via `CreateShortcut().TargetPath`. Returns Name and Target. |
| `lock` | `Get-HawkLock` | Attempts `[System.IO.File]::Open($path, 'Open', 'ReadWrite', 'None')` on files in target path (default: current dir) → reports locked files with exception message. |
| `sparse` | `Get-HawkSparseFile` | `Get-ChildItem -Recurse \| Where-Object Attributes -band [System.IO.FileAttributes]::SparseFile` → FullName, Length. First 20. |
| `compress` | `Get-HawkCompressedDir` | `Get-ChildItem -Recurse \| Where-Object PSIsContainer -and Attributes -band [System.IO.FileAttributes]::Compressed` → FullName, CompressedSizeKB. First 20. |
| `patch` | `Get-HawkPatchHistory` | `Get-CimInstance Win32_QuickFixEngineering` → HotFixID, InstalledOn. Sorted descending, first 5. |
| `driver` | `Get-HawkDriverAudit` | `Get-CimInstance Win32_PnPSignedDriver` → filters `IsSigned -eq $false` → DeviceName, DriverVersion, DriverDate. First 10. |
| `recent` | `Get-HawkRecent` | `Get-ChildItem (Join-Path $env:APPDATA 'Microsoft\Windows\Recent')` → Name, LastWriteTime. Sorted descending, first 5. |
| `secretredact` | `Protect-HawkSensitiveText` | Regex `$script:HawkSensitiveNamePattern` matches keys containing `secret`, `token`, `password`, `credential`, `connection.?string`, `sas`, `bearer`, `api.?key`, `private.?key` → replaces values with `<REDACTED>`. Handles both `key=value` and JSON `"key":"value"` formats. |

---

## 4. 🌐 NETWORK

### Connectivity (`ping`, `wifi`, `established`, `dns`, `dnscache`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `ping` | `Get-HawkNetCheck` | `Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet` → returns `$true`/`$false` for Internet reachability |
| `wifi` | `Get-HawkWifi` | `netsh wlan show interfaces` → parses SSID, Signal% from output. Returns `'Disconnected'`/`'N/A'` if no Wi-Fi interface. |
| `established` | `Get-HawkEstablished` | `Get-NetTCPConnection -State Established` → LocalPort, RemotePort, RemoteAddress, ProcessName (resolved from OwningProcess). First 20, sorted by RemoteAddress. Falls back gracefully if cmdlet unavailable. |
| `dns` | `Get-HawkDnsBench` | `Resolve-DnsName google.com -Server 1.1.1.1/8.8.8.8/9.9.9.9 -QuickTimeout` → measures response time (ms) per resolver. Uses Stopwatch for precision. |
| `dnscache` | `Get-HawkDnsCache` | `Get-DnsClientCache` → Entry, Type, TimeToLive, DataLength. First 20, sorted by TTL. |

### Services (`linkspeed`, `smb`, `hosts`, `nettriage`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `linkspeed` | `Get-HawkLinkSpeed` | `Get-NetAdapter \| Where-Object Status -eq Up` → Name, LinkSpeed, InterfaceDescription, MacAddress |
| `smb` | `Get-HawkShare` | `Get-CimInstance Win32_Share` → Name, Path, Description |
| `hosts` | `Get-HawkHostsCheck` | `Get-Content "$env:windir\System32\drivers\etc\hosts"` → filters comment/blank lines, parses each entry into IP + Hostname columns |
| `nettriage` | `Get-HawkNetworkTriage` | `Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"` → Description, IPAddress, MACAddress |

---

## 5. ⚙️ ENVIRONMENT

### Configuration

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `envmap` | `Get-HawkEnvMap` | `Get-ChildItem Env:` → Name, Value. No built-in redaction (pipe through `secretredact` to redact). |
| `path` | `Get-HawkPathAudit` | `$env:Path -split ';'` → validates each entry with `Test-Path`; flags missing/inaccessible |
| `app` | `Get-HawkApp` | `Get-ItemProperty` on `HKLM:\Software\...\Uninstall\*`, `Wow6432Node\...\Uninstall\*`, `HKCU:\...\Uninstall\*` → DisplayName, DisplayVersion. |
| `where` | `Get-HawkAppLocation` | `Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue` → returns full path(s) of an executable in PATH |
| _(none)_ | `Get-HawkProject` | Returns `$global:HawkProjectRoot` (or the derived checkout/profile root, or `$HAWK_PROJECT_ROOT`) |

---

## 6. 🧠 AI & SEARCH

### Query (`ai`, `ggl`, `intent`, `aiprofile`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `ai` | `Invoke-HawkAI` | Sends prompt + piped input as `{prompt}` to Ollama `HawkPowershell` at `http://127.0.0.1:11434/api/generate` (`stream: true`). Constructs a system contract, context envelope from `Build-HawkAIContextPacket`, and pipeline data. Uses `HttpClient.PostAsync` + `StreamReader.ReadLine` for token-by-token streaming. Supports `-Remember`, `-RedactSensitive`, `-MaxRetries` (with 3s back-off). |
| `ggl` | `Invoke-HawkSearch` | Without `-AI`: opens browser (`Start-Process $url`). With `-AI`: POSTs to DuckDuckGo Lite, extracts `uddg=` redirect links, resolves via `Resolve-HawkDuckDuckGoHref`, scrapes up to N pages (configurable via `-Sources`, default 5), strips `<style>`/`<script>`/HTML tags, runs quality scoring and prompt-injection detection, then pipes to `Invoke-HawkAI` for synthesis. Rate-limited to one request per 5s. |
| `intent` | `Get-HawkAIIntent` | Classifies user prompt via regex matching against `\b(search|web|online)\b` → Research, `\b(command|script|cmdlet)\b` → Shell, `\b(compare|changed|since)\b` → Compare, `\b(summarize|explain|why)\b` → Explain. Returns `'AnalyzeData'` if no pattern matches. |
| `aiprofile` | `Get-HawkAIDataProfile` | Profiles piped input: determines Kind (`Empty`/`Text`/`Table`/`Object`), Row count, Column names (first 24, excludes PS* properties). Does not compute value ranges, null %, or memory size. |

### Quality (`quality`, `injecttest`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `quality` | `Get-HawkSourceQualityScore` | Heuristic score (0-100) for scraped web content: base 50, +20 if content >200 chars, +15 if >800 chars, +15 if URL from `.gov`/`.edu`/`.org`. Returns `[Math]::Min(100, score)`. |
| `injecttest` | `Test-HawkPromptInjection` | Tests payload against regex: `ignore (previous\|above\|all) instructions`, `you are now`, `system prompt`, `DAN.*mode`. Returns `$true`/`$false` only (no severity). |

### AI Status

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `aistatus` | `Get-HawkAIStatus` | `Invoke-RestMethod http://127.0.0.1:11434/api/tags` → lists all pulled Ollama models with name, size, modification date |

---

## 7. 🧠 MEMORY SYSTEM

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `remember` | `Add-HawkMemory` | Appends a JSONL entry to `$script:HawkMemoryFile` with Id (`mem_{yyyyMMdd_HHmmss}_{guid[0:6]}`), Type (note/preference/runbook/session/web/sysops), Tags, Text (auto-redacted via `Protect-HawkSensitiveText`), Source, Created (ISO 8601), Confidence (low/medium/high/user), Pinned flag. Supports `-WhatIf`. |
| `recall` | `Search-HawkMemory` | Reads `hawk-memory.jsonl`, parses lines with `ConvertFrom-Json -AsHashtable` into `[HawkMemoryEntry]`. Accepts `-Query` (term-matching), `-Pinned`, `-First`. Scores results by term hit count (+2 if pinned), sorts by score desc then Created desc. |
| `memmap` | `Get-HawkMemoryMap` | Reads entire `hawk-memory.jsonl`; supports `-Tag`, `-Pinned`, `-First` (default 40). Sorts by Created desc. |
| `readmem` | `Read-HawkMemory` | Reads all entries from `hawk-memory.jsonl` and returns them as `[HawkMemoryEntry]` objects. No parameter filtering (use `Search-HawkMemory` for queries). |
| `memfile` | `Get-HawkMemoryFile` | Returns the resolved path to `hawk-memory.jsonl`; creates the `Memory/` directory if absent. |

### AI Context Builders

| Full command | Under the hood |
|-------------|----------------|
| `Build-HawkAIContextPacket` | Builds context envelope: determines Mode (Fast/Deep/Balanced) from instruction keywords, gets Intent via `Get-HawkAIIntent`, profiles data via `Get-HawkAIDataProfile`, optionally appends memory context via `Build-HawkAIMemoryContext`. Returns `[PSCustomObject]` with Intent, Mode, and formatted Text. |
| `Build-HawkAIMemoryContext` | Reads top 3 pinned entries + up to `$First` entries matching query → formats as bulleted memory context lines. |

### Memory Format Helpers

| Full command | Under the hood |
|-------------|----------------|
| `Format-HawkMemoryId` | Generates ID string: `mem_{yyyyMMdd_HHmmss}_{6-char-guid}` |
| `Format-HawkMemorySnippet` | Truncates memory text to configurable length (default 220 chars), strips newlines. |

---

## 8. 📊 REPORTS

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `hawkreport` | `New-HawkReport` | Gathers: `Get-HawkAIStatus` (AI engine), `Get-HawkDiskPressureAudit` (volumes), `Get-HawkResourceMap` (top 10 processes), `Get-HawkPortMap` (listeners), `Get-HawkFirewallAudit` (firewall cross-ref), `Get-HawkBootMap` (startup persistence), `Get-HawkScheduledTaskRiskAudit` (scheduled tasks), `Get-HawkEventStormAudit` (log storms). Suppresses `Write-HawkHeader` during collection. Renders as console tables via `Write-HawkReportTable` + saves Markdown to `Reports/hawkreport-{timestamp}.md`. File write respects `-WhatIf`; table rendering does not. Supports `-Format Json`. |
| `reportpath` | `Get-HawkReportPath` | Returns `$script:HawkReportRoot/hawkreport-{yyyyMMdd-HHmmss}.{ext}`. Creates `Reports/` directory if absent. |

### Report Formatting Pipeline

| Full command | Under the hood |
|-------------|----------------|
| `ConvertTo-HawkReportMarkdown` | Converts `$report` hashtable into structured Markdown — H2 sections, tables, code blocks |
| `ConvertTo-HawkMarkdownTable` | Converts an array of objects into a GitHub-flavored Markdown table |
| `Format-HawkReportCell` | Truncates/pads a single value for table cell display |
| `Write-HawkReportTable` | `Write-Host` rendering of a bordered table — Title, icon, color, column specifiers with inline padding |

---

## 9. 🔧 MODULE & SHELL

### Shell (`dash`, `watch`, `hawkman`, `reload`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `dash` | `Show-HawkDashboard` | Queries Ollama `/api/tags` (2s timeout), resolves project root, renders 7-category sub-grouped command grid with aliases. Columns auto-fit to console width (1/2/4). Uses `Get-Command -Module HawkwardHybrid` for command listing and `Get-Alias` for alias resolution. |
| `watch` | `Watch-HawkDashboard` | `while($true) { Clear-Host; Show-HawkDashboard; Start-Sleep -Seconds 2 }` — polls and re-renders every 2 seconds (configurable via `-IntervalSeconds`). Gates on `Test-HawkInteractiveSession`. |
| `hawkman` | `Show-HawkManual` | Opens MANUAL.md (`Invoke-Item $manualPath`) in default editor/browser. |
| `reload` | `Update-HawkProfile` | Dot-sources `$PROFILE` (`. $PROFILE`) — reimports module, re-runs `Initialize-HawkProfile`. Supports `-WhatIf`. |

### Config & Utilities (`init`, `proj`, `projset`, `explorer`, `cached`)

| Alias | Full command | Under the hood |
|-------|-------------|----------------|
| `init` | `Initialize-HawkProfile` | Sets `$global:HawkProjectRoot` → imports prerequisites via `Import-HawkPrerequisite` (`Terminal-Icons`, `PSReadLine`, `PSTree`) → validates expected module metadata → configures PSReadLine (prediction source History + ListView mode) → sets safe `hawk-*` aliases (`Set-HawkAliases`) → sets prompt (`Set-HawkPrompt`). `-SkipModules` bypasses prereq import; `-ShowDashboard` forces dashboard render. Supports `-WhatIf`. |
| `proj` | `Get-HawkProject` | Returns the current `$global:HawkProjectRoot` path |
| `projset` | `Invoke-HawkProject` | Sets `$global:HawkProjectRoot` to a new path (or defaults to the derived checkout/profile root). Supports `-WhatIf`. |
| `explorer` | `Invoke-ExplorerHere` | `Start-Process explorer.exe -ArgumentList (Get-Location).Path` — opens current directory in File Explorer |
| `cached` | `Invoke-HawkCachedData` | Thread-safe key-value cache (`[hashtable]::Synchronized`) with per-key TTL. Accepts `-Key`, `-ExpirySeconds`, `-ScriptBlock`. Used internally by health checks, firewall audit, port map, and scheduled task audit. |

### Module Maintenance

| Full command | Under the hood |
|-------------|----------------|
| `Install-HawkPrerequisite` | `Install-Module Terminal-Icons, PSReadLine, PSTree -Scope CurrentUser -Force -ErrorAction Stop`, then validates the installed module metadata against the expected author/company profile. Supports `-WhatIf`. |
| `Import-HawkPrerequisite` | `Import-Module Terminal-Icons, PSReadLine, PSTree -ErrorAction SilentlyContinue`. Returns status per module (Imported/Missing/Failed). |
| `Update-HawkModule` | Walks up from `$PSScriptRoot` to find `.git` directory → `git pull` → `Remove-Module HawkwardHybrid` → `Import-Module HawkwardHybrid.psd1 -Force -Global`. Supports `-WhatIf`. |

---

## 10. 🔄 WORKFLOWS

> Each workflow combines multiple single-purpose functions into a scenario-driven scored report with color-coded status, drill-down sections, and actionable recommendations. Workflows use `Invoke-HawkCachedData` for per-key TTL caching across runs.

### Display helpers (module-internal)

These three helpers are shared by all workflow functions and are not exported:
- `Write-HawkWorkflowBanner` — Renders the decorated box banner with title, timestamp, and hostname
- `Write-HawkWorkflowSection` — Section header with dynamic rule-line padding, configurable foreground color
- `Write-HawkRecommendations` — Iterates recommendation tuples (icon, color, message) and renders each with `Write-Host`

### Workflow aliases

| Alias | Full command | What it aggregates | Data sources |
|-------|-------------|-------------------|-------------|
| `dailyops` | `Invoke-HawkDailyOps` | Health + uptime + disk + network + DNS + events + temp + power | 8 sub-functions, scored 0–100, C: <10% free → 🔴 CRITICAL + score penalty |
| `sysreview` | `Invoke-HawkSystemReview` | Spec + health + uptime + RAM + disk + resource map + ports + temp + hypervisor + power + license | 11 sub-functions, sections: HARDWARE / PERFORMANCE / RESOURCE CONSUMERS / LISTENING PORTS / STORAGE / LICENSE |
| `secaudit` | `Invoke-HawkSecurityAudit` | Firewall + boot + scheduled tasks + ghost ports + suspicious procs + events + admin + shield | 8 sub-functions, sections: DEFENDER / FIREWALL / STARTUP & TASKS / ADMINISTRATORS / ANOMALIES |
| `netdiag` | `Invoke-HawkNetworkDiagnostics` | NetCheck + Wi-Fi + DNS bench + DNS cache + link speed + shares + hosts + established + triage | 9 sub-functions, sections: CONNECTIVITY / DNS RESOLVERS / INTERFACES / SHARES / HOSTS FILE |
| `threat` | `Invoke-HawkThreatHunt` | Suspicious procs + ghost ports + events + bad files + locked files + sparse files + compressed dirs + firewall | 8 sub-functions, categorizes findings into THREATS / WARNINGS / INFO buckets |
| `change` | `Invoke-HawkChangeAudit` | Recent files + patches + drivers + dumps + boot + certs | 6 sub-functions, sections: RECENT FILES / UPDATES / DRIVERS / CRASH DUMPS / STARTUP / CERTIFICATES |
| `compliance` | `Invoke-HawkComplianceCheck` | Admin count + Defender + firewall gaps + non-MS tasks + boot entries + patches + license + hypervisor + ports | 9 CIS-inspired checks, returns pass/fail tally with percentage score |

### Scoring system

All scored workflows (`dailyops`, `sysreview`, `secaudit`, `netdiag`, `change`) share this pattern:
- Start at **100**, deduct for each finding below thresholds
- Floor at **0** (`[Math]::Max(0, $score)`)
- Thresholds: **≥80 🟢** (good), **50–79 🟡** (attention needed), **<50 🔴** (critical)
- `compliance` uses a separate pass-rate percentage instead

### Return value

Every workflow returns `[PSCustomObject]` for programmatic use. Common properties:
```powershell
$result = dailyops
$result.Score            # 0-100 numeric score
$result.Recommendations  # Array of [icon, color, message] tuples
$result.Health           # Individual sub-function result objects
```

---

## 11. CONSOLIDATED DISPATCH

Four "umbrella" commands organize the most common queries under a single verb:

| Alias | Full name | What it does |
|-------|-----------|-------------|
| `sys` | `Get-HawkSystem` | Dispatches to `Get-HawkSpec`, `Get-HawkHealth`, `Get-HawkUptime`, `Get-HawkRamInfo`, `Get-HawkBattery`, `Get-HawkDisplay`, `Get-HawkDiskPressureAudit`, `Get-HawkResourceMap`, `Get-HawkPortMap` via `-Type` parameter |
| `audit` | `Get-HawkAudit` | Dispatches to `Get-HawkFirewallAudit`, `Get-HawkBootMap`, `Get-HawkScheduledTaskRiskAudit`, `Get-HawkGhostPortAudit`, `Get-HawkSuspiciousProcessAudit`, `Get-HawkEventStormAudit`, `Get-HawkPatchHistory`, `Get-HawkTempCheck`, `Get-HawkClipCheck` via `-Type` |
| `net` | `Get-HawkNetwork` | Dispatches to `Get-HawkNetCheck`, `Get-HawkWifi`, `Get-HawkDnsBench`, `Get-HawkLinkSpeed`, `Get-HawkShare`, `Get-HawkHostsCheck`, `Get-HawkDnsCache`, `Get-HawkNetworkTriage` via `-Type` |
| `env` | `Get-HawkEnv` | Dispatches to `Get-HawkEnvMap`, `Get-HawkPathAudit`, `Get-HawkApp` via `-Type` |

---

## 12. CONFIGURATION

```powershell
# Change project root at init
Initialize-HawkProfile -ProjectRoot 'D:\Work' -ShowDashboard

# Skip prereq module import on init
Initialize-HawkProfile -SkipModules

# Suppress dashboard
$env:HAWK_NO_DASH = '1'
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `$env:HAWK_NO_DASH` | unset | Set to `1` to suppress dashboard |
| `$env:CI` | unset | Automatically suppresses dashboard |
| `$global:HawkProjectRoot` | derived checkout/profile root or `$HAWK_PROJECT_ROOT` | Project root for `proj`/`projset` |
| `$script:HawkSensitiveNamePattern` | regex | Pattern for `Protect-HawkSensitiveText` redaction |

---

## 13. PIPELINE TIPS

```powershell
# Chain commands — all Get-Hawk* output objects work with Where-Object, Format-Table, Export-Csv
port | Format-Table -AutoSize
disk | Where-Object { $_.FreePercent -lt '10%' }
boot | Export-Csv startup.csv

# Pipe to AI
res | ai "Which process is using the most RAM?"
fw | ai "Any gaps in firewall rules?"

# Run a full daily ops scan
dailyops

# Run a security audit and check the score
secaudit | ForEach-Object { $_.Score }

# Export compliance check results
compliance | Export-Csv compliance-report.csv

# Redact before sending to AI
envmap -IncludeSensitive | secretredact | ai "Summarize the environment"

# Search the web + synthesize
ggl "windows firewall hardening" -AI

# Save AI output to memory
res | ai "What is using the most memory?" -Remember
```

---

## 14. PERFORMANCE

| Operation | Time |
|-----------|------|
| Module import (bare) | ~137ms |
| Init with prerequisites check | ~336ms |
| Full profile load | ~2.3s |
| Dashboard render | ~50ms |
| First audit run | ~500ms–2s (depends on WMI queries) |
| AI query (Ollama, first) | ~5–20s (model load) |
| AI query (Ollama, cached) | ~500ms–5s |
| Daily ops scan (cached) | ~1–3s |
| Compliance check (cached) | ~2–5s |

The 2.3s profile load is mainly from `Import-HawkPrerequisite` checking PSGallery. Second runs are faster due to caching. AI first-query latency depends on whether `hawkpowershell:latest` is already loaded in Ollama.

---

## 15. COMPLETE ALIAS INDEX

> Loaded shell aliases are now prefixed with `hawk-` to avoid shadowing standard commands. The labels below map to the underlying Hawk command families.

### System
`health` · `spec` · `uptime` · `ram` · `battery` · `display` · `hyperv` · `powerplan` · `license` · `disk` · `temp` · `clip` · `smarts` · `res` · `port`

### Security
`admin` · `shield` · `fw` · `boot` · `schedtask` · `ghost` · `sus` · `storm` · `cert` · `dump` · `badfile` · `link` · `lock` · `sparse` · `compress` · `patch` · `driver` · `recent` · `secretredact`

### Network
`ping` · `wifi` · `established` · `dns` · `dnscache` · `linkspeed` · `smb` · `hosts` · `nettriage`

### Environment
`envmap` · `path` · `app` · `where`

### AI
`ai` · `ggl` · `aistatus` · `intent` · `aiprofile` · `quality` · `injecttest`

### Memory
`remember` · `recall` · `memmap` · `readmem` · `memfile`

### Reports
`hawkreport` · `reportpath`

### Workflows (new in v11.3)
`dailyops` · `sysreview` · `secaudit` · `netdiag` · `threat` · `change` · `compliance`

### Module & Shell
`dash` · `watch` · `hawkman` · `reload` · `init` · `proj` · `projset` · `explorer` · `cached`

### Dispatch
`sys` · `audit` · `net` · `env`
