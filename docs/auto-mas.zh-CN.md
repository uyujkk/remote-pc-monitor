# AUTO-MAS 只读状态接入

Windows 采集端可选读取**同一台电脑**上运行的 AUTO-MAS。它每次采样时访问本机 `127.0.0.1:36163` 的 `/api/core/health`，并在版本支持时读取 `/api/dispatch/runtime-snapshot`。新版运行快照接口见 AUTO-MAS [源码](https://github.com/AUTO-MAS-Project/AUTO-MAS/blob/main/app/api/dispatch.py)。默认正式版端口见 [main.py](https://github.com/AUTO-MAS-Project/AUTO-MAS/blob/main/main.py)。如果 AUTO-MAS 使用其他本机端口，在采集端 `Collect.ps1` 所在目录创建 `auto-mas-port.txt`，文件内容只写端口数字。

采集端仅上报接口状态、版本、最近一次历史结果的时间与 `DONE`/`ERROR`，以及新版快照接口提供的运行任务数、已安排脚本数和最多 8 个任务的摘要（每个任务最多 6 个脚本名称和状态）。脚本名称因此会显示给监控网站的登录用户。**不上传原始日志、用户 ID/名称、队列 ID 或 AUTO-MAS 完整配置文件**，也不会向 AUTO-MAS 发送控制命令。服务器会拒绝多余字段。

**AUTO-MAS v5.4.0 有后端健康接口，但没有运行快照接口。**对此版本，采集端最多每 5 分钟请求一次只读用途的 `POST /api/history/search`，只取最近记录的时间和 `DONE`/`ERROR`。网页标注“历史模式”，无法判断当前是否有任务在运行。新版若提供快照接口，才会显示实时任务与脚本状态。历史记录显示“完成”也**不证明当前任务正在推进**；本版没有独立的卡死检测或通知。AUTO-MAS 停止时，硬件监控仍可继续。

AUTO-MAS 后端端口只供本机使用，**不要在公网、防火墙或路由器开放 36163**。采集端只需沿用现有的出站 HTTPS 上报。

更新服务端和采集端后，可在被监控电脑本地执行 `Collect.ps1 -Once -NoUpload` 查看一次样本中的 `autoMas.state`。`ready` 表示读到任务快照；`limited` 表示后端可响应，但没有实时快照（v5.4.0 属于此类）；`unavailable` 可能是程序未运行、端口不同或请求超时。诊断样本可能包含脚本名称，请勿公开分享。
