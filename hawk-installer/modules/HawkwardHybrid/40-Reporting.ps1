function Get-HawkProjectAudit {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $global:HawkProjectRoot,
        [int]$Depth = 1,
        [switch]$PassThru
    )

    if (-not (Test-Path $ProjectRoot)) {
        Write-Host "`n  ⛨ PROJECT AUDIT" -ForegroundColor Blue
        Write-Host "  [!!] Project root not found: '$ProjectRoot'" -ForegroundColor Red
        Write-Host '       Fix hawkconfig projectRoot or pass -ProjectRoot <path>.' -ForegroundColor DarkGray
        return
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    $dirs = Get-ChildItem -Path $ProjectRoot -Directory -Depth $Depth -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        if (-not (Test-Path (Join-Path $dir.FullName '.git'))) { continue }

        $branch = & git -C $dir.FullName branch --show-current 2>$null
        if (-not $branch) { $branch = & git -C $dir.FullName rev-parse --short HEAD 2>$null }
        $dirty = @(& git -C $dir.FullName status --short 2>$null)
        $lastCommit = & git -C $dir.FullName log -1 --format='%cr | %s' 2>$null

        $rows.Add([PSCustomObject]@{
            Project    = $dir.Name
            Path       = $dir.FullName
            Branch     = $branch
            DirtyFiles = $dirty.Count
            LastCommit = $lastCommit
        })
    }

    Write-Host "`n  ⛨ PROJECT AUDIT" -ForegroundColor Blue
    foreach ($r in $rows) {
        $dirtyColor = if ($r.DirtyFiles -eq 0) { 'Green' } elseif ($r.DirtyFiles -gt 10) { 'Red' } else { 'Yellow' }
        Write-Host ('   ◈ ') -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-24}" -f $r.Project) -NoNewline -ForegroundColor White
        Write-Host ("{0,-16}" -f [string]$r.Branch) -NoNewline -ForegroundColor Cyan
        Write-Host ("{0,-6}" -f "$($r.DirtyFiles) dirty") -NoNewline -ForegroundColor $dirtyColor
        $commit = [string]$r.LastCommit
        if ($commit.Length -gt 48) { $commit = $commit.Substring(0, 45) + '...' }
        Write-Host " $commit" -ForegroundColor DarkGray
    }
    Write-Host "  [OK] repositories: $($rows.Count)" -ForegroundColor Green

    if ($PassThru) { $rows }
}

function Format-HawkMarkdownCell {
    <#
    .SYNOPSIS
    Formats a text value as a single-line markdown table cell.
    .DESCRIPTION
    Strips newlines and excess whitespace, escapes pipe characters, and
    truncates to MaxWidth if specified. Used internally by ConvertTo-HawkMarkdownTable.
    .PARAMETER Text
    The cell content to format.
    .PARAMETER MaxWidth
    Maximum character width. 0 means no truncation.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Text,
        [int]$MaxWidth = 0
    )

    if ($null -eq $Text) { $Text = '' }

    $clean = ($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' '
    $clean = $clean.Trim().Replace('|', '\|')

    if ($MaxWidth -gt 0 -and $clean.Length -gt $MaxWidth) {
        if ($MaxWidth -eq 1) { return $clean.Substring(0, 1) }
        return $clean.Substring(0, $MaxWidth - 1) + '…'
    }

    return $clean
}

