$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module 'E:\Projects\projectx\powershellOps\Modules\HawkwardHybrid\HawkwardHybrid.psd1' -Force -ErrorAction Stop
$config = New-PesterConfiguration
$config.Run.Path = 'E:\Projects\projectx\powershellOps\Modules\HawkwardHybrid\Tests\HawkwardHybrid.Tests.ps1'
$config.Output.Verbosity = 'Normal'
$result = Invoke-Pester -Configuration $config
Write-Host "`nTOTAL:$($result.TotalCount) PASSED:$($result.PassedCount) FAILED:$($result.FailedCount) SKIPPED:$($result.SkippedCount)"
if ($result.FailedCount -eq 0) { Write-Host 'ALL PASSED' -ForegroundColor Green }
