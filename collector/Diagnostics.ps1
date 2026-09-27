function Get-SafeHttpFailure($Failure) {
 $r=$Failure.Exception.Response
 $status=0;$server='';$contentType='';$ray='';$body=''
 if($r){try{$status=[int]$r.StatusCode;$server=[string]$r.Headers['Server'];$contentType=[string]$r.Headers['Content-Type'];$ray=[string]$r.Headers['CF-Ray']}catch{}}
 if($Failure.ErrorDetails){$body=[string]$Failure.ErrorDetails.Message}
 if(-not $body -and $r){try{$reader=New-Object IO.StreamReader($r.GetResponseStream());$buffer=New-Object char[] 16384;$count=$reader.Read($buffer,0,$buffer.Length);$body=New-Object string($buffer,0,$count);$reader.Dispose()}catch{}}
 $cause='HTTP_REJECTED'
 if($body -match 'unsupported_country|unsupported.country|unsupported.region|country.*not.supported|not.available.in.your.(country|region)|地区.*不支持'){$cause='REGION_RESTRICTION'}
 elseif($body -match 'cf-chl-|challenge-platform|Just a moment|Attention Required'){$cause='EDGE_BROWSER_CHALLENGE'}
 elseif($body -match 'Invalid device credential' -and $contentType -match 'json'){$cause='APP_REACHED_DEVICE_KEY_REJECTED'}
 elseif($body -match 'Invalid metrics' -and $contentType -match 'json'){$cause='APP_REACHED_INVALID_METRICS'}
 elseif($body -match '_sites/dispatch-assets|Sign in with ChatGPT|Sign in to view'){$cause='SITE_LOGIN_GATEWAY'}
 elseif($status -eq 0){$cause='NETWORK_DNS_TLS_OR_TIMEOUT'}
 elseif($status -eq 403 -and $contentType -match 'html'){$cause='UPSTREAM_HTML_403'}
 elseif($status -eq 401){$cause='AUTHENTICATION_REJECTED'}
 elseif($status -eq 429){$cause='RATE_LIMITED'}
 # Only allow bounded, non-secret metadata into logs. Never output response bodies or request headers.
 $server=$server -replace '[^a-zA-Z0-9._ -]','';$ray=$ray -replace '[^a-zA-Z0-9-]','';$contentType=$contentType -replace '[^a-zA-Z0-9/;=._ -]',''
 return [ordered]@{http=$status;cause=$cause;server=$server.Substring(0,[Math]::Min(60,$server.Length));contentType=$contentType.Substring(0,[Math]::Min(80,$contentType.Length));requestId=$ray.Substring(0,[Math]::Min(80,$ray.Length))}
}
