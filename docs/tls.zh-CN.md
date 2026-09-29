# HTTPS 证书与自动续期

[English](tls.md) · [中文快速部署](quick-start.zh-CN.md) · [中文完整手册](manual.zh-CN.md)

安装程序要求**事先准备好可信 HTTPS 证书**。你可以使用自己控制的域名，也可以使用受支持的公网 IPv4 证书；访问地址必须与证书覆盖的名称/IP 一致。本文以 Alibaba Cloud Linux 3、Python 3.11 和 nginx 为例。`monitor.example.com` 是示例域名，必须换成自己的域名或公网 IP。程序不会购买域名，也不会替你接受证书机构条款。

如果域名由 Cloudflare 管理，先阅读[接入方案](cloudflare.zh-CN.md)；DNS only（灰云）可让 HTTP-01 验证直接到达 ECS。使用代理或 Tunnel 时，还需要验证对应网络路径。

Let's Encrypt 已提供公网 IP 证书，但要求 **6 天有效期**，因此自动续期特别重要。使用 Certbot 的 `webroot` 方法申请 IP 证书需要 **Certbot 5.4 或更新版本**，见 [Let's Encrypt 官方说明](https://letsencrypt.org/2026/03/11/shorter-certs-certbot)。

## 1. 准备 HTTP 验证入口

在云安全组和主机**当前生效的防火墙区域**允许 TCP 80 和 443；保留原有 SSH 规则。使用域名时，先确认 DNS `A` 记录指向这台服务器。

创建 `/etc/nginx/conf.d/remote-monitor-http.conf`，将 `server_name` 替换成自己的域名或公网 IPv4：

```nginx
server {
    listen 80;
    server_name monitor.example.com;
    location ^~ /.well-known/acme-challenge/ {
        root /usr/share/nginx/html/remote-monitor-acme;
        default_type text/plain;
        try_files $uri =404;
    }
    location / { return 404; }
}
```

```bash
install -d -m 755 /usr/share/nginx/html/remote-monitor-acme/.well-known/acme-challenge
nginx -t && systemctl enable --now nginx
systemctl reload nginx
```

不要覆盖与本项目无关的 nginx 虚拟主机。申请证书前，从服务器外部确认 HTTP 验证目录可访问。

## 2. 申请证书

在独立 Python 虚拟环境安装 Certbot：

```bash
python3.11 -m venv /opt/remote-monitor-certbot
/opt/remote-monitor-certbot/bin/python -m pip --isolated install --index-url https://pypi.org/simple 'certbot>=5.4,<6'
```

**使用域名**时，将示例域名改成自己的：

```bash
PYTHONUTF8=1 /opt/remote-monitor-certbot/bin/certbot certonly \
  --webroot --webroot-path /usr/share/nginx/html/remote-monitor-acme \
  --cert-name remote-monitor-ip -d monitor.example.com
```

**使用公网 IPv4** 时，将文档示例地址改成自己实际的公网 IP：

```bash
PYTHONUTF8=1 /opt/remote-monitor-certbot/bin/certbot certonly \
  --webroot --webroot-path /usr/share/nginx/html/remote-monitor-acme \
  --preferred-profile shortlived \
  --ip-address 192.0.2.10 --cert-name remote-monitor-ip
```

按终端提示输入自己的邮箱并自行阅读、决定是否接受证书机构条款。这里的 `remote-monitor-ip` 只是证书的**本地名称**，域名证书也可沿用这个名称。默认生成路径：

```text
/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem
/etc/letsencrypt/live/remote-monitor-ip/privkey.pem
```

用 `/opt/remote-monitor-certbot/bin/certbot certificates` 核对**实际路径和覆盖的地址**。后续 `MONITOR_ORIGIN` 必须与证书匹配。不要把私钥上传 GitHub。

## 3. 配置自动续期

若已配置有效的自动续期，不要重复安装另一个定时器。否则创建 `/etc/systemd/system/remote-monitor-cert-renew.service`：

```ini
[Unit]
Description=Renew monitor HTTPS certificate
Wants=network-online.target
After=network-online.target nginx.service
[Service]
Type=oneshot
Environment=PYTHONUTF8=1
ExecStart=/opt/remote-monitor-certbot/bin/certbot renew --cert-name remote-monitor-ip --quiet --deploy-hook "/usr/sbin/nginx -t && /usr/bin/systemctl reload nginx"
```

创建 `/etc/systemd/system/remote-monitor-cert-renew.timer`：

```ini
[Unit]
Description=Check monitor certificate renewal twice daily
[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=1800
Persistent=true
[Install]
WantedBy=timers.target
```

先核对系统上 `nginx` 和 `systemctl` 的真实路径，再启用并模拟续期：

```bash
systemctl daemon-reload
systemctl enable --now remote-monitor-cert-renew.timer
PYTHONUTF8=1 /opt/remote-monitor-certbot/bin/certbot renew \
  --cert-name remote-monitor-ip --dry-run --run-deploy-hooks \
  --deploy-hook '/usr/sbin/nginx -t && /usr/bin/systemctl reload nginx'
systemctl list-timers remote-monitor-cert-renew.timer --no-pager
```

继续保留 TCP 80 和 `/.well-known/acme-challenge/`，否则 HTTP-01 续期会失败。一次 dry run 成功只证明这次模拟可行，还需定期检查续期日志与证书到期日。证书报错时修复证书或域名，**不要关闭 TLS 验证**。
