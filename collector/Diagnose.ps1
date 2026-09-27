$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot 'Diagnostics.ps1')
try {
 $plain=Join-Path $PSScriptRoot 'config.json';$protected=Join-Path $PSScriptRoot 'config.protected.xml'
 if(Test-Path -LiteralPath $plain){$c=Get-Content -LiteralPath $plain -Raw -Encoding UTF8|ConvertFrom-Json}
 elseif(Test-Path -LiteralPath $protected){$secure=Import-Clixml -LiteralPath $protected;$c=((New-Object Net.NetworkCredential('',$secure)).Password)|ConvertFrom-Json}
 else{throw 'CONFIG_NOT_FOUND'}
 $uri=[Uri]$c.endpoint
 if($uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.AbsolutePath -ne '/api/ingest' -or $uri.Query -or $uri.Fragment){throw 'INVALID_ENDPOINT'}
 Write-Host 'Connection diagnosis / 连接诊断：不采集、不上传硬件数据，不修改配置。'
 Write-Host ('网站：'+$uri.Host)
 Write-Host ('直连 ECS 模式，无需平台网关凭据。')
 $headers=@{'X-Device-Id'='00000000-0000-4000-8000-000000000000';Authorization=('Bearer '+('0'*64))}
 try{Invoke-RestMethod -Uri $uri.AbsoluteUri -Method Post -Headers $headers -ContentType 'application/json' -Body '{}' -TimeoutSec 20 -MaximumRedirection 0 | Out-Null;$result=[ordered]@{http=200;cause='UNEXPECTED_RESPONSE';server='';contentType='';requestId=''}}
 catch{$result=Get-SafeHttpFailure $_}
 $output=($result|ConvertTo-Json -Compress)
 Write-Host $output
 if($result.cause -eq 'APP_REACHED_DEVICE_KEY_REJECTED'){Write-Host '连接诊断通过：已到达采集接口。这里的 401 是故意使用无效测试设备密钥产生的，不代表你的设备密钥错误。'}
 elseif($result.cause -eq 'SITE_LOGIN_GATEWAY'){Write-Host '请求被网站登录入口拒绝：请检查是否使用了网站当前生成的配置。'}
 elseif($result.cause -eq 'REGION_RESTRICTION'){Write-Host '响应提示地区访问限制，需更换可从该地区访问的数据接收入口。'}
 elseif($result.http -eq 403){Write-Host '请求在接口之前被拒绝；仅凭 403 不能确定是否为地区限制。请把上面的诊断结果反馈给维护者。'}
 else{Write-Host '请把上面的诊断结果反馈给维护者。无需发送 config 文件。'}
 @((Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),('host='+$uri.Host),$output) | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'diagnostic.txt') -Encoding UTF8
}catch{Write-Host '诊断无法读取配置。请把诊断文件放入原采集目录，并用运行采集程序的同一 Windows 用户运行。不要把配置文件发给他人。';exit 1}