<#
.SYNOPSIS
Converts an array of objects into a formatted Markdown table.
.DESCRIPTION
Takes PowerShell objects and renders them as a Markdown table with headers and alignment.
Useful for generating reports from diagnostic output.
.PARAMETER InputObject
Array of objects to convert.
.PARAMETER Section
Optional section header to prepend.
#>
function ConvertTo-HawkMarkdownTable {
    [CmdletBinding()]
    param(
        [object[]]$InputObject,
        [string]$Section = ''
    )

    $rows = @($InputObject | Where-Object { $null -ne $_ })
    if (-not $rows -or $rows.Count -eq 0) {
        return '_No data._'
    }

    $props = @($rows[0].PSObject.Properties.Name)
    $maxWidths = @{
        Endpoint    = 32
        Model       = 64
        Modified    = 20
        ProcessName = 28
        Company     = 28
        Name        = 42
        Target      = 76
        Source      = 48
        TaskPath    = 34
        TaskName    = 52
        Path        = 72
        Args        = 72
        Status      = 56
        MatchedRule = 32
        LastCommit  = 56
    }

    if ($Section -eq 'Startup') {
        $maxWidths.Name = 38
        $maxWidths.Target = 72
        $maxWidths.Source = 44
    }
    elseif ($Section -eq 'ScheduledTaskRisks') {
        $maxWidths.TaskPath = 34
        $maxWidths.TaskName = 48
        $maxWidths.Path = 64
        $maxWidths.Args = 64
    }

    $formattedRows = foreach ($row in $rows) {
        $formatted = [ordered]@{}
        foreach ($prop in $props) {
            $value = $row.PSObject.Properties[$prop].Value
            $maxWidth = if ($maxWidths.ContainsKey($prop)) { [int]$maxWidths[$prop] } else { 0 }
            $formatted[$prop] = Format-HawkMarkdownCell -Text ([string]$value) -MaxWidth $maxWidth
        }
        [PSCustomObject]$formatted
    }

    $widths = [ordered]@{}
    foreach ($prop in $props) {
        $max = $prop.Length
        foreach ($row in $formattedRows) {
            $length = ([string]$row.PSObject.Properties[$prop].Value).Length
            if ($length -gt $max) { $max = $length }
        }
        $widths[$prop] = [Math]::Max(3, $max)
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $headers = foreach ($prop in $props) { $prop.PadRight($widths[$prop]) }
    $separators = foreach ($prop in $props) { '-' * $widths[$prop] }

    $lines.Add('| ' + ($headers -join ' | ') + ' |')
    $lines.Add('| ' + ($separators -join ' | ') + ' |')

    foreach ($row in $formattedRows) {
        $cells = foreach ($prop in $props) {
            ([string]$row.PSObject.Properties[$prop].Value).PadRight($widths[$prop])
        }
        $lines.Add('| ' + ($cells -join ' | ') + ' |')
    }

    return ($lines -join [Environment]::NewLine)
}

<#
.SYNOPSIS
Converts a Hawk report object into a Markdown string.
.DESCRIPTION
Takes a structured report (with Title, Timestamp, Sections) and renders it as a complete Markdown document.
.PARAMETER Report
The report object to convert.
#>
function ConvertTo-HawkReportMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Report
    )

    $sectionIcons = @{
        AI                 = '◉'
        Disk               = '▰'
        Resources          = '▤'
        Ports              = '◦'
        FirewallGaps       = '▣'
        Startup            = '⌂'
        ScheduledTaskRisks = '⌁'
        EventStorms        = '↯'
    }

    $aiModels = @($Report.AI | Where-Object Status -eq 'Reachable')
    $diskCount = @($Report.Disk).Count
    $lowestDisk = @($Report.Disk | Sort-Object FreePercent | Select-Object -First 1)
    $portCount = @($Report.Ports).Count
    $firewallGapCount = @($Report.FirewallGaps).Count
    $startupCount = @($Report.Startup).Count
    $taskRiskCount = @($Report.ScheduledTaskRisks).Count
    $eventStormCount = @($Report.EventStorms).Count

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# PowershellOps Report')
    $lines.Add('')
    $lines.Add("Generated: $($Report.Generated)")
    $lines.Add('')
    $lines.Add('## ▣ Summary')
    $lines.Add('')
    $lines.Add('| Signal | Value |')
    $lines.Add('| --- | --- |')
    $lines.Add("| ◉ AI | $($aiModels.Count) reachable model(s) |")
    if ($lowestDisk) {
        $lines.Add("| ▰ Disk | $diskCount drive(s), lowest free: $($lowestDisk.DeviceID) $($lowestDisk.FreePercent)% |")
    }
    else {
        $lines.Add('| ▰ Disk | No disk data |')
    }
    $lines.Add("| ◦ Ports | $portCount listener row(s) |")
    $lines.Add("| ▣ Firewall gaps | $firewallGapCount item(s) |")
    $lines.Add("| ⌂ Startup | $startupCount entry/entries |")
    $lines.Add("| ⌁ Scheduled risks | $taskRiskCount item(s) |")
    $lines.Add("| ↯ Event storms | $eventStormCount item(s) |")

    foreach ($section in @('AI', 'Disk', 'Resources', 'Ports', 'FirewallGaps', 'Startup', 'ScheduledTaskRisks', 'EventStorms')) {
        $lines.Add('')
        $lines.Add("## $($sectionIcons[$section]) $section")
        $lines.Add('')
        $lines.Add((ConvertTo-HawkMarkdownTable -InputObject $Report[$section] -Section $section))
    }

    return ($lines -join [Environment]::NewLine)
}

