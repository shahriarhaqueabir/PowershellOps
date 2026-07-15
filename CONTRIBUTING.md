# Contributing to PowershellOps

Thanks for your interest! This project is a PowerShell 7 module and profile — contributions that add security audits, system diagnostics, or AI integrations are especially welcome.

## Getting Started

1. Fork the repository.
2. Clone your fork: `git clone https://github.com/your-username/PowershellOps.git`
3. Create a feature branch: `git checkout -b feature/my-thing`

## Code Conventions

| Rule | Reason |
|---|---|
| **Prefix functions with `Hawk`** | `Get-HawkSomething` — predictable tab-completion, no collisions |
| **Add an alias in `Set-HawkAliases`** | Users should never type the full function name |
| **Add a dashboard entry in `Show-HawkDashboard`** | New commands must appear in the startup UI |
| **Use `[CmdletBinding()]`** | Enables `-Verbose`, `-ErrorAction`, and `-WhatIf` |
| **Output `[PSCustomObject]`** | Pipes cleanly into Format-Table, ConvertTo-Json, and the report engine |
| **`-ErrorAction SilentlyContinue` on reads, `Stop` on writes** | Audit functions must not crash the session |
| **Dispose HttpClient/streams in `finally` blocks** | Avoid memory pressure over long sessions |

## Testing

Tests are in `Modules/HawkwardHybrid/Tests/` and use Pester.

```powershell
./Invoke-HawkBuild.ps1
```

This runs PSScriptAnalyzer (Error/Warning severity) and all Pester tests.

## Pull Request Process

1. Run `Invoke-HawkBuild.ps1` and confirm it passes.
2. Update `README.md` and `MANUAL.md` if you added or changed a command.
3. Open a PR against `main` with a clear title and description.
4. A maintainer will review within a few days.

## Questions?

Open a [GitHub Issue](https://github.com/shahriarhaqueabir/PowershellOps/issues).
