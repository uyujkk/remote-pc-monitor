# Optional, read-only AUTO-MAS integration. Only the loopback API is contacted.
function Read-LocalJson([string]$Path,[int]$Port,[string]$Body='') {
 $request=[Net.HttpWebRequest]::Create("http://127.0.0.1:$Port$Path")
 $request.Method=if($Body){'POST'}else{'GET'}
 $request.Timeout=2000;$request.ReadWriteTimeout=2000
 $request.Proxy=$null
 if($Body){
  $bytes=[Text.Encoding]::UTF8.GetBytes($Body)
  $request.ContentType='application/json';$request.ContentLength=$bytes.Length
  $upload=$request.GetRequestStream()
  try{$upload.Write($bytes,0,$bytes.Length)}finally{$upload.Dispose()}
 }
 $response=$request.GetResponse()
 try {
  $stream=$response.GetResponseStream()
  $buffer=New-Object byte[] 8192
  $memory=New-Object IO.MemoryStream
  try {
   while(($count=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
    if($memory.Length+$count -gt 1048576){throw 'AUTO-MAS response exceeds 1 MiB'}
    $memory.Write($buffer,0,$count)
   }
   return [Text.Encoding]::UTF8.GetString($memory.ToArray())|ConvertFrom-Json
  }finally{$memory.Dispose()}
 }finally{$response.Dispose()}
}
$script:autoMasHistoryFetched=[datetime]::MinValue
$script:autoMasHistory=@{lastResultAt=$null;lastResult=$null}
function Read-AutoMas {
 $port=36163
 $portFile=Join-Path $PSScriptRoot 'auto-mas-port.txt'
 if(Test-Path -LiteralPath $portFile){
  $raw=(Get-Content -LiteralPath $portFile -Raw -Encoding UTF8).Trim()
  if($raw -notmatch '^\d{4,5}$' -or [int]$raw -lt 1024 -or [int]$raw -gt 65535){return @{state='unavailable';version=$null;activeTasks=0;scheduledCount=0;tasks=@();lastResultAt=$null;lastResult=$null}}
  $port=[int]$raw
 }
 $summary=@{state='unavailable';version=$null;activeTasks=0;scheduledCount=0;tasks=@();lastResultAt=$null;lastResult=$null}
 $healthy=$false
 try {
  $health=Read-LocalJson '/api/core/health' $port
  if($health -and $health.ready -eq $true){$healthy=$true;$summary.state='limited'}
  if($health -and $health.version){$summary.version=([string]$health.version).Substring(0,[Math]::Min(40,([string]$health.version).Length))}
  if($health -and ($health.ready -ne $true -or $health.backgroundStatus -notin @('ready','completed','success'))){$summary.state='starting'}
 }catch{}
 if($healthy -and ((Get-Date)-$script:autoMasHistoryFetched).TotalSeconds -ge 300){
  $script:autoMasHistoryFetched=Get-Date
  try {
   $end=Get-Date
   $query=@{mode='DAILY';start_date=$end.AddDays(-7).ToString('yyyy-MM-dd');end_date=$end.ToString('yyyy-MM-dd')}|ConvertTo-Json -Compress
   $history=Read-LocalJson '/api/history/search' $port $query
   $latest=$null
   foreach($day in $history.data.PSObject.Properties){foreach($user in $day.Value.PSObject.Properties){foreach($entry in $user.Value.index){
    if($entry.status -in @('DONE','ERROR') -and [string]$entry.date -match '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$' -and ($null -eq $latest -or [string]$entry.date -gt $latest.date)){$latest=$entry}
   }}}
   $script:autoMasHistory=@{lastResultAt=$null;lastResult=$null}
   if($latest){$script:autoMasHistory=@{lastResultAt=[string]$latest.date;lastResult=[string]$latest.status}}
  }catch{}
 }
 if($healthy){$summary.lastResultAt=$script:autoMasHistory.lastResultAt;$summary.lastResult=$script:autoMasHistory.lastResult}
 try {
  $snapshot=Read-LocalJson '/api/dispatch/runtime-snapshot' $port
  if($null -eq $snapshot.tasks -or $null -eq $snapshot.scheduledScripts){return $summary}
  $summary.state='ready'
  $summary.activeTasks=@($snapshot.tasks).Count
  $summary.scheduledCount=@($snapshot.scheduledScripts).Count
  $summary.tasks=@($snapshot.tasks|Select-Object -First 8|ForEach-Object {
   $task=$_
   $scripts=@($task.task_info|Select-Object -First 6|ForEach-Object {
    $item=$_
    @{name=([string]$item.name).Substring(0,[Math]::Min(80,([string]$item.name).Length));status=([string]$item.status).Substring(0,[Math]::Min(40,([string]$item.status).Length))}
   })
   $mode=[string]$task.mode;if($mode -notin @('AutoProxy','ScriptConfig','Update')){$mode='AutoProxy'}
   @{mode=$mode;stopping=($task.stopping -eq $true);scripts=$scripts}
  })
 }catch [Net.WebException] {
  if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404 -and -not $healthy){$summary.state='unsupported'}
 }catch{}
 return $summary
}