<#
.SYNOPSIS
Generates a timestamped report file path.
.DESCRIPTION
Creates a unique file path in the Hawk reports directory with a timestamp prefix.
Returns the path without creating the file.
.PARAMETER Extension
File extension: 'md' or 'json'. Default: md.
#>
function New-HawkReportPath {
    [CmdletBinding()]
    param(
        [ValidateSet('md', 'json')]
        [string]$Extension = 'md'
    )

    if (-not (Test-Path $script:HawkReportRoot)) {
        $null = New-Item -Path $script:HawkReportRoot -ItemType Directory -Force
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Join-Path $script:HawkReportRoot "hawkreport-$stamp.$Extension"
}

function Format-HawkReportCell {
    <#
    .SYNOPSIS
    Formats a text value as a fixed-width table cell for console output.
    .DESCRIPTION
    Pads or truncates text to exactly Width characters. Strips newlines
    and excess whitespace. Used internally by Write-HawkReportTable.
    .PARAMETER Text
    The cell content to format.
    .PARAMETER Width
    Exact character width for the cell.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Text,
        [int]$Width
    )

    if ($Width -le 0) { return '' }
    if ($null -eq $Text) { $Text = '' }

    $clean = ($Text -replace "(`r`n|`n|`r)", ' ') -replace '\s+', ' '
    $clean = $clean.Trim()
    if ($clean.Length -gt $Width) {
        if ($Width -eq 1) { return $clean.Substring(0, 1) }
        return $clean.Substring(0, $Width - 1) + '…'
    }

    return $clean.PadRight($Width)
}

<#
.SYNOPSIS
Writes a formatted table to console from column definitions and data.
.DESCRIPTION
Renders a table with aligned columns, row separators, and optional footers.
Used internally by report functions for console output.
.PARAMETER Title
Table title/header text.
.PARAMETER Columns
Array of hashtable definitions for each column.
.PARAMETER InputObject
Array of row data objects.
.PARAMETER Icon
Bullet character for rows. Default: bullet.
.PARAMETER Color
Header/title color. Default: Cyan.
.PARAMETER RowColor
Row text color. Default: White.
.PARAMETER MaxRows
Maximum rows to display. 0 = unlimited.
#>
function Write-HawkReportTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][hashtable[]]$Columns,
        [object[]]$InputObject = @(),
        [string]$Icon = '•',
        [ConsoleColor]$Color = 'Cyan',
        [ConsoleColor]$RowColor = 'White',
        [int]$MaxRows = 0
    )

    $rows = @($InputObject | Where-Object { $null -ne $_ })
    $visibleRows = if ($MaxRows -gt 0) { @($rows | Select-Object -First $MaxRows) } else { $rows }
    $tableWidth = (($Columns | ForEach-Object { [int]$_.Width } | Measure-Object -Sum).Sum + (($Columns.Count - 1) * 2))

    Write-Host ''
    Write-Host "  $Icon $Title" -ForegroundColor $Color
    Write-Host "  $('─' * [Math]::Max(1, $tableWidth))" -ForegroundColor DarkGray

    if (-not $rows -or $rows.Count -eq 0) {
        Write-Host '  ✓ No data.' -ForegroundColor Green
        return
    }

    $header = foreach ($column in $Columns) {
        $label = if ($column.Label) { [string]$column.Label } else { [string]$column.Name }
        Format-HawkReportCell -Text $label -Width ([int]$column.Width)
    }
    Write-Host ('  ' + ($header -join '  ')) -ForegroundColor DarkGray

    foreach ($row in $visibleRows) {
        $cells = foreach ($column in $Columns) {
            $value = if ($column.Expression) {
                & $column.Expression $row
            }
            else {
                $prop = $row.PSObject.Properties[[string]$column.Name]
                if ($prop) { $prop.Value } else { '' }
            }

            Format-HawkReportCell -Text ([string]$value) -Width ([int]$column.Width)
        }

        Write-Host ('  ' + ($cells -join '  ')) -ForegroundColor $RowColor
    }

    if ($MaxRows -gt 0 -and $rows.Count -gt $MaxRows) {
        Write-Host "  … $($rows.Count - $MaxRows) more row(s) in the saved Markdown report." -ForegroundColor DarkGray
    }
}

