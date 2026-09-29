# 远程电脑监控

[English README](README.md) · [下载最新版](https://github.com/uyujkk/remote-pc-monitor/releases/latest) · [AUTO-MAS 状态接入](docs/auto-mas.zh-CN.md) · [Cloudflare 中文接入方案](docs/cloudflare.zh-CN.md) · [HTTPS 证书配置](docs/tls.md) · [安全说明](SECURITY.md)

这是一套自行部署的 Windows 电脑硬件监控工具：Linux 服务器接收数据并提供网页，Windows 采集端在后台运行，通过系统托盘控制。手机或另一台电脑打开网页即可查看。它**不提供远程控制**；“在线”只表示最近收到硬件数据，不代表游戏或自动化任务执行成功。

网页和 Windows 托盘采集端均可切换中文或 English，网页选项会保存在当前浏览器。默认设计为**一位管理员、一台被监控电脑、一个服务端实例**。

## 功能与组成

- 查看 CPU、内存、显卡、温度（硬件支持时）、显卡功耗、磁盘、网络速度和运行时间，并显示 CPU、主板、显卡、内存模组及物理磁盘型号；不采集序列号。
- 可选读取同一台 Windows 电脑上的 AUTO-MAS 只读任务快照，在网页显示后端状态、运行任务数和脚本状态；具体设置及限制见 [AUTO-MAS 接入说明](docs/auto-mas.zh-CN.md)。
- 网页侧边栏分为总览、硬件与系统、运行趋势、健康与稳定、脚本状态、执行结果和安全设置；执行结果汇总最近 7 天的完成/报错数量与最多 12 条摘要。AUTO-MAS v5.4.0 无法提供实时任务进度。
- “健康指数”是当前资源压力的 0–100 启发式评分，并显示可用指标覆盖率；“稳定指数”直接读取 Windows 可靠性监视器的 1–10 指数。两项均有历史图表。另显示近 24 小时 WHEA 硬件错误事件及可识别的内存相关事件数；普通非 ECC 内存不能提供完整纠错计数，0 条记录不代表内存无故障。
- 查看最近 1 小时、24 小时、7 天的趋势；图表按指标调整纵轴并显示最新、最低、最高值，包含显卡功耗历史；服务端保留约 30 天采样。
- Windows 采集端隐藏命令行，提供图形窗口与托盘图标；可选择登录 Windows 后自动启动。
- HTTPS 传输、密码和设备令牌哈希存储、可撤销登录会话、基本限流；可选启用验证器 6 位动态码（TOTP），沿用现有 HTTPS 公网 IP 即可。通行密钥 WebAuthn 需要域名，本项目目前未实现。
- 新版接入配置由浏览器本地生成摘要密钥，Windows 采集端在上传前加密 AUTO-MAS **结果摘要正文**，服务器只存密文；执行状态、时间、计数和任务名称仍可由服务器读取。安全边界和密钥恢复见[安全说明](SECURITY.md)。
- 可选每日 SQLite 备份；不会自动把备份复制到另一台机器。

```text
Windows 托盘采集端 -- HTTPS --> nginx :443 --> Gunicorn 127.0.0.1:18081
                                   ^                   |
                                   |                 SQLite
                             手机 / 电脑浏览器
```

## 下载哪个文件

从 [GitHub Release](https://github.com/uyujkk/remote-pc-monitor/releases/latest) 下载，安装前用同一 Release 中的 `SHA256SUMS.txt` 校验压缩包。

| 文件 | 用途 |
| --- | --- |
| `remote-monitor-ecs.tar.gz` | 全新安装 Linux 服务端，含网页和离线 Python 依赖 |
| `windows-tray-collector.zip` | Windows 托盘采集端 |
| `remote-monitor-hardening-v2.tar.gz` | 更新采用原始 `/opt/remote-monitor-ecs` 目录布局的旧部署；全新安装不需要 |
| `remote-monitor-backup-v1.tar.gz` | 可选的每日备份服务 |
| `SHA256SUMS.txt` | 以上四个压缩包的 SHA-256 值 |

公开压缩包由通用源码重新构建，不包含个人服务器地址、账号配置、密码、设备令牌、数据库、日志、备份或证书私钥。它们与以前针对某台服务器制作的交付包并非逐字节相同。

## 准备条件

- x86-64 Linux 服务器，使用 systemd、Python 3.11 和 nginx。原部署在 Alibaba Cloud Linux 3 验证过；其他发行版请先自行验证。
- 可从被监控电脑和查看设备访问的公网 IPv4 或域名，以及与该地址匹配的**可信 HTTPS 证书**。域名不是必须的；支持的公网 IP 证书也可以，详见 [证书说明](docs/tls.md)。
- 云安全组及服务器防火墙允许 **TCP 443**；如果使用 HTTP-01 申请/续期证书，还需 **TCP 80**。**不要开放 18081**，也不要误删现有 SSH 规则。
- Windows 10/11、Windows PowerShell 5.1、.NET/WinForms。采集程序本身不自动安装显卡驱动或传感器工具。

安装包内的离线 Python wheel 仅面向 **Linux x86-64 / CPython 3.11**。ARM 或其他 Python ABI 不适用。

### 域名和 Cloudflare 怎么选

如果使用 Cloudflare，建议先添加 `monitor` 的 `A` 记录，指向自己的服务器公网 IP，设为 **DNS only / 仅 DNS（灰云）**。这样 Cloudflare 只负责域名解析，电脑仍直连服务器；尤其适合此前 `*.workers.dev` 在本地网络超时的情况。确认两端都能访问后，才考虑切到 **Proxied / 代理（橙云）** 并启用 **Full (strict)**。橙云或 Cloudflare Tunnel 都会让访问经过 Cloudflare；若本地网络到 Cloudflare 不通，换一个 Cloudflare 主机名未必有效。

完整的 DNS 设置、HTTPS、代理缓存/挑战、Tunnel 和旧 IP 地址迁移步骤见 [Cloudflare 中文接入方案](docs/cloudflare.zh-CN.md)。不要只修改 DNS 就认为迁移完成：程序会校验配置中的访问域名，Windows 采集端也保存了上传地址。中国大陆服务器的域名使用还应先向服务商确认相应备案要求。

## 全新安装服务端

在可信终端中以 root 执行。已部署的服务器**不要重跑全新安装脚本**；旧部署见下文更新/迁移说明。

1. 安装依赖。Alibaba Cloud Linux 3 示例：

   ```bash
   dnf install -y python3.11 nginx
   ```

2. 按 [HTTPS 证书说明](docs/tls.md)设置证书和自动续期。证书名称必须覆盖实际访问的 IP 或域名；确保 80/443 的云安全组和主机防火墙规则正确。

3. 将 `remote-monitor-ecs.tar.gz` 和 `SHA256SUMS.txt` 上传到服务器，在所在目录校验：

   ```bash
   sha256sum --check --ignore-missing SHA256SUMS.txt
   ```

4. 解压并运行安装脚本。将下面示例域名换成**你自己的**域名或公网 IPv4，并核对证书路径：

   ```bash
   tar -xzf remote-monitor-ecs.tar.gz
   cd remote-monitor-ecs
   export MONITOR_ORIGIN='https://monitor.example.com'
   export MONITOR_CERTIFICATE='/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem'
   export MONITOR_PRIVATE_KEY='/etc/letsencrypt/live/remote-monitor-ip/privkey.pem'
   bash install.sh
   ```

   `MONITOR_ORIGIN` 只能是 443 端口的 HTTPS 根地址，不带末尾斜杠、路径或自定义端口。示例中的 `remote-monitor-ip` 是证书**本地名称**，不是要求使用 IP 证书。

5. 输入登录名和长度为 12–256 字符的密码；密码输入不会显示。安装完成后打开自己的 `MONITOR_ORIGIN` 登录。

程序文件位于 `/opt/remote-monitor-ecs`，私有配置位于 `/etc/remote-monitor-ecs`，数据库位于 `/var/lib/remote-monitor-ecs`。nginx 处理 HTTPS；内部 Gunicorn 只监听 `127.0.0.1:18081`。安装脚本不会自动修改云安全组、SSH、FRP 或系统防火墙。

## 接入 Windows 电脑

1. 登录网页，点击 **接入电脑**，下载采集端和接入用 `config.json`。设备令牌由自己的服务器生成，摘要加密密钥由当前浏览器生成并加入下载文件，不会发送给服务器。每次重新生成接入配置都会轮换设备令牌，旧配置将不能继续上报。
2. 将 ZIP 解压到长期保留的目录，例如 `D:\RemotePcMonitor`。先停止旧采集端或旧计划任务，避免重复运行。
3. 双击 **启动监控.vbs**。出现图形窗口后可在右上角切换 **English**；点击 **导入接入配置**，选择刚下载的 `config.json`。
4. 等待显示 **上报成功**，再点击 **最小化到托盘**。直接关闭窗口也会隐藏到托盘。双击托盘图标可重新打开；右键选择 **退出并停止采集** 会真正退出。
5. 可选启用 **登录 Windows 后自动启动并收到托盘**。这是登录当前用户后的启动方式，不是登录前运行的系统服务；下次登录时验证一次。

导入后的凭据由 Windows DPAPI 绑定当前用户和电脑保存，但最初下载的 `config.json` 仍是**明文凭据文件**，导入后请安全删除或妥善保管，绝不能提交到 GitHub。仅导入自己服务器生成的配置，因为导入会开始向其中的地址发送硬件数据。采集端约每 30 秒上报一次，网页约两分钟收不到数据会显示离线。

接入后打开 **安全设置**，下载“脚本摘要恢复密钥”并离线保管；换浏览器时在该页导入密钥后才能解密摘要。所有密钥副本丢失后，已加密的旧摘要无法恢复。可在同一页输入当前密码、将显示的密钥手动添加到支持 TOTP 的验证器，并用 6 位动态码确认启用。若验证器丢失，服务器 root 用户运行密码重置脚本可同时清除动态码绑定。

若系统禁用 VBScript，可参考 [采集端说明](collector/README.txt)建立隐藏 PowerShell 快捷方式。脚本目前未进行代码签名。**查看日志** 可打开本地采集日志；**诊断连接.cmd** 会显示命令行并测试连接，不会上传正式硬件样本。

CPU 温度仅在已有 LibreHardwareMonitor 并提供 WMI 传感器时显示。Windows 标准 WMI 温度类没有可靠的 CPU 核心或封装温度读数；采集端不会自动安装内核驱动，也不会把主板热区温度误标为 CPU 温度。旧版采样没有显卡功耗历史，升级后才开始积累。

健康指数按 CPU 压力 15%、内存压力 25%、最满磁盘 20%、CPU 温度 15%、GPU 温度 10%、WHEA 事件数 15% 计算。缺失指标不会按 0 处理，而是在已获取指标内重新归一化；覆盖率低于 40% 时不显示评分。它只提示当前负载风险，并非磁盘或内存故障诊断。稳定指数来自 Windows [`Win32_ReliabilityStabilityMetrics`](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/racwmiprov/win32-reliabilitystabilitymetrics)；硬件事件来自 [Windows 系统事件日志的 WHEA 记录](https://learn.microsoft.com/en-us/windows-hardware/drivers/whea/whea-hardware-error-events)。仅能识别明确标为内存相关的部分事件，普通非 ECC 电脑没有通用的内存纠错计数器。

## 可选：每日备份

确认网站正常后，上传并安装 `remote-monitor-backup-v1.tar.gz`：

```bash
tar -xzf remote-monitor-backup-v1.tar.gz
cd remote-monitor-backup-v1
bash install.sh
```

完成时应显示 `BACKUP_SETUP_OK`。备份每天在**北京时间 04:15–04:25**运行，存于 `/var/backups/remote-monitor-daily/`；压缩包文件名时间戳使用 UTC。新备份通过校验后才清理超过 14 天的旧备份。备份可能包含账号设置和设备凭据，应按秘密文件保管，并定期复制一份到服务器以外的位置。它不包含整机镜像、Python 虚拟环境、TLS 私钥或 FRP 数据；不要直接把备份解压覆盖正在运行的数据库。

```bash
systemctl list-timers remote-monitor-backup.timer --no-pager
journalctl -u remote-monitor-backup.service -n 30 --no-pager
```

## 更新旧部署与日常检查

旧版 `/opt/remote-monitor-ecs` 部署可使用 `remote-monitor-hardening-v2.tar.gz`；它会保留原账号、令牌和历史，运行测试后切换，并提供回滚命令。以下以 **v1.4.0** 为例，在 ECS 的 root 终端执行。全新安装无需运行升级脚本；更新已有部署也不要重跑全新安装脚本。

```bash
mkdir -p /root/update-v1.4.0
cd /root/update-v1.4.0
curl -fL --retry 3 -O https://github.com/uyujkk/remote-pc-monitor/releases/download/v1.4.0/remote-monitor-hardening-v2.tar.gz
curl -fL --retry 3 -O https://github.com/uyujkk/remote-pc-monitor/releases/download/v1.4.0/SHA256SUMS.txt
sha256sum --check --ignore-missing SHA256SUMS.txt
tar -xzf remote-monitor-hardening-v2.tar.gz
cd remote-monitor-hardening-v2
bash upgrade.sh
```

如果服务器无法访问 GitHub，可在本机从[同一版本的 Release](https://github.com/uyujkk/remote-pc-monitor/releases/tag/v1.4.0)下载这两个文件，用 ECS Workbench 文件管理上传到 `/root/update-v1.4.0`，然后从 `sha256sum` 开始执行。校验应显示压缩包 `OK`；升级成功应显示 `HARDENING_OK` 和 `{"ok":true}`。请保存输出中的 `Backup` 与 `Rollback` 路径；`Password reset` 只是备用命令，无需在正常升级时运行。升级脚本会短暂重启服务、更新网页和采集端下载文件，并在切换失败时尝试回滚。若证书路径与默认路径不同，运行前设置 `MONITOR_CERTIFICATE` 和 `MONITOR_PRIVATE_KEY`，详见[英文更新说明](README.md#update-an-original-deployment)。

服务器更新后，Windows 上退出旧托盘程序，将同一 Release 的 `windows-tray-collector.zip` 解压到原采集端目录并覆盖同名脚本，然后重新运行 `启动监控.vbs`。原有 `config.protected.xml` 可继续上报，但**没有结果摘要加密密钥**。要启用摘要加密，请在新版网页的 **安全设置** 中先导入已有恢复密钥（若有），再到 **接入电脑** 重新生成并下载 `config.json`，同时下载并离线保存恢复密钥，在采集端窗口重新导入配置。重新生成会轮换设备令牌，请尽快在被监控电脑完成导入。确认上报成功，并在有新执行结果时验证摘要可解密；旧备份中的明文摘要不会自动转换。浏览器若仍显示旧页面，可按 Ctrl+F5 刷新。

如需把**已有 IP 地址部署**迁移为 Cloudflare 管理的域名，请使用 [迁移步骤](docs/cloudflare.zh-CN.md#已有-ip-地址部署迁移到域名)，保留旧入口直到域名、证书及 Windows 上报全部验证成功。

```bash
systemctl status remote-monitor-ecs --no-pager
journalctl -u remote-monitor-ecs -n 50 --no-pager
nginx -t
curl --fail https://monitor.example.com/healthz
```

`/healthz` 正常返回 `{"ok":true}`。电脑无法连接时，依次检查域名解析、从**该电脑**到服务端的网络、云安全组、当前 firewalld 区域、nginx 和证书。HTTP 401 可能表示设备配置过期；HTTP 429 可能是重复采集进程或限流。不要通过关闭 TLS 验证解决证书错误。

原部署在 ECS 和 Windows 上做过端到端验证；公开通用包增加了可配置地址，并通过本地测试，但尚未覆盖所有新环境的实际安装。安全加固也不等于渗透测试认证。部署后仍需维护操作系统、SSH、FRP 和相关依赖。

源码结构、构建与测试见 [英文开发说明](docs/development.md)；第三方组件声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
