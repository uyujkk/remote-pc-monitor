# 快速部署：一台 Windows 电脑 + 一台 Linux 服务器

[English](quick-start.md) · [完整中文手册](manual.zh-CN.md) · [返回仓库首页](../README.zh-CN.md) · [下载 Release](https://github.com/uyujkk/remote-pc-monitor/releases/latest)

本页只讲**全新安装**。已有 `/etc/remote-monitor-ecs/config.json` 或正在运行的 `remote-monitor-ecs` 服务时，请直接看[升级旧部署](manual.zh-CN.md#更新旧部署与日常检查)，不要执行 `install.sh`。

## 0. 确认环境

- x86-64 Alibaba Cloud Linux 3（其他发行版需自行验证）、root 终端、systemd、Python 3.11、nginx。
- 一台 Windows 10/11 电脑，使用 Windows PowerShell 5.1。
- 自己的公网 IPv4 **或**域名；两端都能访问，且需有与该地址匹配的**可信 HTTPS 证书**。域名不是必需的。
- 云安全组和当前服务器防火墙允许 TCP **443**；使用 HTTP-01 申请/续期证书时还需 **80**。保留现有 SSH 规则。**不要开放 18081。**

如果计划使用 Cloudflare 域名，先看[Cloudflare 接入方式](cloudflare.zh-CN.md)。本手册的 `monitor.example.com` 只是示例，必须换成自己的地址。

先在 ECS root 终端安装基础依赖，再按[证书和自动续期说明](tls.zh-CN.md)取得可信证书：

```bash
dnf install -y python3.11 nginx
```

## 1. 安装服务端

先在服务器创建目录：

```bash
mkdir -p /root/remote-monitor-install
```

从**同一个** [GitHub Release](https://github.com/uyujkk/remote-pc-monitor/releases/latest)下载 `remote-monitor-ecs.tar.gz` 与 `SHA256SUMS.txt`，通过 ECS Workbench 文件管理上传到服务器的 `/root/remote-monitor-install/`。在该目录执行：

```bash
cd /root/remote-monitor-install
sha256sum --check --ignore-missing SHA256SUMS.txt
```

**只有看到 `remote-monitor-ecs.tar.gz: OK` 才执行下一段。**如文件未找到或校验失败，重新下载/上传，不要跳过校验。

```bash
tar -xzf remote-monitor-ecs.tar.gz
cd remote-monitor-ecs
```

运行 `/opt/remote-monitor-certbot/bin/certbot certificates` 确认证书的实际路径后，设置下面三个变量。将示例域名改成**证书覆盖的自己地址**；如用 IP 证书，`MONITOR_ORIGIN` 填 `https://你的公网IP`。证书路径也要按实际情况修改：

```bash
export MONITOR_ORIGIN='https://monitor.example.com'
export MONITOR_CERTIFICATE='/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem'
export MONITOR_PRIVATE_KEY='/etc/letsencrypt/live/remote-monitor-ip/privkey.pem'
bash install.sh
```

安装时设置登录名和 **12–256 字符**密码。密码输入不会回显。`MONITOR_ORIGIN` 只能是 HTTPS 根地址，使用 443 端口，不带末尾 `/` 或路径。安装程序不修改云安全组或系统防火墙。

## 2. 接入 Windows 电脑

1. 在 Windows 电脑打开刚设置的 `MONITOR_ORIGIN` 并登录。点击网页的**接入电脑**，下载 `windows-tray-collector.zip`（也可从同一 Release 下载）和网页生成的 `config.json`。
2. 将 ZIP 解压到一个长期保留的目录，例如 `D:\RemotePcMonitor`。如有旧采集端，先退出旧托盘程序或停止旧计划任务。
3. 双击 `启动监控.vbs`，在图形窗口点击**导入接入配置**，选择自己网站下载的 `config.json`。
4. 等待显示**上报成功**，再最小化到托盘。右键托盘图标可选择**退出并停止采集**。可选启用“登录 Windows 后自动启动”。

`config.json` 包含设备令牌和结果摘要密钥，**不要公开或提交到 GitHub**；导入后安全删除或离线保管。再次生成配置会轮换设备令牌，使旧配置停止上报。

## 3. 验证与下一步

在服务器检查：

```bash
systemctl is-active remote-monitor-ecs
nginx -t
curl --fail "$MONITOR_ORIGIN/healthz"
```

正常应分别显示 `active`、nginx 配置成功、`{"ok":true}`。还要从**被监控的 Windows 电脑**打开网页，确认监控页出现新数据；仅在服务器本机成功不代表外网可达。

进入网页**安全设置**，下载脚本摘要恢复密钥并离线保管；可选设置验证器动态码。若需要每日备份，见[完整手册的备份章节](manual.zh-CN.md#可选每日备份)。遇到超时、401/429、传感器空白或需要升级，见[完整手册](manual.zh-CN.md#更新旧部署与日常检查)。