<#
.SYNOPSIS
Outputs a complete report to the console with optional file save.
.DESCRIPTION
Renders a report object to the console with header, sections, and summary.
Optionally saves the Markdown version to a file.
.PARAMETER Report
The report object to display.
.PARAMETER SavedPath
If provided, prints the path where the report was saved.
#>
function Write-HawkReportConsole {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Report,
        [string]$SavedPath
    )

    $aiModels = @($Report.AI | Where-Object Status -eq 'Reachable')
    $lowestDisk = @($Report.Disk | Sort-Object FreePercent | Select-Object -First 1)
    $summary = @(
        [PSCustomObject]@{ Signal = 'AI'; Value = "$($aiModels.Count) reachable model(s)" }
        [PSCustomObject]@{ Signal = 'Disk'; Value = if ($lowestDisk) { "$(@($Report.Disk).Count) drive(s), lowest free: $($lowestDisk.DeviceID) $($lowestDisk.FreePercent)%" } else { 'No disk data' } }
        [PSCustomObject]@{ Signal = 'Ports'; Value = "$(@($Report.Ports).Count) listener row(s)" }
        [PSCustomObject]@{ Signal = 'Firewall gaps'; Value = "$(@($Report.FirewallGaps).Count) item(s)" }
        [PSCustomObject]@{ Signal = 'Startup'; Value = "$(@($Report.Startup).Count) entry/entries" }
        [PSCustomObject]@{ Signal = 'Task risks'; Value = "$(@($Report.ScheduledTaskRisks).Count) item(s)" }
        [PSCustomObject]@{ Signal = 'Event storms'; Value = "$(@($Report.EventStorms).Count) item(s)" }
    )

    Write-Host ''
    Write-Host '  ▣ POWERSHELLOPS REPORT' -ForegroundColor Cyan
    Write-Host "  Generated  $($Report.Generated)" -ForegroundColor DarkGray
    if ($SavedPath) {
        Write-Host "  Saved      $SavedPath" -ForegroundColor DarkGray
    }

    Write-HawkReportTable -Title 'Summary' -Icon '▣' -Color Cyan -InputObject $summary -Columns @(
        @{ Name = 'Signal'; Width = 16 }
        @{ Name = 'Value'; Width = 64 }
    )

    Write-HawkReportTable -Title 'AI Models' -Icon '◉' -Color Magenta -InputObject $Report.AI -Columns @(
        @{ Name = 'Status'; Width = 10 }
        @{ Name = 'Model'; Width = 46 }
        @{ Name = 'SizeGB'; Label = 'GB'; Width = 8 }
        @{ Name = 'Modified'; Width = 20 }
    )

    Write-HawkReportTable -Title 'Disk' -Icon '▰' -Color Yellow -InputObject $Report.Disk -Columns @(
        @{ Name = 'DeviceID'; Label = 'Drive'; Width = 8 }
        @{ Name = 'SizeGB'; Label = 'Size GB'; Width = 9 }
        @{ Name = 'FreeGB'; Label = 'Free GB'; Width = 9 }
        @{ Name = 'FreePercent'; Label = 'Free %'; Width = 8 }
        @{ Name = 'Source'; Width = 8 }
    )

    Write-HawkReportTable -Title 'Resources' -Icon '▤' -Color Red -InputObject $Report.Resources -MaxRows 12 -Columns @(
        @{ Name = 'ProcessName'; Label = 'Process'; Width = 24 }
        @{ Name = 'Id'; Label = 'PID'; Width = 8 }
        @{ Name = 'RAMMB'; Label = 'RAM MB'; Width = 8 }
        @{ Name = 'CPUSec'; Label = 'CPU s'; Width = 8 }
        @{ Name = 'Company'; Width = 26 }
    )

    Write-HawkReportTable -Title 'Ports' -Icon '◦' -Color Cyan -InputObject $Report.Ports -MaxRows 30 -Columns @(
        @{ Name = 'Port'; Width = 7 }
        @{ Name = 'PID'; Width = 8 }
        @{ Name = 'Process'; Width = 30 }
        @{ Name = 'Company'; Width = 26 }
    )

    Write-HawkReportTable -Title 'Firewall Gaps' -Icon '▣' -Color DarkYellow -InputObject $Report.FirewallGaps -Columns @(
        @{ Name = 'Port'; Width = 7 }
        @{ Name = 'PID'; Width = 8 }
        @{ Name = 'Process'; Width = 24 }
        @{ Name = 'Status'; Width = 44 }
    )

    Write-HawkReportTable -Title 'Startup' -Icon '⌂' -Color Green -InputObject $Report.Startup -MaxRows 20 -Columns @(
        @{ Name = 'Hive'; Width = 6 }
        @{ Name = 'Name'; Width = 30 }
        @{ Name = 'Target'; Width = 64 }
    )

    Write-HawkReportTable -Title 'Scheduled Task Risks' -Icon '⌁' -Color DarkYellow -InputObject $Report.ScheduledTaskRisks -MaxRows 16 -Columns @(
        @{ Name = 'TaskPath'; Width = 28 }
        @{ Name = 'TaskName'; Width = 36 }
        @{ Name = 'Path'; Width = 46 }
    )

    Write-HawkReportTable -Title 'Event Storms' -Icon '↯' -Color Red -InputObject $Report.EventStorms -Columns @(
        @{ Name = 'Count'; Width = 8 }
        @{ Name = 'Name'; Label = 'Event ID'; Width = 12 }
        @{ Name = 'Source'; Width = 44 }
    )
}

