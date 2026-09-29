# Read-only health signals. The score describes current resource pressure, not a diagnosis.
$script:healthFetched=[datetime]::MinValue
$script:healthSignals=@{stabilityIndex=$null;wheaEvents24h=$null;memoryEvents24h=$null;wheaEventsCapped=$false}
function Read-HealthSignals {
 if(((Get-Date)-$script:healthFetched).TotalMinutes -lt 10){return $script:healthSignals}
 $script:healthFetched=Get-Date
 $signals=@{stabilityIndex=$null;wheaEvents24h=$null;memoryEvents24h=$null;wheaEventsCapped=$false}
 try {
  $record=Get-CimInstance -ClassName Win32_ReliabilityStabilityMetrics -OperationTimeoutSec 8 -ErrorAction Stop | Sort-Object TimeGenerated -Descending | Select-Object -First 1
  if($record -and $null -ne $record.SystemStabilityIndex){
   $value=[double]$record.SystemStabilityIndex
   if($value -ge 1 -and $value -le 10){$signals.stabilityIndex=[Math]::Round($value,2)}
  }
 }catch{}
 try {
  # Check access separately: Get-WinEvent throws when there are simply no matching events.
  $log=Get-WinEvent -ListLog System -ErrorAction Stop
  if($log.IsEnabled){
   try {$events=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WHEA-Logger';StartTime=(Get-Date).AddHours(-24)} -MaxEvents 1001 -ErrorAction Stop)}
   catch {if($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*'){$events=@()}else{throw}}
   $signals.wheaEventsCapped=$events.Count -gt 1000
   $signals.wheaEvents24h=[Math]::Min($events.Count,1000)
   $memory=0
   foreach($event in ($events|Select-Object -First 1000)){
    # Only count events explicitly classified as memory in their event data/message.
    $xml=$event.ToXml()
    if($xml -match '(?i)<Data Name="(?:Component|ErrorType)">(?:Memory|Physical Memory)</Data>' -or $event.Message -match '(?i)(?:Component|组件)\s*[:：]\s*(?:Memory|内存)'){$memory++}
   }
   $signals.memoryEvents24h=$memory
  }
 }catch{}
 $script:healthSignals=$signals
 return $signals
}
function Set-HealthMetrics($sample,$signals) {
 $sample['stabilityIndex']=$signals.stabilityIndex
 $sample['wheaEvents24h']=$signals.wheaEvents24h
 $sample['memoryEvents24h']=$signals.memoryEvents24h
 $sample['wheaEventsCapped']=$signals.wheaEventsCapped
 $weights=@{cpu=15;memory=25;disk=20;cpuTemp=15;gpuTemp=10;whea=15}
 $scores=@{}
 if($null -ne $sample.cpu){$scores.cpu=[Math]::Max(0,100-([Math]::Max(0,$sample.cpu-70)*2.5))}
 if($null -ne $sample.memory){$scores.memory=[Math]::Max(0,100-([Math]::Max(0,$sample.memory-70)*3))}
 $diskUse=@($sample.disks|Where-Object{$_.totalGb -gt 0}|ForEach-Object{100*$_.usedGb/$_.totalGb})
 if($diskUse.Count){$scores.disk=[Math]::Max(0,100-([Math]::Max(0,($diskUse|Measure-Object -Maximum).Maximum-80)*4))}
 if($null -ne $sample.cpuTemp){$scores.cpuTemp=[Math]::Max(0,100-([Math]::Max(0,$sample.cpuTemp-75)*5))}
 if($null -ne $sample.gpuTemp){$scores.gpuTemp=[Math]::Max(0,100-([Math]::Max(0,$sample.gpuTemp-80)*5))}
 if($null -ne $signals.wheaEvents24h){$scores.whea=[Math]::Max(0,100-$signals.wheaEvents24h*20)}
 $total=0;$earned=0
 foreach($key in $scores.Keys){$total+=$weights[$key];$earned+=$weights[$key]*$scores[$key]}
 $sample['healthScore']=if($total -ge 40){[Math]::Round($earned/$total,1)}else{$null}
 $sample['healthCoverage']=$total
}
