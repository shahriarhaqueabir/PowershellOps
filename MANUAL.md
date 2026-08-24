# PowershellOps — Quick Reference Manual

> v12.0.0 · Agentic Stack for Windows  
> Load time: **~150ms** (module) · **~2.5s** (full profile)  
> Total: **126 exported functions** · **90 global aliases** · **4 alias suites** · **7 operational workflows** · **5 semantic recall commands** · **4 dispatch verbs**

---

## 1. Dashboard & Navigation

| Alias | Canonical | Description |
|:---|:---|:---|
| `dash` | `Show-HawkDashboard` | Renders the command dashboard grouped into 11 suites with AI engine ACTIVE/STANDBY header. Columns auto-fit to console width. |
| `hawkwatch` | `Watch-HawkDashboard` | Live-refresh dashboard every N seconds (`-IntervalSec`, default 10, min 3). Press `q` or `Esc` to exit. |
| `hawkman` | `Show-HawkManual` | Opens this manual in default editor/browser. |
| `hawkhelp` | `Invoke-HawkHelp` | Asks the local AI which Hawk command fits your task — injects full command reference into context. |
| `reload` | `Update-HawkProfile` | Dot-sources `$PROFILE` to pick up changes without restarting the shell. Prints elapsed ms. |

---

## 2. 🤖 AI ENGINE & WORKSPACE

