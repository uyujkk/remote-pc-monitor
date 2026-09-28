param([switch]$Tray,[switch]$SmokeTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$script:child=$null
$script:quitting=$false
$script:uiLock=$null
$script:languagePath=Join-Path $PSScriptRoot 'ui-language.txt'
$script:language=if((Test-Path -LiteralPath $script:languagePath) -and (Get-Content -LiteralPath $script:languagePath -Raw).Trim() -eq 'en'){'en'}else{'zh'}
function T([string]$Chinese,[string]$English){if($script:language -eq 'en'){return $English};return $Chinese}
try{$script:uiLock=[IO.File]::Open((Join-Path $PSScriptRoot 'monitor-ui.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{[Windows.Forms.MessageBox]::Show((T '监控程序已运行，请在系统托盘中找到蓝色监控图标。' 'Monitor is already running. Find its blue icon in the system tray.'),'Remote PC Monitor')|Out-Null;exit}
# Draw a small monitor and pulse rather than using the generic Windows information icon.
$script:iconBitmap=New-Object Drawing.Bitmap(32,32)
$iconGraphics=[Drawing.Graphics]::FromImage($script:iconBitmap)
$iconGraphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$iconGraphics.Clear([Drawing.Color]::Transparent)
$blueBrush=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(52,133,245))
$whitePen=New-Object Drawing.Pen([Drawing.Color]::White,2.3)
$iconGraphics.FillRectangle($blueBrush,1,1,30,30)
$iconGraphics.DrawRectangle($whitePen,5,7,22,17)
$pulse=[Drawing.Point[]]@((New-Object Drawing.Point(8,16)),(New-Object Drawing.Point(12,16)),(New-Object Drawing.Point(15,11)),(New-Object Drawing.Point(18,20)),(New-Object Drawing.Point(21,16)),(New-Object Drawing.Point(25,16)))
$iconGraphics.DrawLines($whitePen,$pulse)
$iconGraphics.Dispose();$blueBrush.Dispose();$whitePen.Dispose()
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class MonitorIconNative { [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle); }'
$iconHandle=$script:iconBitmap.GetHicon()
$script:monitorIcon=([Drawing.Icon]::FromHandle($iconHandle)).Clone()
[void][MonitorIconNative]::DestroyIcon($iconHandle)
$form=New-Object Windows.Forms.Form
$form.Text=T '远程电脑监控 · 采集端' 'Remote PC Monitor · Collector'
$form.ClientSize=New-Object Drawing.Size(620,410)
$form.MinimumSize=New-Object Drawing.Size(636,449)
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$form.Icon=$script:monitorIcon
$form.BackColor=[Drawing.Color]::FromArgb(17,26,39)
$form.ForeColor=[Drawing.Color]::FromArgb(236,243,253)
$title=New-Object Windows.Forms.Label
$title.Text=T '远程电脑监控' 'Remote PC Monitor'
$title.Font=New-Object Drawing.Font('Microsoft YaHei UI',19,[Drawing.FontStyle]::Bold)
$title.SetBounds(26,21,430,43)
$form.Controls.Add($title)
$languageSelect=New-Object Windows.Forms.ComboBox
$languageSelect.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDownList
$languageSelect.Items.AddRange([object[]]@('简体中文','English'))
$languageSelect.SelectedIndex=if($script:language -eq 'en'){1}else{0}
$languageSelect.SetBounds(490,27,104,31)
$languageSelect.BackColor=[Drawing.Color]::FromArgb(33,48,68)
$languageSelect.ForeColor=$form.ForeColor
$form.Controls.Add($languageSelect)
$statusCard=New-Object Windows.Forms.Panel
$statusCard.SetBounds(24,78,572,83)
$statusCard.BackColor=[Drawing.Color]::FromArgb(27,42,61)
$form.Controls.Add($statusCard)
$status=New-Object Windows.Forms.Label
$status.Text=T '尚未开始采集' 'Collection has not started'
$status.Font=New-Object Drawing.Font('Microsoft YaHei UI',12,[Drawing.FontStyle]::Bold)
$status.ForeColor=[Drawing.Color]::FromArgb(110,222,183)
$status.SetBounds(18,13,535,31)
$statusCard.Controls.Add($status)
$note=New-Object Windows.Forms.Label
$note.Text=T '每 30 秒上报一次。关闭窗口将最小化到托盘。' 'Reports every 30 seconds. Closing minimizes to the tray.'
$note.ForeColor=[Drawing.Color]::FromArgb(153,174,198)
$note.SetBounds(18,48,535,27)
$statusCard.Controls.Add($note)
function Button([string]$Text,[int]$X,[int]$Y,[int]$Width=150){
 $b=New-Object Windows.Forms.Button;$b.Text=$Text;$b.SetBounds($X,$Y,$Width,40)
 $b.FlatStyle=[Windows.Forms.FlatStyle]::Flat;$b.FlatAppearance.BorderSize=1
 $b.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(63,84,110)
 $b.BackColor=[Drawing.Color]::FromArgb(34,50,71);$b.ForeColor=$form.ForeColor
 $form.Controls.Add($b);return $b
}
$start=Button (T '开始采集' 'Start collection') 24 184 180
$stop=Button (T '停止采集' 'Stop collection') 220 184 180
$hide=Button (T '最小化到托盘' 'Minimize to tray') 416 184 180
$import=Button (T '导入接入配置' 'Import connection') 24 239 180
$logs=Button (T '查看日志' 'View log') 220 239 180
$web=Button (T '打开监控网站' 'Open dashboard') 416 239 180
$start.BackColor=[Drawing.Color]::FromArgb(45,106,209)
$start.FlatAppearance.BorderSize=0
$auto=New-Object Windows.Forms.CheckBox
$auto.Text=T '登录 Windows 后自动启动并进入托盘' 'Start in tray after Windows sign-in'
$auto.SetBounds(28,305,540,30)
$auto.Checked=Test-Path -LiteralPath (Join-Path ([Environment]::GetFolderPath('Startup')) 'RemotePcMonitor-Tray.lnk')
$form.Controls.Add($auto)
$hint=New-Object Windows.Forms.Label
$hint.Text=T '查看端只需浏览器；退出请使用托盘右键菜单。' 'View from any browser. Right-click the tray icon to exit.'
$hint.ForeColor=[Drawing.Color]::FromArgb(143,163,188)
$hint.SetBounds(28,356,560,30)
$form.Controls.Add($hint)
$trayIcon=New-Object Windows.Forms.NotifyIcon
$trayIcon.Icon=$script:monitorIcon;$trayIcon.Text=T '远程电脑监控' 'Remote PC Monitor';$trayIcon.Visible=$true
$menu=New-Object Windows.Forms.ContextMenuStrip
$showItem=$menu.Items.Add((T '打开主窗口' 'Open window'))
$startItem=$menu.Items.Add((T '开始采集' 'Start collection'))
$stopItem=$menu.Items.Add((T '停止采集' 'Stop collection'))
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$exitItem=$menu.Items.Add((T '退出并停止采集' 'Exit and stop collection'))
$trayIcon.ContextMenuStrip=$menu
function Update-Language {
 $form.Text=T '远程电脑监控 · 采集端' 'Remote PC Monitor · Collector'
 $title.Text=T '远程电脑监控' 'Remote PC Monitor'
 $note.Text=T '每 30 秒上报一次。关闭窗口将最小化到托盘。' 'Reports every 30 seconds. Closing minimizes to the tray.'
 $start.Text=T '开始采集' 'Start collection';$stop.Text=T '停止采集' 'Stop collection';$hide.Text=T '最小化到托盘' 'Minimize to tray'
 $import.Text=T '导入接入配置' 'Import connection';$logs.Text=T '查看日志' 'View log';$web.Text=T '打开监控网站' 'Open dashboard'
 $auto.Text=T '登录 Windows 后自动启动并进入托盘' 'Start in tray after Windows sign-in'
 $hint.Text=T '查看端只需浏览器；退出请使用托盘右键菜单。' 'View from any browser. Right-click the tray icon to exit.'
 $showItem.Text=T '打开主窗口' 'Open window';$startItem.Text=$start.Text;$stopItem.Text=$stop.Text;$exitItem.Text=T '退出并停止采集' 'Exit and stop collection'
 $status.Text=T '状态更新中…' 'Updating status…'
}
$languageSelect.Add_SelectedIndexChanged({
 $script:language=if($languageSelect.SelectedIndex -eq 1){'en'}else{'zh'}
 try{[IO.File]::WriteAllText($script:languagePath,$script:language)}catch{}
 Update-Language
})
function Show-Monitor{$form.Show();$form.WindowState='Normal';$form.ShowInTaskbar=$true;$form.Activate()}
function Hide-Monitor{$form.Hide();$form.ShowInTaskbar=$false}
function Stop-Collector {
 if($script:child){try{if(-not $script:child.HasExited){$script:child.Kill();[void]$script:child.WaitForExit(3000)}}catch{}; $script:child.Dispose();$script:child=$null}
 $status.Text=T '采集已停止' 'Collection stopped';$trayIcon.Text=T '远程电脑监控 · 已停止' 'Remote PC Monitor · Stopped'
}
function Start-Collector {
 try{
  if($script:child -and -not $script:child.HasExited){return}
  if(-not ((Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.json')) -or (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'config.protected.xml')))){throw (T '请先点击“导入接入配置”，选择网站下载的 config.json。' 'Import config.json downloaded from your own dashboard first.')}
  $check=$null
  try{$check=[IO.File]::Open((Join-Path $PSScriptRoot 'collector.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw (T '此文件夹已有采集进程。请先关闭旧采集窗口或停用旧版自动启动任务。' 'A collector is already running from this folder. Stop the old instance first.')}finally{if($check){$check.Dispose()}}
  if($script:child){$script:child.Dispose()}
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=Join-Path $PSHOME 'powershell.exe'
  $psi.Arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Collect.ps1')+'"'
  $psi.WorkingDirectory=$PSScriptRoot;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
  $script:child=[Diagnostics.Process]::Start($psi)
  $status.Text=T '正在采集，等待第一次上报…' 'Collecting; waiting for the first upload…'
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,(T '无法启动采集' 'Could not start collection'))|Out-Null}
}
$start.Add_Click({Start-Collector});$startItem.Add_Click({Start-Collector})
$stop.Add_Click({Stop-Collector});$stopItem.Add_Click({Stop-Collector})
$hide.Add_Click({Hide-Monitor});$showItem.Add_Click({Show-Monitor});$trayIcon.Add_DoubleClick({Show-Monitor})
$exitItem.Add_Click({$script:quitting=$true;$form.Close()})
$form.Add_Resize({if($form.WindowState -eq 'Minimized'){Hide-Monitor}})
$form.Add_FormClosing({param($sender,$e) if(-not $script:quitting -and $e.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing){$e.Cancel=$true;Hide-Monitor}})
$logs.Add_Click({$p=Join-Path $PSScriptRoot 'collector.log';if(Test-Path -LiteralPath $p){Start-Process notepad.exe -ArgumentList ('"'+$p+'"')}else{[Windows.Forms.MessageBox]::Show((T '尚无采集日志。' 'No collection log is available yet.'),'Remote PC Monitor')|Out-Null}})
$web.Add_Click({
 try {
  $file=Join-Path $PSScriptRoot 'config.protected.xml'
  if(Test-Path -LiteralPath $file){$secure=Import-Clixml -LiteralPath $file;$raw=(New-Object Net.NetworkCredential('',$secure)).Password}
  else{$raw=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'config.json'),[Text.Encoding]::UTF8)}
  $uri=[Uri](($raw|ConvertFrom-Json).endpoint)
  if($uri.Scheme -ne 'https' -or $uri.UserInfo){throw 'Invalid endpoint'}
  Start-Process ($uri.GetLeftPart([UriPartial]::Authority)+'/')
 }catch{[Windows.Forms.MessageBox]::Show((T '请先导入有效接入配置。' 'Import a valid connection configuration first.'),'Remote PC Monitor')|Out-Null}
})
$import.Add_Click({
 $dialog=New-Object Windows.Forms.OpenFileDialog;$dialog.Filter=T '接入配置 (config.json)|*.json' 'Connection configuration (config.json)|*.json';$dialog.Title=T '选择从监控网站下载的 config.json' 'Select config.json downloaded from your dashboard'
 try{
  if($dialog.ShowDialog() -ne 'OK'){return}
  $raw=[IO.File]::ReadAllText($dialog.FileName,[Text.Encoding]::UTF8)
  $c=$raw|ConvertFrom-Json
  $uri=[Uri]$c.endpoint
  if(-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.AbsolutePath -ne '/api/ingest' -or $uri.Query -or $uri.Fragment -or $c.deviceToken -notmatch '^[a-f0-9]{64}$' -or $c.deviceId -notmatch '^[a-f0-9-]{36}$'){throw (T '配置不是有效接入配置。' 'The selected file is not a valid connection configuration.')}
  Stop-Collector
  $raw|ConvertTo-SecureString -AsPlainText -Force|Export-Clixml -LiteralPath (Join-Path $PSScriptRoot 'config.protected.xml')
  # A stale local plaintext config would otherwise override the imported secret.
  $plain=Join-Path $PSScriptRoot 'config.json'
  if(Test-Path -LiteralPath $plain){Remove-Item -LiteralPath $plain}
  $status.Text=T '配置已加密保存，正在启动…' 'Configuration encrypted; starting…'
  Start-Collector
 }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,(T '导入失败' 'Import failed'))|Out-Null}finally{$dialog.Dispose()}
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
 }catch{[Windows.Forms.MessageBox]::Show((T '自动启动设置失败：' 'Could not change startup setting: ')+$_.Exception.Message,'Remote PC Monitor')|Out-Null}
})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=2000
$timer.Add_Tick({
 if($script:child){
  if($script:child.HasExited){$status.Text=T '采集进程已退出，请查看日志后重新启动。' 'Collector exited; check the log and restart.';$trayIcon.Text=T '远程电脑监控 · 采集已退出' 'Remote PC Monitor · Exited'}
  else{
   $logFile=Get-Item -LiteralPath (Join-Path $PSScriptRoot 'collector.log') -ErrorAction SilentlyContinue
   $last=''
   if($logFile -and $logFile.LastWriteTime -ge $script:child.StartTime){$last=Get-Content -LiteralPath $logFile.FullName -Tail 1 -ErrorAction SilentlyContinue}
   if($last -match 'Upload OK'){$status.Text=(T '后台采集中 · ' 'Collecting · ')+$last.Substring(0,[Math]::Min(21,$last.Length))+(T ' 上报成功' ' Upload succeeded');$trayIcon.Text=T '远程电脑监控 · 上报成功' 'Remote PC Monitor · Upload OK'}
   elseif($last -match 'failed'){$status.Text=T '上报暂未成功，下一周期自动重试；详情见日志。' 'Upload failed; retrying next cycle. Check the log.';$trayIcon.Text=T '远程电脑监控 · 等待重试' 'Remote PC Monitor · Retrying'}
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
try{$timer.Start();[Windows.Forms.Application]::Run($form)}finally{Stop-Collector;$timer.Stop();$timer.Dispose();$trayIcon.Visible=$false;$trayIcon.Dispose();$menu.Dispose();$form.Dispose();$script:monitorIcon.Dispose();$script:iconBitmap.Dispose();if($script:uiLock){$script:uiLock.Dispose()}}
