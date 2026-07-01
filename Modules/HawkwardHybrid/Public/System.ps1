# ── PUBLIC: SYSTEM DIAGNOSTICS ─────────────────────────────────────────────

function Get-HawkHealth {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
    $totalRam = [Math]::Round($os.TotalVisibleMemorySize / 1KB / 1024, 1)
    $freeRam = [Math]::Round($os.FreePhysicalMemory / 1KB / 1024, 1)
    [PSCustomObject]@{
        "CPU Load"  = "$([Math]::Round($cpu.Average, 0))%"
        "RAM Usage" = "$($totalRam - $freeRam) GB / $totalRam GB"
        "Processes" = (Get-Process).Count
        "Handles"   = (Get-Process | Measure-Object -Property HandleCount -Sum).Sum
    }
}

function Get-HawkSpec {
    return Invoke-HawkCachedData -Key 'sys_specs' -ExpirySeconds 300 -ScriptBlock {
        $cpu = Get-CimInstance Win32_Processor
        $comp = Get-CimInstance Win32_ComputerSystem
        $gpu = Get-CimInstance Win32_VideoController
        [PSCustomObject]@{
            "Processor"       = $cpu.Name
            "Cores"           = $cpu.NumberOfCores
            "Vendor"          = $comp.Manufacturer
            "Model"           = $comp.Model
            "Graphics Engine" = $gpu.Description
        }
    }
}

function Get-HawkUptime {
    return Invoke-HawkCachedData -Key 'sys_uptime' -ExpirySeconds 10 -ScriptBlock {
        $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $span = (Get-Date) - $boot
        [PSCustomObject]@{
            "System Boot Anchor"  = $boot
            "Continuous Run Time" = "$($span.Days)d $($span.Hours)h $($span.Minutes)m"
        }
    }
}

function Get-HawkRamInfo {
    return Invoke-HawkCachedData -Key 'sys_raminfo' -ExpirySeconds 600 -ScriptBlock {
        Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, @{N='CapacityGB';E={[Math]::Round($_.Capacity / 1GB, 1)}}, Speed, Manufacturer
    }
}

function Get-HawkBattery {
    return Invoke-HawkCachedData -Key 'sys_battery' -ExpirySeconds 30 -ScriptBlock {
        $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if (-not $bat) {
            return [PSCustomObject]@{ "Status" = 'No battery hardware tracked' }
        }
        [PSCustomObject]@{
            "Design Capacity"          = $bat.DesignCapacity
            "Full Charge Capacity"    = $bat.FullChargeCapacity
            "Calculated Health Status" = "$([Math]::Round(($bat.FullChargeCapacity / $bat.DesignCapacity) * 100, 1))%"
        }
    }
}

function Get-HawkDisplay {
    return Invoke-HawkCachedData -Key 'sys_displays' -ExpirySeconds 600 -ScriptBlock {
        Get-CimInstance Win32_VideoController | Select-Object Description, VideoModeDescription
    }
}

function Get-HawkDiskPressureAudit {
    return Invoke-HawkCachedData -Key 'sys_diskpressure' -ExpirySeconds 30 -ScriptBlock {
        Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            $sz = [Math]::Round($_.Size / 1GB, 1)
            $fr = [Math]::Round($_.FreeSpace / 1GB, 1)
            [PSCustomObject]@{
                DeviceID    = $_.DeviceID
                SizeGB      = $sz
                FreeGB      = $fr
                FreePercent = "$([Math]::Round(($fr / [Math]::Max(1, $sz)) * 100, 1))%"
            }
        }
    }
}

function Get-HawkResourceMap {
    return Invoke-HawkCachedData -Key 'sys_resourcemap' -ExpirySeconds 5 -ScriptBlock {
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | ForEach-Object {
            [PSCustomObject]@{
                ProcessName = $_.ProcessName
                Id          = $_.Id
                RAMMB       = [Math]::Round($_.WorkingSet / 1MB, 1)
                CPUSec      = [Math]::Round($_.Cpu, 1)
            }
        }
    }
}