### Core AI

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `ai` | `Invoke-HawkAI` | Streams piped input + prompt to local llama.cpp (`/v1/chat/completions`). Auto-starts server on connection failure. Retry logic with backoff. `-RedactSensitive` scrubs secrets via regex before send. |
| `hawkchat` | `Invoke-HawkChat` | Multi-turn REPL with 16-turn conversation memory. Commands: `/exit`, `/quit`, `/q`, `/clear`, `/help`. |
| `hawkmodel` | `Get-HawkModel` | Scans `$env:USERPROFILE\Models\GGUF` for `*.gguf`. Marks active model from config. `-Switch <substring>` persists new model to `hawk.config.json` and restarts llama-server. |
| `hawkdaily` | `Invoke-HawkDaily` | Runs full ops sweep (all suites), writes timestamped Markdown to `~\Documents\PowerShell\Reports\`. `-Open` opens report. `-RegisterTask` creates daily Task Scheduler entry at `-AtHour` (default 9). `-RemoveTask` deletes it. |
| `hawkwatch` | `Watch-HawkDashboard` | Clears screen and redraws dashboard every `-IntervalSec` (default 10s, min 3). `q`/`Esc` quits. |
| `proj` | `Invoke-HawkProject` | `cd` to configured `projectRoot` from `hawk.config.json`. |
| `projaudit` | `Get-HawkProjectAudit` | Walks `projectRoot`, finds git repos, shows branch, dirty file count, last commit. `-PassThru` returns objects. |
| `hawkreport` | `New-HawkReport` | Aggregates all suites (AI models, disk, resources, ports, firewall gaps, startup, task risks, event storms). Renders console + saves Markdown/JSON (`-Format`). `-Path` overrides output location. |

### Search & Web

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `ggl` | `Invoke-HawkSearch` | Without `-AI`: opens browser (`Start-Process`). With `-AI`: POSTs to DuckDuckGo Lite, extracts `uddg=` redirect links, resolves via scrapes up to N pages (`-Sources`, default 5), strips HTML, runs quality scoring + prompt-injection detection, pipes to `Invoke-HawkAI` for synthesis. `-Deep` = more sources + fuller pages. `-News` pulls Google News RSS (headlines + dates + sources → article bodies → local synthesis). Rate-limited to 1 req/5s. |

---

## 3. 🛡️ SECURITY AUDIT

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `ghostaudit` | `Get-HawkGhostPortAudit` | `Get-NetTCPConnection -State Listen` → cross-references owning PID against live process table. Returns ports with no matching process. |
| `fwaudit` | `Get-HawkFirewallAudit` | Gets live listeners (`Get-NetTCPConnection`) + enabled inbound allow rules (`Get-NetFirewallRule`). Extracts `LocalPort` via `Get-NetFirewallPortFilter`. Flags ports with no matching rule. |
| `susaudit` | `Get-HawkSuspiciousProcessAudit` | `Get-Process` → filters `Path -match '(AppData|Temp)'`. Returns Name, Id, Path, CPU, RAM. |
| `diskaudit` | `Get-HawkDiskPressureAudit` | `Get-CimInstance Win32_LogicalDisk` (DriveType=3) → SizeGB, FreeGB, Free%. `-IncludeHogs` adds top N largest files under `-HogPath` + temp folder footprint. |
| `taskaudit` | `Get-HawkScheduledTaskRiskAudit` | `Get-ScheduledTask | Where State -ne Disabled` → filters actions referencing `AppData`, `Temp`, `powershell`, `pwsh`, `cmd`. |
| `evntaudit` | `Get-HawkEventStormAudit` | `Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=2,3; StartTime=(30 min ago)}` → groups by EventId, flags groups > threshold (default 5). Marks hive-corruption IDs 6008/9/11/15. |
| `defendermap` | `Get-HawkDefenderAudit` | `Get-MpComputerStatus` + `Get-MpPreference` + `Get-MpThreatDetection`. Returns: EngineMode, RealTimeProtection, BehaviorMonitoring, NetworkInspection, SignatureAge, TamperProtection, Exclusions, Detections. Color-coded. |
| `regaudit` | `Get-HawkRegAudit` | Enumerates `HKLM:\...\Run`, `HKCU:\...\Run`, `HKLM:\...\RunOnce`, `HKCU:\...\RunOnce`, plus WOW64 variants. Resolves each entry's target exe, checks existence, `Get-AuthenticodeSignature`, flags uncommon locations. Risk: Low/Medium/High + notes (safe-mode, deferred-delete, one-shot, shell-chain, missing-binary). `-SkipWow64` skips 32-bit view. |
| `ifeoaudit` | `Get-HawkIfeoAudit` | Scans `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options` + HKCU equivalent for `Debugger` values. Read-only. |
| `regsnap` | `Save-HawkRegistrySnapshot` | `reg.exe export <KeyPath> <Reports>\<Name>-<timestamp>.reg`. Restore hint: `reg import <file>`. |
| `secretredact` | `Protect-HawkSensitiveText` | Regex `$script:HawkSensitiveNamePattern` matches keys containing `secret`, `token`, `password`, `credential`, `connection.?string`, `sas`, `bearer`, `api.?key`, `private.?key`. Replaces `key=value` and JSON `"key":"value"` with `<REDACTED>`. |

---

## 4. 🩺 DIAGNOSTICS

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `sysview` | `Get-HawkSysView` | One-shot ~25 lines: uptime (`Win32_OperatingSystem`), RAM%, disk usage (`Win32_LogicalDisk`), temp cleanup candidates, critical services (Spooler/WinDefend/WSearch/Dhcp/Dnscache/EventLog/llama-server), ping 8.8.8.8, Defender RT+defs age, pending reboot, AI server state. |
| `hawkdoctor` | `Get-HawkDoctor` | Profile parse check, required modules availability, `projectRoot` exists, llama reachable, Terminal-Icons prefs present. |
| `hawkcheck` | `Test-HawkSetup` | Integration test table: modules, engine (pwsh+llama binaries), model file, config, HF_HOME consistency, AI known-answer round-trip ('2+2'), auto-start proof (stops server, verifies `Invoke-HawkAI` restarts it). `-SkipAI` skips AI checks. Returns `{ Passed, Checks }`. |
| `evntmap` | `Get-HawkEventMap` | Last `-MaxEvents` (20) warnings/errors from System/Application logs. `-RegistryHealth` adds hive-corruption scan (event IDs 6008,9,11,15 per KB822705). |
| `resmap` | `Get-HawkResourceMap` | Top `-Top` (10) processes by WorkingSet with RAM MB, CPU sec, Company. |

---

## 5. 🌍 ENVIRONMENT

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `fwmap` | `Get-HawkFirewallMap` | First `-First` (15) enabled inbound allow rules (`Get-NetFirewallRule`). |
| `envmap` | `Get-HawkEnvMap` | Env vars across Process/Machine/User scopes. REG_EXPAND_SZ expanded. Sensitive-named values redacted unless `-IncludeSensitive`. `-Scope All|Process|Machine|User`. |
| `pathaudit` | `Get-HawkPathAudit` | Validates PATH segments exist, flags duplicates/empties. `-IncludeRegistry` audits persisted Machine/User PATH. `-PassThru` returns objects. |
| `portmap` | `Get-HawkPortMap` | `Get-NetTCPConnection` enriched with process name/company. `-State Listen|Established|All`. |
| `nettriage` | `Get-HawkNetworkTriage` | Listeners + owning process + matching firewall rule. `-WanCheck` prepends 1.1.1.1 ping + IPv4 interface summary. |
| `bootmap` | `Get-HawkBootMap` | HKLM/HKCU Run-key startup entries (hive/name/target/source). |

---

## 6. 🦙 LLAMA SERVER CONTROL

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `llamastart` | `Start-HawkLlamaServer` | Launches `llama-server` hidden with configured model/port (context 32768, 8 threads, flash-attn). Logs to `%LOCALAPPDATA%\llama-app\logs`. Returns process. |
| `llamastop` | `Stop-HawkLlamaServer` | Kills `llama.exe` matching `--port`. |
| `aidoctor` | `Get-HawkLlamaStatus` | `Invoke-RestMethod http://127.0.0.1:8081/v1/models` → renders endpoint/status/model/size. `-Start` auto-launches when offline. |
| `llamadoctor` | `Invoke-HawkLlamaDoctor` | Wrapper: `Get-HawkLlamaStatus -Start`. |

