# 远程电脑监控

自己部署一套 Windows 电脑监控服务。托盘采集端经 HTTPS 向自己的 Linux 服务器上报硬件状态及可选的 AUTO-MAS 信息；手机或另一台电脑登录网页即可查看。**本项目不提供远程控制。**

**[English](README.md)** · [下载最新 Release](https://github.com/uyujkk/remote-pc-monitor/releases/latest) · [安全说明](SECURITY.md)

## 从这里开始

| 你的情况 | 中文说明 | English |
| --- | --- | --- |
| 第一次安装，希望按步骤尽快部署 | [快速部署手册](docs/quick-start.zh-CN.md) | [Quick deployment](docs/quick-start.md) |
| 已有服务器，需要更新、维护或排错 | [完整手册](docs/manual.zh-CN.md) | [Complete manual](docs/manual.md) |
| 配置 HTTPS 证书与续期 | [证书说明](docs/tls.zh-CN.md) | [TLS guide](docs/tls.md) |
| 接入 Cloudflare 管理的域名 | [Cloudflare 接入](docs/cloudflare.zh-CN.md) | [Cloudflare guide](docs/cloudflare.md) |
| 接入 AUTO-MAS 脚本状态 | [AUTO-MAS 接入](docs/auto-mas.zh-CN.md) | [AUTO-MAS guide](docs/auto-mas.md) |

**已有部署不要重跑全新安装脚本。**请使用[完整手册的升级步骤](docs/manual.zh-CN.md#更新旧部署与日常检查)。服务器和 Windows 采集端是两个部分，只更新需要变更的一端。安装前从**同一个 Release**下载压缩包与 `SHA256SUMS.txt` 并校验。

## 能看到什么

- CPU、内存、显卡、支持的温度与显卡功耗、磁盘、网络和运行时间；显示配件型号，不采集序列号。缺失的传感器读数显示“—”。
- 总览、硬件与系统、运行趋势、健康与稳定、脚本状态、执行结果、安全设置等独立模块；可查看最近 1 小时、24 小时和 7 天趋势，采样大约保留 30 天。
- 当前资源压力的健康指数、Windows 可靠性监视器稳定指数和系统记录的 WHEA 事件数。0 条错误记录不等于硬件无故障。
- 可选读取同一台电脑上的 AUTO-MAS 只读状态与最近结果。电脑在线或历史任务成功，不等于当前脚本正在推进。
- 网页与 Windows 托盘程序可切换中文、英文；采集端可在当前用户登录 Windows 后自动启动。
- HTTPS、密码与设备令牌哈希存储、可撤销会话、限流、可选验证器动态码，以及可选的 AUTO-MAS **结果摘要正文**上传前加密。详见[安全边界](SECURITY.md)。
- 可选的每日 SQLite 校验备份；异机备份需自行复制。

```text
Windows 托盘采集端 -- HTTPS --> nginx :443 --> Gunicorn 127.0.0.1:18081
                                   ^                   |
                                   |                 SQLite
                             手机 / 电脑浏览器
```

当前设计面向**一位管理员、一台被监控电脑、一个服务端实例**。需要 x86-64 Linux 服务器（systemd、Python 3.11、nginx）、能从 Windows 电脑和查看设备访问的公网 IPv4 或域名及匹配的可信 HTTPS 证书，以及 Windows 10/11 和 Windows PowerShell 5.1。**18081 只供本机使用**；网页需开放 TCP **443**，采用 HTTP-01 续期时还需 **80**。原部署在 Alibaba Cloud Linux 3 验证过；其他发行版需另行验证。

## Release 文件怎么选

| 文件 | 用途 |
| --- | --- |
| `remote-monitor-ecs.tar.gz` | 全新安装 Linux 服务端 |
| `windows-tray-collector.zip` | Windows 托盘采集端 |
| `remote-monitor-hardening-v2.tar.gz` | 更新现有 `/opt/remote-monitor-ecs` 部署 |
| `remote-monitor-backup-v1.tar.gz` | 可选的每日备份定时器 |
| `SHA256SUMS.txt` | 上述四个安装包的 SHA-256 值 |

公开安装包不包含个人服务器地址、账号配置、密码、设备令牌、数据库、备份或证书私钥。网页下载的 `config.json` **含有接入凭据**，请妥善保管，不要提交到 GitHub。

`main` 分支可能包含**尚未打包到 Release** 的改动。安装或升级时请使用 Release 安装包及其配套校验文件，不要以为仓库最新源码已经自动部署到服务器。

源码结构、构建与测试见[开发说明](docs/development.md)；第三方组件声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