function Get-HawkPortMap {
    return Invoke-HawkCachedData -Key 'sys_portmap' -ExpirySeconds 10 -ScriptBlock {
        if ($IsWindows) {
            if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
                $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Sort-Object LocalPort, OwningProcess -Unique
                $procMap = @{}
                Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $procMap[$_.Id] = $_.ProcessName }
                foreach ($conn in $connections) {
                    [PSCustomObject]@{
                        Port    = $conn.LocalPort
                        PID     = $conn.OwningProcess
                        Process = if ($procMap.ContainsKey($conn.OwningProcess)) { $procMap[$conn.OwningProcess] } else { 'Unknown' }
                    }
                }
            } else {
                foreach ($conn in [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()) {
                    [PSCustomObject]@{ Port = $conn.Port; PID = 'N/A'; Process = 'System Listen Stack' }
                }
            }
        } else {
            foreach ($conn in [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()) {
                [PSCustomObject]@{ Port = $conn.Port; PID = 'N/A'; Process = 'System Listen Stack' }
            }
        }
    }
}

function Get-HawkAdmin {
    try {
        Get-LocalGroupMember -Group 'S-1-5-32-544' -ErrorAction Stop | Select-Object Name, PrincipalSource, ObjectClass
    } catch {
        try {
            Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue | Select-Object Name, PrincipalSource, ObjectClass
        } catch {
            Write-Verbose "Get-HawkAdmin: Unable to query Administrators group: $($_.Exception.Message)"
            [PSCustomObject]@{ Name = 'Error querying admin group'; PrincipalSource = ''; ObjectClass = '' }
        }
    }
}

function Get-HawkHypervisor {
    $model = (Get-CimInstance Win32_ComputerSystem).Model
    $isVM = $model -match '(VirtualBox|VMware|Virtual Machine|Hyper-V|VirtualBox|QEMU|KVM|Xen)'
    [PSCustomObject]@{ Status = if ($isVM) { 'Virtual' } else { 'Physical' }; Model = $model }
}

function Get-HawkPower {
    try {
        $plan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -Filter "IsActive=True" -ErrorAction Stop
        [PSCustomObject]@{ Mode = $plan.ElementName }
    } catch {
        [PSCustomObject]@{ Mode = 'Unknown'; Note = 'Requires administrator privileges to query power plan.' }
    }
}

function Get-HawkLicense {
    $license = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $license) { return [PSCustomObject]@{ Status = 'N/A'; PartialProductKey = '' } }
    $status = @{1='Licensed';0='Unlicensed'}[$license.LicenseStatus]
    [PSCustomObject]@{ Status = $status; PartialProductKey = $license.PartialProductKey }
}

function Get-HawkTempCheck {
    $totalLength = [long]0
    try {
        if (Test-Path $env:TEMP) {
            foreach ($file in [System.IO.Directory]::EnumerateFiles($env:TEMP, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { $totalLength += [System.IO.FileInfo]::new($file).Length } catch { Write-Verbose "Could not get file size: $($_.Exception.Message)" }
            }
        }
    } catch { Write-Warning "Temp directory enumeration failed: $($_.Exception.Message)" }
    [PSCustomObject]@{
        Target = $env:TEMP
        SizeMB = [Math]::Round(($totalLength / 1MB), 1)
    }
}

function Get-HawkClipCheck {
    $len = try {
        if (Get-Command Get-Clipboard -ErrorAction SilentlyContinue) {
            (Get-Clipboard -Raw -ErrorAction SilentlyContinue).Length
        } else { 0 }
    } catch { 0 }
    [PSCustomObject]@{ ClipboardLength = if ($null -eq $len) { 0 } else { $len } }
}

function Get-HawkDriveHealth {
    $result = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue |
        Select-Object InstanceName, PredictFailure
    if (-not $result) { return [PSCustomObject]@{ Status = 'No SMART data available'; PredictFailure = 'Unknown' } }
    $result
}

function Get-HawkDump {
    $result = Get-ChildItem "$env:windir\Minidump" -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime
    if (-not $result) { return [PSCustomObject]@{ Status = 'No memory dumps found'; Path = "$env:windir\Minidump" } }
    $result
}

function Get-HawkBadFile {
    $results = @()
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DeviceID
    if (-not $drives) { $drives = @('C:') }

    $suspicious = @('.encrypt', '.locked', '.crypt', '.xyz', '.zepto', '.cerber')
    $matchesSuspicious = @()
    $filesOver500MB = @()

    foreach ($drive in $drives) {
        try {
            $driveRoot = "$drive\"
            $driveFiles = Get-ChildItem -Path $driveRoot -File -ErrorAction SilentlyContinue
            $driveFiles | Where-Object { $_.Length -gt 500MB } | ForEach-Object { $filesOver500MB += $_ }
            $driveFiles | Where-Object { $_.Extension -in $suspicious } | ForEach-Object { $matchesSuspicious += $_ }
        } catch { Write-Verbose "Could not scan drive $drive`: $($_.Exception.Message)" }
    }

    [PSCustomObject]@{
        FilesOver500MB = @($filesOver500MB).Count
        LargestFileMB = if ($filesOver500MB) { [Math]::Round(($filesOver500MB | Sort-Object Length -Descending | Select-Object -First 1).Length / 1MB, 1) } else { 0 }
        SuspiciousExtensions = @($matchesSuspicious).Count
    }
}

function Get-HawkLink {
    $shell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue
    if (-not $shell) { return [PSCustomObject]@{ LinksProcessed = 0; Error = 'WScript.Shell COM unavailable' } }
    $links = Get-ChildItem *.lnk -ErrorAction SilentlyContinue
    if (-not $links) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null; return [PSCustomObject]@{ LinksProcessed = 0; Status = 'No .lnk files in current directory' } }
    $results = foreach ($link in $links) {
        try {
            $shortcut = $shell.CreateShortcut($link.FullName)
            [PSCustomObject]@{ Name = $link.Name; Target = $shortcut.TargetPath }
        } catch { Write-Verbose "Failed to resolve shortcut: $($_.Exception.Message)" }
    }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    if (-not $results) { return [PSCustomObject]@{ LinksProcessed = 0; Status = 'No shortcuts could be resolved' } }
    $results
}