---

## 7. 🖥️ SYSTEM MATRIX — HARDWARE

All matrix probes are parameterless, query live sensors, and use no caching.

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `specs` | `Get-HawkSpecs` | Hardware blueprint: CPU name/cores (`Win32_Processor`), vendor/model (`Win32_ComputerSystem`), GPU (`Win32_VideoController`) → `Format-List`. |
| `uptime` | `Get-HawkUptime` | `Win32_OperatingSystem.LastBootUpTime` vs now → boot anchor + continuous run time as `Nd Nh Nm`. |
| `raminfo` | `Get-HawkRamInfo` | `Win32_PhysicalMemory`: per-slot BankLabel, Capacity, Speed, Manufacturer. |
| `battery` | `Get-HawkBattery` | `Win32_Battery`: Design vs FullCharge capacity; health % = FullCharge/Design·100 (N/A when design value missing). Graceful "no battery hardware" message on desktops. |
| `temps` | `Get-HawkThermals` | ACPI thermal zones (`root/wmi MSAcpi_ThermalZoneTemperature`), Kelvin-tenths → °C. Classifies NOMINAL / WARM ≥50 / HOT ≥70 / CRITICAL ≥85. Hints at vendor drivers/admin elevation when no zones are exposed. |
| `fans` | `Get-HawkFans` | `Win32_Fan` → Name, Status, RPM. Explains that fan curves are EC/vendor-controlled when WMI exposes nothing. |
| `displays` | `Get-HawkDisplays` | `Win32_VideoController` → adapter Description + current VideoModeDescription. |
| `hypervisor` | `Get-HawkHypervisor` | `Win32_ComputerSystem` flags: HypervisorPresent + VirtualizationFirmwareEnabled. |
| `power` | `Get-HawkPower` | Parses `powercfg /getactivescheme` output line-by-line. |
| `license` | `Get-HawkLicense` | `Win32_SoftwareLicensingProduct` filtered on `PartialProductKey` → Name + LicenseStatus; graceful fallback if the CIM class is unavailable. |

---

## 8. 🌐 NETWORK INTEL

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `wifi` | `Get-HawkWifi` | Parses `netsh wlan show interfaces` for SSID + Signal → `Format-List`. Ethernet-only link detected on blank SSID. |
| `dnsbench` | `Get-HawkDnsBench` | `Measure-Command { Resolve-DnsName google.com }` → resolver latency in ms (2 decimals). |
| `linkspeed` | `Get-HawkLinkSpeed` | `Get-NetAdapter` where Status=Up → Name, InterfaceDescription, LinkSpeed. |
| `shares` | `Get-HawkShares` | `Get-SmbShare` excluding hidden admin shares (`*$`) → Name, Path, Description. Warns when SMB cmdlets are unavailable. |
| `hostscheck` | `Get-HawkHostsCheck` | Reads `%windir%\System32\drivers\etc\hosts`, surfaces every non-comment line as an active map override. |
| `dnscache` | `Get-HawkDnsCache` | `Get-DnsClientCache` → first 20 entries: Name, EntryStatus, Data. Reads the OS resolver cache live. |

