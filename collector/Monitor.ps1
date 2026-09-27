param([switch]$Tray,[switch]$SmokeTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$script:child=$null
$script:quitting=$false
$script:uiLock=$null
try{$script:uiLock=[IO.File]::Open((Join-Path $PSScriptRoot 'monitor-ui.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{[Windows.Forms.MessageBox]::Show('监控程序已运行，请在系统托盘中找到蓝色信息图标。','远程电脑监控')|Out-Null;exit}
$form=New-Object Windows.Forms.Form
$form.Text='远程电脑监控 · 采集端'
$form.ClientSize=New-Object Drawing.Size(560,360)
$form.MinimumSize=New-Object Drawing.Size(576,399)
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$form.Icon=[Drawing.SystemIcons]::Information
$title=New-Object Windows.Forms.Label
$title.Text='远程电脑监控'
$title.Font=New-Object Drawing.Font('Microsoft YaHei UI',17,[Drawing.FontStyle]::Bold)
$title.SetBounds(24,20,500,40)
$form.Controls.Add($title)
$status=New-Object Windows.Forms.Label
$status.Text='尚未开始采集'
$status.SetBounds(26,69,510,30)
$form.Controls.Add($status)
$note=New-Object Windows.Forms.Label
$note.Text='每 30 秒上报一次。关闭窗口会收到托盘，退出时停止采集。'
$note.SetBounds(26,103,510,44)
$form.Controls.Add($note)
function Button([string]$Text,[int]$X,[int]$Y,[int]$Width=150){
 $b=New-Object Windows.Forms.Button;$b.Text=$Text;$b.SetBounds($X,$Y,$Width,36);$form.Controls.Add($b);return $b
}
$start=Button '开始采集' 24 154
$stop=Button '停止采集' 204 154
$hide=Button '最小化到托盘' 384 154
$import=Button '导入接入配置' 24 206
$logs=Button '查看日志' 204 206
$web=Button '打开监控网站' 384 206
$auto=New-Object Windows.Forms.CheckBox
$auto.Text='登录 Windows 后自动启动并收到托盘'
$auto.SetBounds(26,263,490,30)
$auto.Checked=Test-Path -LiteralPath (Join-Path ([Environment]::GetFolderPath('Startup')) 'RemotePcMonitor-Tray.lnk')
$form.Controls.Add($auto)
$hint=New-Object Windows.Forms.Label
$hint.Text='查看端只需浏览器；退出请使用托盘右键菜单。'
$hint.ForeColor=[Drawing.Color]::DimGray
$hint.SetBounds(26,309,500,30)
$form.Controls.Add($hint)
$trayIcon=New-Object Windows.Forms.NotifyIcon
$trayIcon.Icon=$form.Icon;$trayIcon.Text='远程电脑监控';$trayIcon.Visible=$true
$menu=New-Object Windows.Forms.ContextMenuStrip
$showItem=$menu.Items.Add('打开主窗口')
$startItem=$menu.Items.Add('开始采集')
$stopItem=$menu.Items.Add('停止采集')
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$exitItem=$menu.Items.Add('退出并停止采集')
$trayIcon.ContextMenuStrip=$menu
function Show-Monitor{$form.Show();$form.WindowState='Normal';$form.ShowInTaskbar=$true;$form.Activate()}
function Hide-Monitor{$form.Hide();$form.ShowInTaskbar=$false}
function Stop-Collector {
 if($script:child){try{if(-not $script:child.HasExited){$script:child.Kill();[void]$script:child.WaitForExit(3000)}}catch{}; $script:child.Dispose();$script:child=$null}
 $status.Text='采集已停止';$trayIcon.Text='远程电脑监控 · 已停止'
}
function Start-Collector {
 try{
  if($script:child -and -not $script:child.HasExited){return}
  if(-not ((Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.json')) -or (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.protected.xml')))){throw '请先点击“导入接入配置”，选择网站下载的 config.json。'}
  $check=$null
  try{$check=[IO.File]::Open((Join-Path $PSScriptRoot 'collector.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw '此文件夹已有采集进程。请先关闭旧采集窗口或停用旧版自动启动任务。'}finally{if($check){$check.Dispose()}}
  if($script:child){$script:child.Dispose()}
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=Join-Path $PSHOME 'powershell.exe'
  $psi.Arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Collect.ps1')+'"'
  $psi.WorkingDirectory=$PSScriptRoot;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
  $script:child=[Diagnostics.Process]::Start($psi)
  $status.Text='正在采集，等待第一次上报…'
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'无法启动采集')|Out-Null}
}
$start.Add_Click({Start-Collector});$startItem.Add_Click({Start-Collector})
$stop.Add_Click({Stop-Collector});$stopItem.Add_Click({Stop-Collector})
$hide.Add_Click({Hide-Monitor});$showItem.Add_Click({Show-Monitor});$trayIcon.Add_DoubleClick({Show-Monitor})
$exitItem.Add_Click({$script:quitting=$true;$form.Close()})
$form.Add_Resize({if($form.WindowState -eq 'Minimized'){Hide-Monitor}})
$form.Add_FormClosing({param($sender,$e) if(-not $script:quitting -and $e.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing){$e.Cancel=$true;Hide-Monitor}})
$logs.Add_Click({$p=Join-Path $PSScriptRoot 'collector.log';if(Test-Path -LiteralPath $p){Start-Process notepad.exe -ArgumentList ('"'+$p+'"')}else{[Windows.Forms.MessageBox]::Show('尚无采集日志。','远程电脑监控')|Out-Null}})
$web.Add_Click({
 try {
  $file=Join-Path $PSScriptRoot 'config.protected.xml'
  if(Test-Path -LiteralPath $file){$secure=Import-Clixml -LiteralPath $file;$raw=(New-Object Net.NetworkCredential('',$secure)).Password}
  else{$raw=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'config.json'),[Text.Encoding]::UTF8)}
  $uri=[Uri](($raw|ConvertFrom-Json).endpoint)
  if($uri.Scheme -ne 'https' -or $uri.UserInfo){throw 'Invalid endpoint'}
  Start-Process ($uri.GetLeftPart([UriPartial]::Authority)+'/')
 }catch{[Windows.Forms.MessageBox]::Show('请先导入有效接入配置。','远程电脑监控')|Out-Null}
})
$import.Add_Click({
 $dialog=New-Object Windows.Forms.OpenFileDialog;$dialog.Filter='接入配置 (config.json)|*.json';$dialog.Title='选择从监控网站下载的 config.json'
 try{
  if($dialog.ShowDialog() -ne 'OK'){return}
  $raw=[IO.File]::ReadAllText($dialog.FileName,[Text.Encoding]::UTF8)
  $c=$raw|ConvertFrom-Json
  $uri=[Uri]$c.endpoint
  if(-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.AbsolutePath -ne '/api/ingest' -or $uri.Query -or $uri.Fragment -or $c.deviceToken -notmatch '^[a-f0-9]{64}$' -or $c.deviceId -notmatch '^[a-f0-9-]{36}$'){throw '配置不是此监控服务器生成的有效接入配置。'}
  Stop-Collector
  $raw|ConvertTo-SecureString -AsPlainText -Force|Export-Clixml -LiteralPath (Join-Path $PSScriptRoot 'config.protected.xml')
  # A stale local plaintext config would otherwise override the imported secret.
  $plain=Join-Path $PSScriptRoot 'config.json'
  if(Test-Path -LiteralPath $plain){Remove-Item -LiteralPath $plain}
  $status.Text='配置已加密保存，正在启动…'
  Start-Collector
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'导入失败')|Out-Null}finally{$dialog.Dispose()}
})
$auto.Add_CheckedChanged({
 try{
  $link=Join-Path ([Environment]::GetFolderPath('Startup')) 'RemotePcMonitor-Tray.lnk'
  if($auto.Checked){
   $shell=New-Object -ComObject WScript.Shell;$shortcut=$shell.CreateShortcut($link)
   $shortcut.TargetPath=Join-Path $env:WINDIR 'System32\wscript.exe'
   $shortcut.Arguments='"'+(Join-Path $PSScriptRoot '启动监控.vbs')+'" /tray'
   $shortcut.WorkingDirectory=$PSScriptRoot;$shortcut.Description='远程电脑监控托盘采集端';$shortcut.Save()
  }elseif(Test-Path -LiteralPath $link){Remove-Item -LiteralPath $link}
 }catch{[Windows.Forms.MessageBox]::Show('自动启动设置失败：'+$_.Exception.Message,'远程电脑监控')|Out-Null}
})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=2000
$timer.Add_Tick({
 if($script:child){
  if($script:child.HasExited){$status.Text='采集进程已退出，请查看日志后重新启动。';$trayIcon.Text='远程电脑监控 · 采集已退出'}
  else{
   $logFile=Get-Item -LiteralPath (Join-Path $PSScriptRoot 'collector.log') -ErrorAction SilentlyContinue
   $last=''
   if($logFile -and $logFile.LastWriteTime -ge $script:child.StartTime){$last=Get-Content -LiteralPath $logFile.FullName -Tail 1 -ErrorAction SilentlyContinue}
   if($last -match 'Upload OK'){$status.Text='后台采集中 · '+$last.Substring(0,[Math]::Min(21,$last.Length))+' 上报成功';$trayIcon.Text='远程电脑监控 · 上报成功'}
   elseif($last -match 'failed'){$status.Text='上报暂未成功，下一周期自动重试；详情见日志。';$trayIcon.Text='远程电脑监控 · 等待重试'}
  }
 }
 $running=$script:child -and -not $script:child.HasExited
 $start.Enabled=-not $running;$stop.Enabled=[bool]$running
})
$form.Add_Shown({
 if($SmokeTest){$bmp=New-Object Drawing.Bitmap($form.Width,$form.Height);$form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bmp.Save((Join-Path $PSScriptRoot 'preview.png'));$bmp.Dispose();$script:quitting=$true;$form.Close();return}
 if((Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.json')) -or (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.protected.xml'))){Start-Collector}
 if($Tray){Hide-Monitor}
})
try{$timer.Start();[Windows.Forms.Application]::Run($form)}finally{Stop-Collector;$timer.Stop();$timer.Dispose();$trayIcon.Visible=$false;$trayIcon.Dispose();$menu.Dispose();$form.Dispose();if($script:uiLock){$script:uiLock.Dispose()}}