function Get-HawkLock {
    param([string]$Path = (Get-Location).Path)
    $files = Get-ChildItem $Path -File -ErrorAction SilentlyContinue | Select-Object -First 50
    $results = foreach ($file in $files) {
        try {
            $stream = [System.IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None')
            $stream.Dispose()
        } catch {
            [PSCustomObject]@{ File = $file.Name; Locked = $true; Message = $_.Exception.Message }
        }
    }
    if (-not $results) { return [PSCustomObject]@{ LockedFiles = 0; Status = 'No locked files detected' } }
    $results
}

function Get-HawkSparseFile {
    $result = Get-ChildItem -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [System.IO.FileAttributes]::SparseFile } |
        Select-Object FullName, Length | Select-Object -First 20
    if (-not $result) { return [PSCustomObject]@{ Status = 'No sparse files detected'; Count = 0 } }
    $result
}

function Get-HawkCompressedDir {
    $result = Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Compressed } |
        Select-Object FullName, @{N='CompressedSizeKB';E={[Math]::Round(($_.GetFiles() | Measure-Object Length -Sum).Sum / 1KB, 1)}} |
        Select-Object -First 20
    if (-not $result) { return [PSCustomObject]@{ Status = 'No compressed directories detected'; Count = 0 } }
    $result
}

function Get-HawkApp {
    if (-not $IsWindows) { return [PSCustomObject]@{ Name = 'Cross-platform Environment'; Version = 'N/A' } }
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    try {
        Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayVersion } |
            Select-Object @{N='Name';E={$_.DisplayName}}, @{N='Version';E={$_.DisplayVersion}}
    } catch { @() }
}

function Get-HawkAppLocation { param([string]$App) Get-Command $App -ErrorAction SilentlyContinue | Select-Object Name, Source }

function Get-HawkRecent {
    $recentDir = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
    if (-not (Test-Path $recentDir)) { return @() }
    Get-ChildItem $recentDir -ErrorAction SilentlyContinue |
        Select-Object Name, LastWriteTime | Sort-Object LastWriteTime -Descending | Select-Object -First 5
}

function Get-HawkCert { Get-ChildItem Cert:\CurrentUser\My | Select-Object Subject, Thumbprint, NotAfter }

function Get-HawkPatchHistory { Get-CimInstance Win32_QuickFixEngineering | Select-Object HotFixID, InstalledOn | Sort-Object InstalledOn -Descending | Select-Object -First 5 }

function Get-HawkDriverAudit {
    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceName -and -not $_.IsSigned } |
        Select-Object DeviceName, DriverVersion, DriverDate | Select-Object -First 10
}

function Get-HawkSystem {
    [CmdletBinding()]
    param([ValidateSet('Health','Spec','Uptime','Ram','Battery','Display','Disk','Resource','Port')][string]$Type = 'Health')
    switch ($Type) {
        'Health'   { Get-HawkHealth }
        'Spec'     { Get-HawkSpec }
        'Uptime'   { Get-HawkUptime }
        'Ram'      { Get-HawkRamInfo }
        'Battery'  { Get-HawkBattery }
        'Display'  { Get-HawkDisplay }
        'Disk'     { Get-HawkDiskPressureAudit }
        'Resource' { Get-HawkResourceMap }
        'Port'     { Get-HawkPortMap }
    }
}
