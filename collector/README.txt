Remote PC Monitor - Windows tray collector

The application UI supports Chinese and English. Select the language in the upper-right corner; the choice is saved locally.

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
11. On the dashboard Security page, download the script-summary recovery key and store it offline. The server cannot recover it.

Use only configuration downloaded from your own server. The public collector accepts HTTPS /api/ingest endpoints; it is not bound to any author's server.
Config import immediately starts transmitting hardware metrics to that endpoint.
The Open website button uses the host from the imported configuration.

If VBScript is disabled, create a shortcut to powershell.exe with these arguments:
-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "D:\RemotePcMonitor\Monitor.ps1"
The scripts are not code-signed. Review the source before running.
Use 查看日志 to read collector.log. 诊断连接.cmd performs a connection diagnosis and opens a console; it does not upload hardware samples.

Metrics: CPU load/frequency/model, motherboard model, RAM module models, physical disk models, memory, disk capacity/IO, aggregate network rates, uptime and the first GPU, including its power reading when available. Serial numbers are not collected.
NVIDIA metrics use the driver's nvidia-smi when available. Optional CPU temperature and other GPU sensors use LibreHardwareMonitor WMI if already installed.
No drivers or sensor tools are installed automatically. Windows standard WMI classes do not provide a reliable direct CPU package/core temperature; LibreHardwareMonitor WMI is optional. Missing readings remain null (shown as a dash).
Health: the 0-100 score is a resource-pressure heuristic with coverage, not a hardware diagnosis. The 1-10 stability index is read from Win32_ReliabilityStabilityMetrics when available. WHEA System-log events are counted over 24 hours, including an explicitly identified memory-related subset; non-ECC RAM has no universal error counter, and zero logged events does not prove healthy memory.
Capacity is GiB although the UI abbreviates it as GB; throughput MB/s is decimal. Virtual network adapters may be counted twice.
Optional AUTO-MAS status: the collector reads GET /api/core/health and, when available, GET /api/dispatch/runtime-snapshot on 127.0.0.1:36163. AUTO-MAS v5.4.0 has no snapshot endpoint, so the collector reads /api/history/search at most every five minutes for seven-day completed/error totals and up to twelve recent result excerpts. Excerpts are length-limited and common links, emails, paths and credential assignments are masked, but arbitrary result text may still contain private information. If AUTO-MAS uses another port, create auto-mas-port.txt beside Collect.ps1 with only the local port number. No public AUTO-MAS port is needed. Raw logs, users and configuration are not uploaded. A responding API or previous DONE result does not prove current task progress.
On AUTO-MAS v5.6.0, the dashboard can show how long the visible status of each task has remained unchanged during collector observation. This timer resets when the collector restarts or loses the snapshot. It is not a stall diagnosis, and task IDs stay local to the collector.
With a newly generated config.json, the collector encrypts result excerpt text before upload; the server can still see status, timestamp, counts and task names. Older config files lack the key and cannot encrypt old or new summaries. Re-generate and import a config after updating the server and collector to activate this feature; this rotates the device token.
The collector does not capture the screen, send game input or run remote commands.
Online means a sample arrived recently; it does not prove an automation task is healthy.
There is no offline spool or independent crash watchdog.