---

## 9. 🔍 SECURITY SCAN

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `shield` | `Get-HawkShield` | `Get-MpComputerStatus` → RealTimeProtection + DefinitionsUpdated (signature freshness). Red-flag message when Defender cmdlets are absent. |
| `admins` | `Get-HawkAdmins` | `Get-LocalGroupMember -Group Administrators` → Name, PrincipalSource, ObjectClass. |
| `apps` | `Get-HawkApps` | HKLM machine-wide uninstall registry (`...\CurrentVersion\Uninstall\*`) with `DisplayName` → first 30 apps: DisplayName, DisplayVersion. |
| `patchhistory` | `Get-HawkPatchHistory` | `Get-HotFix` sorted by InstalledOn desc → latest 15 KB updates. |
| `driveraudit` | `Get-HawkDriverAudit` | `Win32_PnPSignedDriver` where DeviceStatus ≠ OK → DeviceName, DeviceStatus, Manufacturer. |
| `certs` | `Get-HawkCerts` | `Cert:\LocalMachine\My` → Subject + NotAfter expiry for personal certificates. |

---

## 10. 💾 STORAGE FORENSICS

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `clipcheck` | `Get-HawkClipCheck` | `Get-Clipboard -Raw` → buffer length + first-40-char preview; "buffer is clear" when empty. |
| `recent` | `Get-HawkRecent` | Recurses Documents + Downloads for files written in the last 24h → Name, LastWriteTime. |
| `drivehealth` | `Get-HawkDriveHealth` | Direct CIM query `MSFT_PhysicalDisk` (Storage namespace) → DeviceId, FriendlyName, OperationalStatus, HealthStatus (SMART-class health). |
| `dumps` | `Get-HawkDumps` | Lists `%windir%\Minidump` contents (Name, Length, LastWriteTime) or reports none exist. |
| `badfiles` | `Get-HawkBadFiles` | Zero-byte files at the top level of Documents — possible corruption artifacts. |
| `links` | `Get-HawkLinks` | Reparse points (symlinks/junctions) at the profile root incl. hidden items → Name, Target. |
| `locked` | `Get-HawkLocked` | Recursive Documents walk with `-ErrorVariable` capturing access-denied failures → restricted entry list. |
| `sparse` | `Get-HawkSparse` | Files carrying the NTFS SparseFile attribute, top level of Documents. |
| `compress` | `Get-HawkCompress` | Files carrying the NTFS Compressed attribute, top level of Documents. |

---

## 11. 🧰 UTILITIES

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `locate` | `Get-HawkAppLocation` | `Get-Command <name>` → Name, CommandType, Source — traces where an app resolves from. Usage: `locate git`. |
| `open` | `Invoke-ExplorerHere` | `Invoke-Item .` opens File Explorer at the current directory. |

### Short Verbs & Hub

| Alias | Canonical | Under the Hood |
|:---|:---|:---|
| `ask` | `Invoke-HawkShortAsk` | Sends a question or piped data to the local model via `Invoke-HawkAI` (redaction always on). Pipeline branch auto-instructs "Analyze this operational data and answer concisely." `-Instruction` overrides. |
| `fix` | `Invoke-HawkShortFix` | Sends `$Error[0]` + position message (+ optional `-Context`) through `Invoke-HawkAI -RedactSensitive` with a concrete-fix instruction. |
| `stat` | `Invoke-HawkShortStat` | One-page operational pulse — delegates to `Get-HawkSysView`: uptime, RAM%, disk, temp footprint, critical services, ping 8.8.8.8, Defender state, AI server. |
| `mem` | `Invoke-HawkShortMem` | Memory router: text → remember, query → recall, neither → memory map (see §15). |
| `hub` | `Invoke-HawkCompanion` | One-word hub: `hub brief\|fix\|stat\|ask\|mem [args]`, default `brief`. The `mem` route accepts `-Query/-Tag/-Pinned`. |

---

## 12. 🎯 DISPATCH VERBS


Single-entry verbs for grouped queries:

