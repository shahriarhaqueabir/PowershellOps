#region LegacyMatrix.System

function Get-HawkSpecs {
    <#
    .SYNOPSIS
    Shows the hardware blueprint: CPU, cores, vendor, model, GPU.
    #>
    Write-Host "`n  󰘚 CORE ENGINE MACHINE BLUEPRINT" -ForegroundColor Cyan
    $cpu = Get-CimInstance Win32_Processor; $comp = Get-CimInstance Win32_ComputerSystem; $gpu = Get-CimInstance Win32_VideoController
    [PSCustomObject]@{ "Processor" = $cpu.Name; "Cores" = $cpu.NumberOfCores; "Vendor" = $comp.Manufacturer; "Model" = $comp.Model; "Graphics Engine" = $gpu.Description } | Format-List
}

function Get-HawkUptime {
    <#
    .SYNOPSIS
    Shows system boot time and continuous uptime.
    #>
    Write-Host "`n  󱑎 KERNEL SCHEDULER LIFECYCLE CHRONICLE" -ForegroundColor Cyan
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; $span = (Get-Date) - $boot
    [PSCustomObject]@{ "System Boot Anchor" = $boot; "Continuous Run Time" = "$($span.Days)d $($span.Hours)h $($span.Minutes)m" } | Format-List
}

function Get-HawkRamInfo {
    <#
    .SYNOPSIS
    Lists physical RAM slots: bank, capacity, speed, manufacturer.
    #>
    Write-Host "`n  󰘚 PHYSICAL MEMORY SLOT ARCHITECTURE" -ForegroundColor Cyan
    Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, Capacity, Speed, Manufacturer | Format-Table -AutoSize
}

function Get-HawkBattery {
    <#
    .SYNOPSIS
    Reports battery design/full-charge capacity and calculated health %.
    #>
    Write-Host "`n  󰁹 POWER CELL DEGRADATION METRICS" -ForegroundColor Cyan
    $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if (-not $bat) { Write-Host "  No active battery tracking hardware detected." -ForegroundColor DarkGray; return }
    $health = if ($bat.DesignCapacity -gt 0) { "$([Math]::Round(($bat.FullChargeCapacity / $bat.DesignCapacity) * 100, 1))%" } else { "N/A" }
    $design = if ($bat.DesignCapacity) { $bat.DesignCapacity } else { "N/A" }
    $full = if ($bat.FullChargeCapacity) { $bat.FullChargeCapacity } else { "N/A" }
    [PSCustomObject]@{ "Design Capacity" = $design; "Full Charge Capacity" = $full; "Calculated Health Status" = $health } | Format-List
}

function Get-HawkThermals {
    <#
    .SYNOPSIS
    Reads ACPI thermal zone temperatures and converts Kelvin readings to Celsius.
    #>
    Write-Host "`n  🌡 THERMAL ZONE INFRARED SWEEP" -ForegroundColor Cyan
    $zones = @(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue)
    if (-not $zones) {
        Write-Host "  No ACPI thermal zones exposed by this hardware/driver stack." -ForegroundColor DarkGray
        Write-Host "  (Many consumer boards require vendor drivers or admin elevation.)" -ForegroundColor DarkGray
        return
    }
    $zones | ForEach-Object {
        $celsius = [Math]::Round(($_.CurrentTemperature / 10.0) - 273.15, 1)
        $state = if ($celsius -ge 85) { 'CRITICAL' } elseif ($celsius -ge 70) { 'HOT' } elseif ($celsius -ge 50) { 'WARM' } else { 'NOMINAL' }
        [PSCustomObject]@{ Zone = $_.InstanceName; TemperatureC = "$celsius °C"; State = $state }
    } | Format-Table -AutoSize
}

function Get-HawkFans {
    <#
    .SYNOPSIS
    Reports cooling fan devices and their reported speeds via WMI.
    #>
    Write-Host "`n  🌀 COOLING FAN ROTATION TELEMETRY" -ForegroundColor Cyan
    $fans = @(Get-CimInstance -ClassName Win32_Fan -ErrorAction SilentlyContinue | Where-Object { $_.Name -or $_.DesiredSpeed })
    if (-not $fans) {
        Write-Host "  No fan telemetry exposed via WMI on this machine." -ForegroundColor DarkGray
        Write-Host "  (Fan curves are typically controlled by the EC/vendor utility, not WMI.)" -ForegroundColor DarkGray
        return
    }
    $fans | ForEach-Object {
        $rpm = if ($_.DesiredSpeed) { "$($_.DesiredSpeed) RPM" } else { 'Unreported' }
        [PSCustomObject]@{ Fan = $_.Name; Status = $_.Status; Speed = $rpm }
    } | Format-Table -AutoSize
}

