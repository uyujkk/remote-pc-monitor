param([switch]$Once,[switch]$NoUpload,[string]$ConfigPath=(Join-Path $PSScriptRoot 'config.json'))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Diagnostics.ps1')
. (Join-Path $PSScriptRoot 'AutoMas.ps1')
. (Join-Path $PSScriptRoot 'Health.ps1')
. (Join-Path $PSScriptRoot 'ResultCrypto.ps1')
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$logPath=Join-Path $PSScriptRoot 'collector.log'
function Log([string]$Message){
 $line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message
 Write-Host $line
 try {if((Test-Path -LiteralPath $logPath) -and (Get-Item -LiteralPath $logPath).Length -gt 1MB){Move-Item -LiteralPath $logPath -Destination ($logPath+'.1') -Force};Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8}catch{}
}
function Num($value,[double]$Scale=1){if($null -eq $value -or "$value" -eq ''){return $null};$n=0.0;if([double]::TryParse("$value",[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$n) -and -not [double]::IsNaN($n) -and -not [double]::IsInfinity($n)){return [Math]::Round($n/$Scale,3)};return $null}
function Cim([string]$Class,[string]$Filter=''){try{if($Filter){return Get-CimInstance -ClassName $Class -Filter $Filter -OperationTimeoutSec 8 -ErrorAction Stop}else{return Get-CimInstance -ClassName $Class -OperationTimeoutSec 8 -ErrorAction Stop}}catch{return $null}}
function Read-Sample {
 $s=[ordered]@{sampleId=[guid]::NewGuid().ToString();cpu=$null;memory=$null;gpu=$null;cpuTemp=$null;gpuTemp=$null;netUp=$null;netDown=$null;memoryUsedGb=$null;memoryTotalGb=$null;gpuName=$null;gpuMemoryUsedGb=$null;gpuMemoryTotalGb=$null;gpuPowerW=$null;cpuMhz=$null;uptimeSeconds=$null;diskRead=$null;diskWrite=$null;disks=@();cpuName=$null;motherboardName=$null;memoryModules=@();storageModels=@();cpuTempSource=$null}
 $os=Cim 'Win32_OperatingSystem';if($os){$s.memoryTotalGb=Num $os.TotalVisibleMemorySize 1048576;$s.memoryUsedGb=Num ($os.TotalVisibleMemorySize-$os.FreePhysicalMemory) 1048576;if($os.TotalVisibleMemorySize -gt 0){$s.memory=Num (100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize))};$s.uptimeSeconds=[Math]::Max(0,[Math]::Floor(((Get-Date)-$os.LastBootUpTime).TotalSeconds))}
 $cpu=Cim 'Win32_PerfFormattedData_PerfOS_Processor' "Name='_Total'";if($cpu){$s.cpu=Num $cpu.PercentProcessorTime}
 $processor=@(Cim 'Win32_Processor'|Where-Object{$null -ne $_})|Select-Object -First 1;if($processor){$s.cpuMhz=Num $processor.CurrentClockSpeed;$s.cpuName=([string]$processor.Name).Trim()}
 $board=@(Cim 'Win32_BaseBoard'|Where-Object{$null -ne $_})|Select-Object -First 1;if($board){$s.motherboardName=(([string]$board.Manufacturer+' '+[string]$board.Product).Trim())}
 $s.memoryModules=@(Cim 'Win32_PhysicalMemory'|Where-Object{$_.Capacity -gt 0}|Select-Object -First 16|ForEach-Object{
  $label=(([string]$_.Manufacturer+' '+[string]$_.PartNumber).Trim());if(-not $label){$label='内存模组'}
  [ordered]@{name=$label;capacityGb=Num $_.Capacity 1073741824;speedMhz=Num $_.ConfiguredClockSpeed}
 })
 $s.storageModels=@(Cim 'Win32_DiskDrive'|Where-Object{$_.Size -gt 0}|Select-Object -First 16|ForEach-Object{
  $label=([string]$_.Model).Trim();if(-not $label){$label='物理磁盘'}
  [ordered]@{name=$label;sizeGb=Num $_.Size 1073741824}
 })
 $disk=Cim 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk' "Name='_Total'";if($disk){$s.diskRead=Num $disk.DiskReadBytesPersec 1000000;$s.diskWrite=Num $disk.DiskWriteBytesPersec 1000000}
 $net=@(Cim 'Win32_PerfFormattedData_Tcpip_NetworkInterface'|Where-Object{$null -ne $_});if($net.Count -gt 0){$s.netUp=Num (($net|Measure-Object BytesSentPersec -Sum).Sum) 1000000;$s.netDown=Num (($net|Measure-Object BytesReceivedPersec -Sum).Sum) 1000000}
 $s.disks=@(Cim 'Win32_LogicalDisk' 'DriveType=3'|Where-Object{$_.Size -gt 0}|ForEach-Object{[ordered]@{name=$_.DeviceID;usedGb=Num ($_.Size-$_.FreeSpace) 1073741824;totalGb=Num $_.Size 1073741824}})
 # Optional NVIDIA driver utility. Restrict launch to the resolved executable; never invoke a shell command from configuration.
 $nv=Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
 if($nv){
  try{
   $info=New-Object System.Diagnostics.ProcessStartInfo
   $info.FileName=$nv.Source;$info.Arguments='--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits'
   $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
   $p=New-Object System.Diagnostics.Process;$p.StartInfo=$info;[void]$p.Start();$outTask=$p.StandardOutput.ReadToEndAsync();$errTask=$p.StandardError.ReadToEndAsync()
   if($p.WaitForExit(5000) -and $p.ExitCode -eq 0){$csv=$outTask.Result.Trim().Split([char]10)[0];$parts=$csv -split ',\s*';if($parts.Count -ge 6){$s.gpuName=$parts[0].Trim();$s.gpu=Num $parts[1];$s.gpuTemp=Num $parts[2];$s.gpuMemoryUsedGb=Num $parts[3] 1024;$s.gpuMemoryTotalGb=Num $parts[4] 1024;$s.gpuPowerW=Num $parts[5]}}elseif(-not $p.HasExited){$p.Kill()};$p.Dispose()
  }catch{}
 }
 # Optional LibreHardwareMonitor WMI. No driver or monitoring utility is installed automatically.
 try{
  $sensors=@(Get-CimInstance -Namespace 'root\LibreHardwareMonitor' -ClassName Sensor -OperationTimeoutSec 5 -ErrorAction Stop)
  $cpuTemps=@($sensors|Where-Object{$_.SensorType -eq 'Temperature' -and $_.Identifier -match '/(intelcpu|amdcpu)/' -and $_.Value -gt 0 -and $_.Value -lt 200})
  $package=$cpuTemps|Where-Object{$_.Name -match 'CPU Package|Tctl/Tdie|CPU Core|Core Max'}|Select-Object -First 1
  if(-not $package){$package=$cpuTemps|Select-Object -First 1}
  if($package){$s.cpuTemp=Num $package.Value;$s.cpuTempSource='LibreHardwareMonitor · '+[string]$package.Name}
  $gpuSensors=@($sensors|Where-Object{$_.Identifier -match '/gpu-(nvidia|amd|intel)/0/'});
  if($null -eq $s.gpuTemp){$temp=$gpuSensors|Where-Object{$_.SensorType -eq 'Temperature' -and $_.Name -match 'GPU Core'}|Select-Object -First 1;if($temp){$s.gpuTemp=Num $temp.Value}}
  if($null -eq $s.gpu){$load=$gpuSensors|Where-Object{$_.SensorType -eq 'Load' -and $_.Name -match 'GPU Core'}|Select-Object -First 1;if($load){$s.gpu=Num $load.Value}}
 }catch{}
 if(-not $s.gpuName){$video=@(Cim 'Win32_VideoController'|Where-Object{$null -ne $_})|Select-Object -First 1;if($video){$s.gpuName=$video.Name}}
 return $s
}
$config=$null
if(-not $NoUpload){
 $protectedPath=Join-Path $PSScriptRoot 'config.protected.xml'
 if(Test-Path -LiteralPath $ConfigPath){
  $raw=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
  $config=$raw|ConvertFrom-Json
  $uri=[Uri]$config.endpoint
  if($uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.AbsolutePath -ne '/api/ingest' -or $uri.Query -or $uri.Fragment){throw 'Endpoint must be an HTTPS /api/ingest URL.'}
  if($config.deviceToken -notmatch '^[a-f0-9]{64}$' -or $config.deviceId -notmatch '^[a-f0-9-]{36}$' -or ($config.resultKey -and $config.resultKey -cnotmatch '^[a-f0-9]{128}$')){throw 'Invalid device configuration.'}
  # DPAPI encryption is bound to this Windows user and computer.
  $raw|ConvertTo-SecureString -AsPlainText -Force|Export-Clixml -LiteralPath $protectedPath
  Remove-Item -LiteralPath $ConfigPath
  Log 'Configuration imported and encrypted for this Windows user.'
 }elseif(Test-Path -LiteralPath $protectedPath){
  $secure=Import-Clixml -LiteralPath $protectedPath
  $raw=(New-Object System.Net.NetworkCredential('',$secure)).Password
  $config=$raw|ConvertFrom-Json
 }else{throw 'Place downloaded config.json beside Collect.ps1 and start again.'}
 $uri=[Uri]$config.endpoint
 if($uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.AbsolutePath -ne '/api/ingest' -or $uri.Query -or $uri.Fragment){throw 'Invalid HTTPS endpoint.'}
}
$interval=30;if($config -and $config.intervalSeconds){$interval=[Math]::Max(30,[Math]::Min(3600,[int]$config.intervalSeconds))}
# Lock this folder against duplicate collectors; the scheduled task also ignores parallel instances.
$lock=$null
try{$lock=[IO.File]::Open((Join-Path $PSScriptRoot 'collector.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'Another collector is already running in this folder.'}
try{
 do{
  $started=Get-Date
  try{
   $sample=Read-Sample
   Set-HealthMetrics $sample (Read-HealthSignals)
   $sample['autoMas']=Read-AutoMas
   if($config -and $config.resultKey){Protect-AutoMasResults $sample['autoMas'] $config.resultKey}
   if($NoUpload){$sample|ConvertTo-Json -Depth 5}
   else{
    $headers=@{Authorization=('Bearer '+$config.deviceToken);'X-Device-Id'=$config.deviceId}
    $body=[Text.Encoding]::UTF8.GetBytes(($sample|ConvertTo-Json -Depth 5 -Compress))
    $result=Invoke-RestMethod -Uri $config.endpoint -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $body -TimeoutSec 15 -MaximumRedirection 0
    if($result.ok -ne $true){throw 'Server did not acknowledge the sample.'}
    Log 'Upload OK / 上报成功'
   }
  }catch{
   $safe=Get-SafeHttpFailure $_
   Log ('Collection or upload failed: '+($safe|ConvertTo-Json -Compress)+'. Run Diagnose.ps1 / 请运行诊断连接.cmd。')
   if($Once){throw 'Single collection/upload failed.'}
  }
  if(-not $Once){$wait=[Math]::Max(1,$interval-((Get-Date)-$started).TotalSeconds);Start-Sleep -Seconds ([int][Math]::Ceiling($wait))}
 }while(-not $Once)
}finally{if($lock){$lock.Dispose()}}