| Verb | Alias | Types |
|:---|:---|:---|
| `Get-HawkSystem` | `sysdiag` | `health`, `spec`, `uptime`, `ram`, `battery`, `display`, `disk`, `res`, `port`, `temp`, `fans`, `hyperv`, `power`, `license` |
| `Get-HawkAudit` | `auditdiag` | `fw`, `boot`, `schedtask`, `ghost`, `sus`, `storm`, `admin`, `shield`, `temp`, `clip`, `defender`, `reg`, `ifeo`, `pathaudit` |
| `Get-HawkNetwork` | `netview` | `ping`, `wifi`, `dns`, `linkspeed`, `shares`, `hosts`, `dnscache`, `established`, `nettriage`, `portmap` |
| `Get-HawkEnv` | `envdiag` | `envmap`, `path`, `app` |

```powershell
sysdiag -Type disk      # → Get-HawkDiskPressureAudit
auditdiag -Type fw      # → Get-HawkFirewallAudit
netview -Type ping      # → Get-HawkNetCheck
envdiag -Type path      # → Get-HawkPathAudit
```

---

## 13. ⚡ CACHING BEHAVIOR

The only session cache today is the git prompt segment (`$global:HawkPromptGitCache`, 2-second TTL per working directory) so the prompt stays snappy inside large repositories. Audit and map commands query WMI/CIM live on every invocation — no result caching, no `-Force` bypass needed.

---

## 14. 📋 OPERATIONAL WORKFLOWS


Each workflow aggregates existing functions, applies scoring (start 100, deduct per finding, floor 0), returns `[PSCustomObject]@{ Score; Recommendations; Health }`.

| Workflow | Alias | Sources | Scoring |
|:---|:---|:---|:---|
| `Invoke-HawkDaily` | `hawkdaily` | health, uptime, disk, network, dns, events, temp, power | 8 sub-functions |
| `Invoke-HawkSystemReview` | `sysreview` | spec, health, uptime, ram, disk, res, port, temp, hyperv, power, license | 11 sub-functions |
| `Invoke-HawkSecurityAudit` | `secaudit` | fw, boot, schedtask, ghost, sus, storm, admin, shield | 8 sub-functions |
| `Invoke-HawkNetworkDiagnostics` | `netdiag` | ping, wifi, dns, dnscache, linkspeed, shares, hosts, established, nettriage | 9 sub-functions |
| `Invoke-HawkThreatHunt` | `threathunt` | sus, ghost, storm, badfiles, locked, sparse, compress, fw | THREATS/WARNINGS/INFO buckets |
| `Invoke-HawkChangeAudit` | — | recent, patches, drivers, dumps, boot, certs | 6 sub-functions |
| `Invoke-HawkComplianceCheck` | — | admin, shield, fw gaps, non-MS tasks, boot, patches, license, hyperv, ports | 9 CIS-inspired checks, pass-rate % |

**Thresholds:** ≥80 🟢 | 50–79 🟡 | <50 🔴

```powershell
hawkdaily | ForEach-Object { $_.Score }
secaudit | ForEach-Object { $_.Recommendations }
```

---

## 15. 🧠 SEMANTIC RECALL (MEMORY)


Persistent JSONL at `~\Documents\PowerShell\Memory\hawk-memory.jsonl`.

| Alias | Canonical | Description |
|:---|:---|:---|
| `remember` | `Add-HawkMemory` | Appends entry: Id (`mem_{yyyyMMdd_HHmmss}_{guid[0:6]}`), Type (note/preference/runbook/session/web/sysops), Tags, Text (auto-redacted), Source, Created (ISO 8601), Confidence (low/medium/high/user), Pinned. Supports `-WhatIf`. |
| `recall` | `Search-HawkMemory` | Reads JSONL, filters by `-Query` (term match), `-Pinned`, `-First`. Scores by term hits (+2 if pinned), sorts desc. |
| `memmap` | `Get-HawkMemoryMap` | Lists all with `-Tag`, `-Pinned`, `-First` filters. Sorts by Created desc. |
| `readmem` | `Read-HawkMemory` | Returns all entries as `[HawkMemoryEntry]` objects. |

**Auto-redaction:** `Text` field passed through `Protect-HawkSensitiveText` before write.

```powershell
remember "Prefer Q4_K_M for 1.7B models" -Tag preference -Pinned
recall "quantization" -First 5
memmap -Pinned
```

---

## 16. 🧭 GUIDED ONBOARDING


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

Config persisted to `~\Documents\PowerShell\hawk-settings.json`.

---

## 17. 🔍 QUALITY & INJECTION SCORING