<#
.SYNOPSIS
Creates a new Hawk report with auto-generated timestamp and title.
.DESCRIPTION
Initializes a report object ready for section accumulation.
Call Add-HawkReportSection to populate, then Write-HawkReportConsole or ConvertTo-HawkReportMarkdown to output.
.PARAMETER Format
Output format: Console, Markdown, or Json. Default: Console.
.PARAMETER Path
Optional file path to save the report.
#>
function New-HawkReport {
    [CmdletBinding()]
    param(
        [ValidateSet('Console', 'Markdown', 'Json')]
        [string]$Format = 'Console',
        [string]$Path
    )

    $previous = $script:HawkSuppressHeaders
    $script:HawkSuppressHeaders = $true
    try {
        $report = [ordered]@{
            Generated          = Get-Date
            AI                 = @(Get-HawkLlamaStatusCore)
            Disk               = @(Get-HawkDiskPressureAudit)
            Resources          = @(Get-HawkResourceMap)
            Ports              = @(Get-HawkPortMap)
            FirewallGaps       = @(Get-HawkFirewallAudit)
            Startup            = @(Get-HawkBootMap)
            ScheduledTaskRisks = @(Get-HawkScheduledTaskRiskAudit)
            EventStorms        = @(Get-HawkEventStormAudit)
        }
    }
    finally {
        $script:HawkSuppressHeaders = $previous
    }

    $markdownOutput = ConvertTo-HawkReportMarkdown -Report $report

    if ($Format -eq 'Console') {
        $markdownPath = if ($Path) { $Path } else { New-HawkReportPath -Extension md }
        $parentPath = Split-Path $markdownPath -Parent
        if ($parentPath -and -not (Test-Path $parentPath)) {
            $null = New-Item -Path $parentPath -ItemType Directory -Force
        }

        Set-Content -Path $markdownPath -Value $markdownOutput -Encoding UTF8
        Write-HawkReportConsole -Report $report -SavedPath $markdownPath
        return
    }

    $output = if ($Format -eq 'Json') {
        $report | ConvertTo-Json -Depth 8
    }
    else {
        $markdownOutput
    }

    if ($Path) {
        $parentPath = Split-Path $Path -Parent
        if ($parentPath -and -not (Test-Path $parentPath)) {
            $null = New-Item -Path $parentPath -ItemType Directory -Force
        }

        Set-Content -Path $Path -Value $output -Encoding UTF8
    }

    $output
}

