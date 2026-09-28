# 使用 Cloudflare 域名接入

[English version](cloudflare.md) · [中文 README](../README.zh-CN.md)

本文中的 `monitor.example.com` 和 `192.0.2.10` 只是示例，请换成**自己**的域名和 ECS 公网 IP。Cloudflare 账号本身不会给此安装程序提供固定域名；三种方案均需要你控制的域名。不要将设备令牌、账号、证书私钥或 Tunnel 令牌上传到 GitHub。

| 方案 | 数据路径 | 适用情况 | ECS 入站 Web 端口 |
| --- | --- | --- | --- |
| **DNS only（灰云）** | 电脑/浏览器 → ECS | 建议先用它测试；此前 Cloudflare Workers 地址超时的网络尤其如此 | 443；HTTP-01 续期还需 80 |
| **Proxied（橙云）** | 电脑/浏览器 → Cloudflare → ECS | 灰云稳定后，从实际使用网络测试再开启 | 443；若继续用 HTTP-01 还需 80 |
| **Cloudflare Tunnel** | 电脑/浏览器 → Cloudflare → ECS 上的 `cloudflared` → nginx | 可选，适合已完成域名 HTTPS 部署后收紧公网 Web 入站端口 | Web 可不开放；SSH 等单独处理 |

Cloudflare 官方对 [DNS-only 与代理流量路径](https://developers.cloudflare.com/dns/proxy-status/)有说明。**灰云只是 DNS 托管**，访问仍直连 ECS，服务器公网 IP 会暴露；橙云和 Tunnel 都要求被监控电脑能访问 Cloudflare。此前 `*.workers.dev` 超时，并不能通过换一个 Cloudflare 主机名保证解决。原有 SSH/FRP 端口也不是普通 HTTP 代理的范围，不要顺手改动它们。

如果域名部署在中国大陆 ECS 上，先向服务商核实适用的域名备案与接入要求。Cloudflare [China Network](https://developers.cloudflare.com/china-network/) 是另行提供的 Enterprise 服务，不会因为使用普通 Cloudflare DNS 而自动开通。

## 建议先用灰云直连

1. 注册自己的域名并添加到 Cloudflare；在域名注册商处将 NS 改为**你账户中实际显示的**两条 Cloudflare nameserver，等待域名在 Cloudflare 中显示 Active。
2. 打开 **DNS → Records**，新增 `A` 记录：名称填 `monitor`，内容填自己的 ECS 公网 IPv4，Proxy status 选 **DNS only**。DNS 记录不要填 `https://` 或端口。没有真正配置 IPv6 时不要添加 `AAAA`。
3. 从**被监控 Windows 电脑**和准备用来查看的手机/电脑确认域名解析为 ECS IP、80/443 网络可达。只在 ECS 上测试本机回环并不能证明远端网络可达。
4. 按 [HTTPS 证书配置](tls.md)为该域名签发**浏览器信任**的证书，做好续期。IP 证书不能用于验证新域名。若使用 HTTP-01，端口 80 及 `/.well-known/acme-challenge/` 必须保持可访问。
5. **全新安装**可按 [中文 README](../README.zh-CN.md#全新安装服务端)操作，设置 `MONITOR_ORIGIN='https://monitor.example.com'`，并填写这张域名证书真实的文件路径。先运行 `certbot certificates` 核对路径。安装时不要输入这里的示例域名。
6. 从两台设备打开 `https://monitor.example.com/`。在 Windows 上登录自己的网页，点 **接入电脑**，下载本服务端生成的 `config.json`，导入托盘程序，确认 **上报成功**。

## 可选：切换橙云代理

灰云访问和上报都正常后，仅把监控域名的 `A` 记录改成 **Proxied**。在 **SSL/TLS → Overview** 中选 **Full (strict)**；nginx 仍应提供有效且覆盖该域名的证书。Cloudflare 的 [Full (strict) 说明](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/)要求验证源站证书。不要为了绕过证书问题改成 Flexible。保留证书续期；Let’s Encrypt 证书还能用于以后切回灰云直连。Cloudflare Origin CA 证书只适合 Cloudflare 到源站的连接，切回灰云时浏览器可能不信任，见 [Origin CA 文档](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/)。

此网站有登录状态和 API。不要开启 **Cache Everything**；若域名已有自定义缓存规则，请对整个 `monitor.example.com` 设置 **Bypass cache**，避免登录页、会话和 `/api/*` 被缓存。Cloudflare [动态页面缓存说明](https://developers.cloudflare.com/cache/troubleshooting/dynamic-content-and-login-issues/)解释了风险。也不要让需要人工操作的 Challenge 或 Access 页面拦截 `/api/ingest`：Windows 采集端无法完成网页挑战。

安装包的 nginx 限流使用 `$remote_addr`。经过 Cloudflare 后，多个真实用户可能按同一个 Cloudflare 出口 IP 计数，出现误报 429。若确需按真实客户端 IP 限流，应仅信任 [Cloudflare 当前公布的 IP 段](https://www.cloudflare.com/ips/)，再单独配置 nginx `set_real_ip_from` 与 `real_ip_header CF-Connecting-IP`，并适当限制绕过 Cloudflare 的源站直连。**不要**直接信任任何公网客户端自己发送的 `CF-Connecting-IP` 或 `X-Forwarded-For`。发布安装包不会自动修改此项。

切换后，从实际 Windows 网络测试网页登录、`/healthz` 和连续多次上报。如果橙云域名仍超时，改回 DNS only；等本地 DNS 缓存更新后再测。若域名未变化，不必因为灰云/橙云切换而轮换采集端令牌。

## 可选：Cloudflare Tunnel

先确认域名 HTTPS 部署本身可用，再按 Cloudflare 官方 [Tunnel 安装向导](https://developers.cloudflare.com/tunnel/get-started/)安装 `cloudflared`、创建**命名 Tunnel**，为 `monitor.example.com` 添加 **Published application** 路由。ECS 上的 Service URL 使用 `https://localhost:443`，Origin Server Name 填 `monitor.example.com`，并保持 **Disable TLS certificate verification** 为关闭状态；nginx 证书必须覆盖该域名。具体 HTTPS 源站选项见 [官方说明](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/)。Tunnel token 是凭据，不能公开。

务必先在 Windows 和查看设备上验证登录、上报，再考虑关闭 ECS 的公网 Web 入站 80/443。若关闭 80，原有 HTTP-01 证书续期无法继续访问 nginx；应先改为可用的 DNS-01 续期方式，或保留 80。保留紧急 SSH 通道。不要使用会变化的 Quick Tunnel 地址作为正式地址。Tunnel 显示 Healthy 也不等于 nginx 或监控 API 一定可用。

橙云和 Tunnel 都通过 Cloudflare；如果电脑到 Cloudflare 网络不通，它们不比灰云更可靠。Cloudflare Access 可能需要采集端目前不会发送的机器认证信息；未经适配不要给上报 API 强制加交互认证，也不要关闭本程序已有的登录和设备令牌验证。

## 已有 IP 地址部署迁移到域名

**不要在现有部署上重跑全新安装脚本。** 在域名、证书和 Windows 侧网络均确认可用前，保留旧 IP 入口。先在服务器外留一份数据库和私有配置备份，并记下原 nginx 配置。程序会用 `/etc/remote-monitor-ecs/config.json` 的 `origin` 校验浏览器写入请求，也会从这里生成 Windows 上传地址，所以仅改 DNS 或 nginx `server_name` 不够。

安排维护时间，把现有私有配置里的 `origin` 改成 `https://monitor.example.com`，同时将 nginx 的 `server_name` 和证书路径调整为新域名；运行 `nginx -t` 成功后 reload nginx，并重启 `remote-monitor-ecs`。**保留**已有用户名、密码哈希、会话密钥、数据库路径和设备相关数据，不要重新初始化账号或数据库。随后在新域名登录，从 **接入电脑**重新生成/导入 Windows 配置。重新生成会轮换设备令牌，先停掉旧采集端。确认网页和新数据都正常后，才考虑停用 IP 入口。失败时用事先备份恢复配置及 nginx，再排查。备份和下载的 `config.json` 都不能公开。

## 验证与排错

```bash
nginx -t
systemctl status nginx remote-monitor-ecs --no-pager
curl --fail https://monitor.example.com/healthz
```

还应在被监控 Windows 电脑执行 `Invoke-RestMethod -Uri 'https://monitor.example.com/healthz'`，正常结果为 `{"ok":true}`。超时就查 DNS、路由、云安全组、防火墙和 Cloudflare 路径；证书警告要修复证书/域名，**不要关闭证书验证**。迁移后出现 `403 Invalid origin` 要检查程序配置的 `origin`；Cloudflare `52x` 指向代理/Tunnel 至源站连接问题；上报 `401` 可能是采集端还在使用旧配置。
