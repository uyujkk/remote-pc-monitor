$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../collector/Health.ps1')
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
$signals=@{stabilityIndex=9.2;wheaEvents24h=0;memoryEvents24h=0;wheaEventsCapped=$false}
$normal=[ordered]@{cpu=20;memory=50;disks=@(@{usedGb=70;totalGb=100});cpuTemp=55;gpuTemp=60}
Set-HealthMetrics $normal $signals
Assert ($normal.healthScore -eq 100) 'healthy resources should score 100'
Assert ($normal.healthCoverage -eq 100) 'all signals should give full coverage'
$pressure=[ordered]@{cpu=100;memory=95;disks=@(@{usedGb=98;totalGb=100});cpuTemp=100;gpuTemp=95}
Set-HealthMetrics $pressure @{stabilityIndex=$null;wheaEvents24h=3;memoryEvents24h=1;wheaEventsCapped=$false}
Assert ($pressure.healthScore -lt 50) 'resource pressure should lower score'
$missing=[ordered]@{cpu=$null;memory=$null;disks=@();cpuTemp=$null;gpuTemp=$null}
Set-HealthMetrics $missing @{stabilityIndex=$null;wheaEvents24h=$null;memoryEvents24h=$null;wheaEventsCapped=$false}
Assert ($null -eq $missing.healthScore) 'missing signals must not imply a perfect score'
Assert ($missing.healthCoverage -eq 0) 'missing signals must have zero coverage'
Write-Output 'Health score tests OK'