function Invoke-HawkDaily {
    <#
    .SYNOPSIS
    Runs the daily ops sweep and saves a markdown report.
    .DESCRIPTION
    Composes the full Hawkward report (AI status, disk, resources, ports,
    firewall gaps, startup, task risks, event storms) into a timestamped
    markdown file under Reports\. Use -Open to view it immediately.
    Use -RegisterTask to create a Task Scheduler entry that runs this sweep
    every day at -AtHour (default 9). Use -RemoveTask to delete it. Alias: hawkdaily.
    .PARAMETER Open
    Open the generated report with the default markdown viewer.
    .PARAMETER RegisterTask
    Register a daily scheduled task for this sweep.
    .PARAMETER RemoveTask
    Remove the daily scheduled task.
    .PARAMETER AtHour
    Hour of day (0-23) for the scheduled task. Default: 9.
    #>
    [CmdletBinding()]
    param(
        [switch]$Open,
        [switch]$RegisterTask,
        [switch]$RemoveTask,
        [ValidateRange(0, 23)]
        [int]$AtHour = 9
    )

    $taskName = 'Hawkward-DailyOps'

    if ($RemoveTask) {
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "  [OK] scheduled task '$taskName' removed" -ForegroundColor Green
        }
        else {
            Write-Host "  [i] scheduled task '$taskName' not present" -ForegroundColor DarkGray
        }
        return
    }

    if ($RegisterTask) {
        $pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
        if (-not $pwshExe) {
            Write-Host '  [!!] pwsh.exe not found in PATH' -ForegroundColor Red
            return
        }
        $action = New-ScheduledTaskAction -Execute $pwshExe -Argument @'
-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Import-Module HawkwardHybrid -Force -DisableNameChecking; Invoke-HawkDaily | Out-Null"
'@
        $trigger = New-ScheduledTaskTrigger -Daily -At ("{0:D2}:00" -f $AtHour)
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        $null = Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'PowershellOps daily ops sweep (markdown report)' -Force
        Write-Host '  ◆ HAWK DAILY — SCHEDULED TASK' -ForegroundColor Magenta
        Write-Host '  Name   : ' -NoNewline; Write-Host $taskName -ForegroundColor White
        Write-Host '  Run    : ' -NoNewline; Write-Host "daily at $("{0:D2}:00" -f $AtHour)" -ForegroundColor Cyan
        Write-Host '  Remove : ' -NoNewline; Write-Host 'hawkdaily -RemoveTask' -ForegroundColor DarkGray
        return
    }

    Write-Host "`n  ☀ HAWK DAILY OPS SWEEP" -ForegroundColor Cyan
    $reportPath = New-HawkReportPath -Extension md
    New-HawkReport -Format Markdown -Path $reportPath | Out-Null

    $item = Get-Item -LiteralPath $reportPath
    Write-Host '  [OK] report written : ' -NoNewline -ForegroundColor Green
    Write-Host $item.FullName -ForegroundColor White
    Write-Host '  Size                : ' -NoNewline
    Write-Host "$([Math]::Round($item.Length / 1KB, 1)) KB" -ForegroundColor DarkGray

    $sections = @(Select-String -LiteralPath $reportPath -Pattern '^##\s+(.+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    if ($sections.Count) {
        Write-Host '  Sections            : ' -NoNewline
        Write-Host ($sections -join ' · ') -ForegroundColor DarkGray
    }

    if ($Open) { Invoke-Item -LiteralPath $reportPath }
}