function Get-HawkDisplays {
    <#
    .SYNOPSIS
    Lists attached displays and their current video modes.
    #>
    Write-Host "`n  󰍹 INTERFACED GRAPHICS LAYER DISPLAYS" -ForegroundColor Cyan
    Get-CimInstance Win32_VideoController | Select-Object Description, VideoModeDescription | Format-Table -AutoSize
}

function Get-HawkHypervisor {
    <#
    .SYNOPSIS
    Checks virtualization readiness (hypervisor present, firmware enabled).
    #>
    Write-Host "`n  󰘚 BIOS MOVEMENT VIRTUALIZATION SUITE READINESS" -ForegroundColor Cyan
    Get-CimInstance Win32_ComputerSystem | Select-Object HypervisorPresent, VirtualizationFirmwareEnabled | Format-List
}

function Get-HawkPower {
    <#
    .SYNOPSIS
    Shows the active Windows power scheme.
    #>
    Write-Host "`n  󰐎 KERNEL SCHEDULER SYSTEM ENERGY SCHEMES" -ForegroundColor Cyan
    powercfg /getactivescheme | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}

function Get-HawkLicense {
    <#
    .SYNOPSIS
    Shows Windows licensing status for activated software products.
    #>
    Write-Host "`n  󰘚 WINDOWS ENGINE CERTIFICATE CONFIGURATION DATA" -ForegroundColor Cyan
    try {
        $products = @(Get-CimInstance Win32_SoftwareLicensingProduct -ErrorAction Stop)
        $licensed = $products | Where-Object { $_.PartialProductKey }
        if ($licensed) { $licensed | Select-Object Name, LicenseStatus | Format-Table -AutoSize }
        else { Write-Host "  No licensed software products reported on this device." -ForegroundColor Gray }
    }
    catch {
        Write-Host "  License configuration data unavailable on this device (SoftwareLicensing CIM class not present)." -ForegroundColor Gray
    }
}

#endregion

#region LegacyMatrix.Network

function Get-HawkWifi {
    <#
    .SYNOPSIS
    Shows Wi-Fi SSID and signal strength, or notes ethernet-only links.
    #>
    Write-Host "`n  󰖩 RF HARDWARE WIRELESS LINK POLICIES" -ForegroundColor Green
    $w = netsh wlan show interfaces
    $s = ($w | Select-String "^\s+SSID\s+:\s+(.*)$") -replace ".*:\s+"
    if ([string]::IsNullOrWhiteSpace($s)) { Write-Host "  Device running via hardline copper ethernet link interface." -ForegroundColor Gray } else {
        [PSCustomObject]@{ SSID = $s.Trim(); Signal = (($w | Select-String "^\s+Signal\s+:\s+(.*)$") -replace ".*:\s+").Trim() } | Format-List
    }
}

function Get-HawkDnsBench {
    <#
    .SYNOPSIS
    Times a DNS lookup of google.com to gauge resolver latency.
    #>
    Write-Host "`n  󰓅 DOMAIN NAME TRANSLATION LATENCY SPEED TEST" -ForegroundColor Green
    $t = Measure-Command { Resolve-DnsName google.com -ErrorAction SilentlyContinue }
    [PSCustomObject]@{ "Host Resolver Loop Timeout" = "$([Math]::Round($t.TotalMilliseconds, 2)) ms" } | Format-List
}

function Get-HawkLinkSpeed {
    <#
    .SYNOPSIS
    Lists connected network adapters with negotiated link speeds.
    #>
    Write-Host "`n  󰛳 HARDWARE ADAPTER CONTROLLER CONNECTION RATES" -ForegroundColor Green
    Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, InterfaceDescription, LinkSpeed | Format-Table -AutoSize
}