| Command | Description |
|:---|:---|
| `Get-HawkSourceQualityScore` | Heuristic 0–100: base 50, +20 if content >200 chars, +15 if >800 chars, +15 if `.gov`/`.edu`/`.org`. Cap 100. |
| `Test-HawkPromptInjection` | Regex detection: `ignore (previous|above|all) instructions`, `you are now`, `system prompt`, `DAN.*mode`. Returns `$true`/`$false`. |

**Integrated into `ggl -AI`:** Scores each scraped page, filters injection positives, only synthesizes from clean pages ≥50.

---

## 18. ⚙️ CONFIGURATION

```powershell
# Change project root at init
Initialize-HawkProfile -ProjectRoot 'D:\Work' -ShowDashboard

# Skip prereq module import
Initialize-HawkProfile -SkipModules

# Suppress dashboard
$env:HAWK_NO_DASH = '1'
```

| Variable | Default | Purpose |
|:---|:---|:---|
| `$env:HAWK_NO_DASH` | unset | Set `1` to suppress dashboard |
| `$env:CI` | unset | Auto-suppresses dashboard |
| `$global:HawkProjectRoot` | derived checkout/profile root | Project root for `proj` |
| `~\Documents\PowerShell\hawk.config.json` | optional | Persists projectRoot, hfHome, llamaPort, modelPath |
| `~\Documents\PowerShell\hawk-settings.json` | optional | Persists onboarding: project root, memory root, llama endpoint, selected model, modelfile path |
| `$script:HawkSensitiveNamePattern` | regex | Pattern for `secretredact` |

---

## 19. 📊 PIPELINE TIPS

```powershell
# Chain commands — all Get-Hawk* output objects work with Where-Object, Format-Table, Export-Csv
portmap | Format-Table -AutoSize
diskaudit | Where-Object { $_.FreePercent -lt 10 }
bootmap | Export-Csv startup.csv

# Pipe to AI
resmap | ai "Which process is using the most RAM?"
fwaudit | ai "Any gaps in firewall rules?"

# Run a full daily ops scan
hawkdaily

# Run a security audit and check the score
secaudit | ForEach-Object { $_.Score }

# Export compliance check results
Invoke-HawkComplianceCheck | Export-Csv compliance-report.csv

# Redact before sending to AI
envmap -IncludeSensitive | secretredact | ai "Summarize the environment"

# Search the web + synthesize
ggl "windows firewall hardening" -AI

# One-word hub shortcuts
hub stat
hub ask "best way to trim TEMP folders?"
```

---

## 20. 📈 PERFORMANCE

| Operation | Time |
|:---|:---|
| Module import (bare) | ~150ms |
| Init with prerequisites check | ~400ms |
| Full profile load | ~2.5s |
| Dashboard render | ~50ms |
| First audit run | ~500ms–2s (depends on WMI queries) |
| AI query (llama.cpp, first) | ~5–20s (model load) |
| AI query (llama.cpp, cached) | ~500ms–5s |
| Daily ops scan (cached) | ~1–3s |
| Compliance check (cached) | ~2–5s |

The 2.5s profile load is mainly from `Import-HawkPrerequisites` checking PSGallery. Second runs are faster due to caching. AI first-query latency depends on whether the selected llama.cpp model is already loaded.

---

## 21. 📋 COMPLETE ALIAS INDEX

Every daily-driver alias registered by the profile, generated from the live alias map.