<#
.SYNOPSIS
Displays the Hawk quick reference manual.
.DESCRIPTION
Shows help topics covering AI commands, sysOps tools, search tips, report generation, and advanced usage.
Run with a topic name for focused help: ai, sysops, search, reports, advanced.
.PARAMETER Topic
Help topic to display. Leave empty for the overview.
#>
function Invoke-HawkHelp {
    <#
    .SYNOPSIS
    Asks the local AI which Hawk command fits your task.
    .DESCRIPTION
    Injects the full Hawk command reference into the local LLM context and
    answers your shell/task question using the profile's own tooling.
    Alias: hawkhelp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Question
    )

    $joined = ($Question -join ' ').Trim()
    if (-not $joined) { throw 'Ask a question, e.g. hawkhelp "how do I check disk health?"' }

    $reference = @'
HAWK COMMAND REFERENCE (available in this PowerShell profile):
AI: ai (pipe data+question to local LLM), hawkchat (chat REPL), ggl "q" [-AI|-Deep|-News] (web search/synthesis), hawkmodel -Switch <name> (swap GGUF model), llamastart/llamastop/aidoctor/llamadoctor (llama server control)
WORKSPACE: proj (cd project root), projaudit (git repos status), reload (reload profile), dash (command dashboard), hawkwatch (live dashboard), hawkman (manual), locate <name> (find command source), open (explorer here)
SENTINEL SECURITY: ghostaudit (orphaned listeners), fwaudit (ports vs firewall rules), susaudit (processes from AppData/Temp), diskaudit (disk space/hogs), taskaudit (risky scheduled tasks), evntaudit (event storms), defendermap (Defender posture), regaudit (Run-key persistence + signatures), ifeoaudit (IFEO hijacks), regsnap (registry backup), secretredact (mask secrets in text)
DIAGNOSTICS: sysview (one-shot health overview), hawkdoctor (stack health), hawkcheck (integration tests), evntmap (recent errors/warnings), resmap (top processes by RAM)
ENVIRONMENT: fwmap (firewall rules list), envmap (env vars all scopes), pathaudit (PATH hygiene), portmap (TCP listeners), nettriage (ports+process+rule), bootmap (startup entries)
SYSTEM MATRIX: specs (CPU/GPU/model), uptime, raminfo, battery, temps (ACPI thermals), fans, displays, hypervisor, power, license
NET INTEL: wifi, dnsbench (resolver latency), linkspeed, shares, hostscheck (hosts file), dnscache
SEC SCAN: shield (Defender quick view), admins (local admins), apps (installed apps), patchhistory (hotfixes), driveraudit (problem drivers), certs (cert expiry)
STORAGE: clipcheck (clipboard), recent (files <24h), drivehealth (SMART), dumps (crash dumps), badfiles (zero-byte), links (symlinks), locked (access-denied), sparse, compress
REPORTS: hawkdaily (daily ops sweep + scheduled task), hawkreport (full system report markdown/JSON)
'@

    $prompt = "$reference`n`nUSER QUESTION: $joined"
    $prompt | Invoke-HawkAI -Instruction 'You are the assistant for this PowerShell profile. Answer using the Hawk commands listed above when they fit the task; give concrete commands to run. If no Hawk command fits, say so and suggest standard PowerShell instead.'
}

