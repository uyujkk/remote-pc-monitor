Remote PC Monitor - Windows tray collector

The current application UI is Chinese. Documentation is in English.

1. Extract the ZIP into a permanent folder, e.g. D:\RemotePcMonitor.
2. Sign into YOUR self-hosted dashboard. Click 接入电脑 (Connect PC), then download config.json.
3. Stop any older collector or scheduled collector task before starting this copy.
4. Double-click 启动监控.vbs. A small GUI opens without a command prompt.
5. Click 导入接入配置 (Import configuration) and select config.json.
6. The collector stores credentials using Windows DPAPI for this user on this PC and starts reporting.
7. After 上报成功 (Upload succeeded), click 最小化到托盘 (Minimize to tray). Closing the window also hides it in the tray.
8. Double-click the tray icon to reopen. Right-click and choose 退出并停止采集 to exit and stop reporting.
9. Enable 登录 Windows 后自动启动并收到托盘 to start when this Windows user signs in. It is not a pre-login service.
10. The original downloaded config.json remains a plaintext credential: delete it or keep it securely after import.

Use only configuration downloaded from your own server. The public collector accepts HTTPS /api/ingest endpoints; it is not bound to any author's server.
Config import immediately starts transmitting hardware metrics to that endpoint.
The Open website button uses the host from the imported configuration.

If VBScript is disabled, create a shortcut to powershell.exe with these arguments:
-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "D:\RemotePcMonitor\Monitor.ps1"
The scripts are not code-signed. Review the source before running.
Use 查看日志 to read collector.log. 诊断连接.cmd performs a connection diagnosis and opens a console; it does not upload hardware samples.

Metrics: CPU load/frequency, memory, disk capacity/IO, aggregate network rates, uptime and the first GPU.
NVIDIA metrics use the driver's nvidia-smi when available. Optional CPU temperature and other GPU sensors use LibreHardwareMonitor WMI if already installed.
No drivers or sensor tools are installed automatically. Missing readings remain null (shown as a dash).
Capacity is GiB although the UI abbreviates it as GB; throughput MB/s is decimal. Virtual network adapters may be counted twice.
The collector does not capture the screen, send game input, run remote commands or inspect automation task logs.
Online means a sample arrived recently; it does not prove an automation task is healthy.
There is no offline spool or independent crash watchdog.