| Alias | Runs |
|---|---|
| `admins` | `Get-HawkAdmins` |
| `ai` | `Invoke-HawkAI` |
| `aidoctor` | `Get-HawkLlamaStatus` |
| `apps` | `Get-HawkApps` |
| `ask` | `Invoke-HawkShortAsk` |
| `auditdiag` | `Get-HawkAudit` |
| `badfiles` | `Get-HawkBadFiles` |
| `battery` | `Get-HawkBattery` |
| `bootmap` | `Get-HawkBootMap` |
| `certs` | `Get-HawkCerts` |
| `clipcheck` | `Get-HawkClipCheck` |
| `compress` | `Get-HawkCompress` |
| `dash` | `Show-HawkDashboard` |
| `defendermap` | `Get-HawkDefenderAudit` |
| `diskaudit` | `Get-HawkDiskPressureAudit` |
| `displays` | `Get-HawkDisplays` |
| `dnsbench` | `Get-HawkDnsBench` |
| `dnscache` | `Get-HawkDnsCache` |
| `drivehealth` | `Get-HawkDriveHealth` |
| `driveraudit` | `Get-HawkDriverAudit` |
| `dumps` | `Get-HawkDumps` |
| `envdiag` | `Get-HawkEnv` |
| `envmap` | `Get-HawkEnvMap` |
| `evntaudit` | `Get-HawkEventStormAudit` |
| `evntmap` | `Get-HawkEventMap` |
| `fans` | `Get-HawkFans` |
| `fix` | `Invoke-HawkShortFix` |
| `fwaudit` | `Get-HawkFirewallAudit` |
| `fwmap` | `Get-HawkFirewallMap` |
| `ggl` | `Invoke-HawkSearch` |
| `ghostaudit` | `Get-HawkGhostPortAudit` |
| `hawkchat` | `Invoke-HawkChat` |
| `hawkcheck` | `Test-HawkSetup` |
| `hawkdaily` | `Invoke-HawkDaily` |
| `hawkdoctor` | `Get-HawkDoctor` |
| `hawkhelp` | `Invoke-HawkHelp` |
| `hawkman` | `Show-HawkManual` |
| `hawkmodel` | `Get-HawkModel` |
| `hawkreport` | `New-HawkReport` |
| `hawkwatch` | `Watch-HawkDashboard` |
| `hostscheck` | `Get-HawkHostsCheck` |
| `hub` | `Invoke-HawkCompanion` |
| `hypervisor` | `Get-HawkHypervisor` |
| `ifeoaudit` | `Get-HawkIfeoAudit` |
| `license` | `Get-HawkLicense` |
| `links` | `Get-HawkLinks` |
| `linkspeed` | `Get-HawkLinkSpeed` |
| `llamadoctor` | `Invoke-HawkLlamaDoctor` |
| `llamastart` | `Start-HawkLlamaServer` |
| `llamastop` | `Stop-HawkLlamaServer` |
| `locate` | `Get-HawkAppLocation` |
| `locked` | `Get-HawkLocked` |
| `mem` | `Invoke-HawkShortMem` |
| `memmap` | `Get-HawkMemoryMap` |
| `netdiag` | `Invoke-HawkNetworkDiagnostics` |
| `nettriage` | `Get-HawkNetworkTriage` |
| `netview` | `Get-HawkNetwork` |
| `onboard` | `Invoke-HawkOnboard` |
| `open` | `Invoke-ExplorerHere` |
| `patchhistory` | `Get-HawkPatchHistory` |
| `pathaudit` | `Get-HawkPathAudit` |
| `portmap` | `Get-HawkPortMap` |
| `power` | `Get-HawkPower` |
| `proj` | `Invoke-HawkProject` |
| `projaudit` | `Get-HawkProjectAudit` |
| `raminfo` | `Get-HawkRamInfo` |
| `readmem` | `Read-HawkMemory` |
| `recall` | `Search-HawkMemory` |
| `recent` | `Get-HawkRecent` |
| `regaudit` | `Get-HawkRegAudit` |
| `regsnap` | `Save-HawkRegistrySnapshot` |
| `reload` | `Update-HawkProfile` |
| `remember` | `Add-HawkMemory` |
| `resmap` | `Get-HawkResourceMap` |
| `secaudit` | `Invoke-HawkSecurityAudit` |
| `secretredact` | `Protect-HawkSensitiveText` |
| `shares` | `Get-HawkShares` |
| `shield` | `Get-HawkShield` |
| `sparse` | `Get-HawkSparse` |
| `specs` | `Get-HawkSpecs` |
| `stat` | `Invoke-HawkShortStat` |
| `susaudit` | `Get-HawkSuspiciousProcessAudit` |
| `sysdiag` | `Get-HawkSystem` |
| `sysreview` | `Invoke-HawkSystemReview` |
| `sysview` | `Get-HawkSysView` |
| `taskaudit` | `Get-HawkScheduledTaskRiskAudit` |
| `temps` | `Get-HawkThermals` |
| `threathunt` | `Invoke-HawkThreatHunt` |
| `uptime` | `Get-HawkUptime` |
| `wifi` | `Get-HawkWifi` |


**Developed for Professionals by [Shahriar Haque Abir](https://github.com/shahriarhaqueabir)**