function Get-HawkShares {
    <#
    .SYNOPSIS
    Lists local SMB shares (hidden administrative shares excluded).
    #>
    Write-Host "`n  󰛳 ACTIVE LOCAL AREA NETWORK SMB STORAGE ATTACHMENTS" -ForegroundColor Green
    if (-not (Get-Command Get-SmbShare -ErrorAction SilentlyContinue)) {
        Write-Host "  SMB cmdlets unavailable on this Windows edition - share scan skipped." -ForegroundColor Yellow
        return
    }
    try {
        Get-SmbShare -ErrorAction Stop |
            Where-Object { $_.Name -notlike "*$" } |
            Select-Object Name, Path, Description | Format-Table -AutoSize
    }
    catch {
        Write-Host ("  SMB share enumeration failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

function Get-HawkHostsCheck {
    <#
    .SYNOPSIS
    Surfaces active (non-comment) entries in the hosts file.
    #>
    Write-Host "`n  󰞀 LOOPBACK RESOLUTION TRAFFIC SYSTEM REDIRECT INSPECTION" -ForegroundColor Green
    $p = "$env:windir\System32\drivers\etc\hosts"
    if (Test-Path $p) { Get-Content $p | Where-Object { $_ -match "^\s*[^#]" } | ForEach-Object { Write-Host "  Active Map Override: $_" -ForegroundColor Yellow } }
}

function Get-HawkDnsCache {
    <#
    .SYNOPSIS
    Shows the first 20 entries of the local DNS resolver cache.
    #>
    Write-Host "`n  󰓅 CACHED MEMORY BOUND ADAPTER RESOLUTIONS" -ForegroundColor Green
    Get-DnsClientCache | Select-Object Name, EntryStatus, Data | Select-Object -First 20 | Format-Table -AutoSize
}

#endregion

#region LegacyMatrix.Security

function Get-HawkShield {
    <#
    .SYNOPSIS
    Shows Defender real-time protection state and signature freshness.
    #>
    Write-Host "`n  󰞀 WINDOWS DEFENDER ENGINE ENGINE SUBSYSTEM DEFINITIONS" -ForegroundColor Yellow
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        $s = Get-MpComputerStatus; [PSCustomObject]@{ "RealTimeProtection" = $s.RealTimeProtectionEnabled; "DefinitionsUpdated" = $s.AntispywareSignatureLastUpdated } | Format-List
    } else { Write-Host "  Defender telemetry isolated under current security token configuration context." -ForegroundColor Red }
}

function Get-HawkAdmins {
    <#
    .SYNOPSIS
    Lists members of the local Administrators group.
    #>
    Write-Host "`n  󰀕 LOCAL EXECUTIVE PRIVILEGE SECURITY TOKENS" -ForegroundColor Yellow
    Get-LocalGroupMember -Group "Administrators" | Select-Object Name, PrincipalSource, ObjectClass | Format-Table -AutoSize
}

function Get-HawkApps {
    <#
    .SYNOPSIS
    Lists the first 30 installed applications from the machine-wide uninstall registry.
    #>
    Write-Host "`n  󰀻 SYSTEM APPLICATION SOFTWARE MANAGEMENT DIRECTORY" -ForegroundColor Yellow
    Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | Select-Object DisplayName, DisplayVersion | Sort-Object DisplayName | Select-Object -First 30 | Format-Table -AutoSize
}

function Get-HawkPatchHistory {
    <#
    .SYNOPSIS
    Shows the 15 most recent installed Windows hotfixes (KB updates).
    #>
    Write-Host "`n  󰚰 SECURITY PATCH DISPATCH DEVELOPMENT MAINTENANCE ARTIFACTS" -ForegroundColor Yellow
    Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 15 | Format-Table -AutoSize
}

function Get-HawkDriverAudit {
    <#
    .SYNOPSIS
    Flags signed PnP drivers whose status is anything other than OK.
    #>
    Write-Host "`n  󰘚 CRITICAL PLUG-AND-PLAY PHYSICAL DEVICE HARDWARE STACKS" -ForegroundColor Yellow
    Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceStatus -ne "OK" -and $null -ne $_.DeviceStatus } | Select-Object DeviceName, DeviceStatus, Manufacturer | Format-Table -AutoSize
}

function Get-HawkCerts {
    <#
    .SYNOPSIS
    Lists LocalMachine personal certificates with expiry dates.
    #>
    Write-Host "`n  󰞀 PHYSICAL MACHINE ASSET CRYPTOGRAPHY IDENTIFICATION VALIDITY" -ForegroundColor Yellow
    Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Select-Object Subject, NotAfter | Format-Table -AutoSize
}

#endregion

#region LegacyMatrix.Storage

function Get-HawkClipCheck {
    <#
    .SYNOPSIS
    Inspects clipboard contents: length plus a 40-character preview.
    #>
    Write-Host "`n  󰅌 VOLATILE LAYER CLIPBOARD RAM RUNTIME DATA" -ForegroundColor Yellow
    $c = Get-Clipboard -Raw -ErrorAction SilentlyContinue
    if ($c) { [PSCustomObject]@{ "Buffer Allocations" = $c.Length; "Isolated Stream Data Preview" = $c.Substring(0, [Math]::Min(40, $c.Length)) } | Format-List } else { Write-Host "  Clipboard interface buffer is clear." -ForegroundColor Gray }
}

function Get-HawkRecent {
    <#
    .SYNOPSIS
    Lists files modified in Documents/Downloads within the last 24 hours.
    #>
    Write-Host "`n  󰈙 TRANSACTION RECORDS MODIFIED WITHIN RUNTIME POOL (LAST 24 HOURS)" -ForegroundColor Magenta
    Get-ChildItem -Path "$env:USERPROFILE\Documents", "$env:USERPROFILE\Downloads" -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } | Select-Object Name, LastWriteTime | Format-Table -AutoSize
}