function Show-HawkManual {
    [CmdletBinding()]
    param([Parameter(Position = 0)][ValidateSet('', 'ai', 'sysops', 'search', 'reports', 'advanced')][string]$Topic = '')

    $topicKey = if ($Topic) { $Topic.ToLowerInvariant() } else { '' }
    Write-Host "`nPOWERSHELLOPS - QUICK MANUAL`n" -ForegroundColor Cyan

    switch ($topicKey) {
        'ai' {
            Write-Host 'AI:' -ForegroundColor Yellow
            Write-Host '  <command> | ai "question"       Analyze pipeline data fast'
            Write-Host '  <command> | ai "deep check..."  Expands context when asked naturally'
            Write-Host '  hawkchat                        Multi-turn AI chat REPL (/help inside)'
            Write-Host '  Default behavior: fast, data-first, no commands unless requested.'
        }
        'sysops' {
            Write-Host 'SYSOPS:' -ForegroundColor Yellow
            Write-Host '  sysview      One-shot system health overview'
            Write-Host '  hawkdoctor   Profile/module/AI health'
            Write-Host '  resmap       Top CPU/RAM consumers'
            Write-Host '  diskaudit    Disk health'
            Write-Host '  evntmap      Recent warnings/errors'
            Write-Host '  evntaudit    Event storm detection'
            Write-Host '  nettriage    Ports + process + firewall rule'
            Write-Host '  fwaudit      Firewall gaps'
            Write-Host '  susaudit     Temp/AppData process audit'
            Write-Host '  taskaudit    Scheduled task risks'
            Write-Host '  bootmap      Startup persistence'
            Write-Host '  defendermap  Defender engine/status audit'
            Write-Host '  regaudit     Run-key persistence sweep'
            Write-Host '  ifeoaudit    IFEO debugger hijack check'
    Write-Host '  regsnap      Snapshot a registry key to .reg before edits'
        }
        'search' {
            Write-Host 'WEB SEARCH:' -ForegroundColor Yellow
            Write-Host '  ggl "query"                 Open browser search'
Write-Host '  ggl "query" -AI             Fast web-to-AI synthesis'
Write-Host '  ggl "query" -AI -Deep       More sources, slower'
Write-Host '  ggl "query" -AI -News       Real news articles via Google News RSS'
            Write-Host '  ggl "query" -AI -Sources 6  Choose source count'
        }
        'reports' {
            Write-Host 'REPORTS:' -ForegroundColor Yellow
            Write-Host '  hawkreport                              Console report + saved Markdown'
            Write-Host '  hawkreport -Format Json -Path file.json Save structured snapshot'
            Write-Host '  Reports are local and ignored by git.'
        }
        'advanced' {
            Write-Host 'ADVANCED:' -ForegroundColor Yellow
            Write-Host '  secretredact     Redact sensitive pipeline text'
            Write-Host '  projaudit        Git repo audit under project root'
            Write-Host '  pathaudit        PATH validation'
            Write-Host '  aidoctor         Llama model status'
            Write-Host '  llamadoctor      Llama server (auto-start)'
            Write-Host '  reload           Reload profile'
            Write-Host '  dash             Re-render dashboard'
            Write-Host '  hawkmodel        List/switch local GGUF models'
            Write-Host '  hawkdaily        Daily report + optional scheduled task'
            Write-Host '  hawkwatch        Live dashboard refresh loop'
        }
        default {
            Write-Host 'CORE:' -ForegroundColor Yellow
            Write-Host '  ai          Analyze, explain, summarize, or help with PowerShell'
            Write-Host '  ggl         Browser search or fast web-to-AI synthesis'
Write-Host '  hawkhelp    Ask the AI which Hawk command fits your task'
            Write-Host '  hawkreport  System snapshot and saved report'
            Write-Host ''
            Write-Host 'COMMON FLOW:' -ForegroundColor Yellow
            Write-Host '  resmap | ai "what is using the most memory?"'
            Write-Host '  ggl "windows event id 10016" -AI'
            Write-Host ''
            Write-Host 'MORE HELP:' -ForegroundColor Yellow
            Write-Host '  hawkman ai | sysops | search | reports | advanced'
        }
    }
}

