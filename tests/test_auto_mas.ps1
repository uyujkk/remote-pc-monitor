. (Join-Path $PSScriptRoot '../collector/AutoMas.ps1')
function Read-LocalJson([string]$Path,[int]$Port,[string]$Body='') {
 switch($Path) {
  '/api/core/health' {return [pscustomobject]@{ready=$true;backgroundStatus='ready';version='5.4.0'}}
  '/api/history/search' {return [pscustomobject]@{code=200;data=[pscustomobject]@{
   '2026-09-28'=[pscustomobject]@{privateUser=[pscustomobject]@{index=@(
    [pscustomobject]@{date='2026-09-28 12:00:00';status='ERROR';result='password=hidden C:\Users\Private\secret.txt'},
    [pscustomobject]@{date='2026-09-28 13:00:00';status='DONE';result='Task completed'}
   )}}
  }}}
  '/api/dispatch/runtime-snapshot' {throw 'Not supported by v5.4.0'}
 }
}
$sample=Read-AutoMas
if($sample.state -ne 'limited' -or $sample.resultCounts.done -ne 1 -or $sample.resultCounts.error -ne 1){throw 'Incorrect history aggregation'}
if($sample.recentResults.Count -ne 2 -or $sample.recentResults[0].at -ne '2026-09-28 13:00:00'){throw 'Incorrect result ordering'}
if($sample.recentResults[1].message -match 'hidden|Private|secret.txt' -or $sample.recentResults[1].message -notmatch '\[redacted\]'){throw 'Result redaction failed'}
if(-not $sample.historyUpdatedAt){throw 'Missing history timestamp'}
Write-Output 'AUTO-MAS collector history test OK'