function Get-HawkDriveHealth {
    <#
    .SYNOPSIS
    Shows physical disk SMART health and operational status.
    #>
    Write-Host "`n  󰋊 SMART STORAGE CONTROLLER FAULT INSIGHT INDICES" -ForegroundColor Magenta
    Get-CimInstance -Namespace root\Microsoft\Windows\Storage -ClassName MSFT_PhysicalDisk -ErrorAction SilentlyContinue | Select-Object DeviceId, FriendlyName, OperationalStatus, HealthStatus | Format-Table -AutoSize
}

function Get-HawkDumps {
    <#
    .SYNOPSIS
    Checks C:\Windows\Minidump for crash dump artifacts.
    #>
    Write-Host "`n  󰓦 OPERATING KERNEL MINIDUMP SYSTEM CRASH RECOVERIES" -ForegroundColor Magenta
    $d = "$env:windir\Minidump"; if (Test-Path $d) { Get-ChildItem $d | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize } else { Write-Host "  No operating engine panic dumps exist within standard crash structures." -ForegroundColor Gray }
}

function Get-HawkBadFiles {
    <#
    .SYNOPSIS
    Scans Documents for zero-byte files (possible corruption artifacts).
    #>
    Write-Host "`n  󰈙 SCANNING USER SPACE FOR ZERO-BYTE ARTIFACT STRUCTURAL DEFECTS" -ForegroundColor Magenta
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 } | Select-Object Name, DirectoryName | Format-Table -AutoSize
}

function Get-HawkLinks {
    <#
    .SYNOPSIS
    Maps symlinks/junctions (reparse points) in the user profile root.
    #>
    Write-Host "`n  󰉋 NTFS REPARSE DATA SYSTEM POINTER RECORDS AND SYMLINKS" -ForegroundColor Magenta
    Get-ChildItem -Path "$env:USERPROFILE" -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -match "ReparsePoint" } | Select-Object Name, Target | Format-Table -AutoSize
}

function Get-HawkLocked {
    <#
    .SYNOPSIS
    Recursively walks Documents and reports access-denied entries.
    #>
    Write-Host "`n  󰈙 OPERATIONAL LAYER ACCESS DENIED STREAM BLOCKS" -ForegroundColor Magenta
    Write-Host "  Auditing directory infrastructure restrictions..." -ForegroundColor Gray
    Get-ChildItem "$env:USERPROFILE\Documents" -Recurse -ErrorAction SilentlyContinue -ErrorVariable lockedOut | Out-Null
    $lockedOut | ForEach-Object { Write-Host "  Restricted Pointer Entry: $($_.TargetObject)" -ForegroundColor DarkGray }
}

function Get-HawkSparse {
    <#
    .SYNOPSIS
    Finds sparse-file allocations in Documents.
    #>
    Write-Host "`n  󰋊 NTFS SPARSE FILE ALLOCATION TABLE MAPS" -ForegroundColor Magenta
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -File -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -match "SparseFile" } | Select-Object Name, Length | Format-Table -AutoSize
}

function Get-HawkCompress {
    <#
    .SYNOPSIS
    Finds NTFS-compressed files in Documents.
    #>
    Write-Host "`n  󰋊 SYSTEM DISK NATIVE FILE COMPRESSION MATRIX ALLOCATIONS" -ForegroundColor Magenta
    Get-ChildItem -Path "$env:USERPROFILE\Documents" -File -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -match "Compressed" } | Select-Object Name, Length | Format-Table -AutoSize
}

#endregion

#region LegacyMatrix.Utilities

function Get-HawkAppLocation {
    <#
    .SYNOPSIS
    Traces where an app/command resolves from (path, type, source).
    .PARAMETER AppName
    Name of the app or command to trace.
    #>
    param([string]$AppName)
    Write-Host "`n  󰍎 TRACING ARCHITECTURE LOCATION PATHS FOR: $AppName" -ForegroundColor Cyan
    if (-not $AppName) { Write-Host "  󰜺 Supply an app or command target name." -ForegroundColor Red; return }
    Get-Command $AppName -ErrorAction SilentlyContinue | Select-Object Name, CommandType, Source | Format-List
}

function Invoke-ExplorerHere {
    <#
    .SYNOPSIS
    Opens File Explorer at the current directory.
    #>
    $CurrentPath = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    Write-Host "`n  󰉋 BRIDGE LINK: OPENING GUI VIEW AT $CurrentPath" -ForegroundColor Green
    Invoke-Item .
}

#endregion

