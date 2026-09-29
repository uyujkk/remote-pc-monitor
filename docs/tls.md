# HTTPS and automatic renewal

[简体中文](tls.zh-CN.md) · [Quick deployment](quick-start.md) · [Complete manual](manual.md)

Use your own DNS hostname or public IPv4 address throughout. Never use another deployment's address. The application installer expects an existing trusted certificate; it does not purchase a domain or accept certificate-authority terms for you.

If Cloudflare manages your domain, read the [Cloudflare guide](cloudflare.md) ([简体中文](cloudflare.zh-CN.md)) first. The DNS-only route keeps HTTP-01 validation direct; proxy and Tunnel routes need their own reachability checks.

The instructions below target Alibaba Cloud Linux 3 with Python 3.11 and nginx. A domain is optional. IP certificates need compatible Certbot support and short-lived renewal. See [Let's Encrypt's official IP certificate guide](https://letsencrypt.org/2026/03/11/shorter-certs-certbot) and [Certbot's instructions](https://certbot.eff.org/instructions?os=pip&ws=other).

## 1. HTTP challenge endpoint

Allow TCP 80 and 443 in your cloud security group and the host's active firewall zone. Keep your existing SSH rules. If using a domain, point its DNS A record at this server and confirm it resolves correctly.

Create `/etc/nginx/conf.d/remote-monitor-http.conf` with the following, replacing `monitor.example.com` with your own hostname or public IPv4:

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

Preserve other nginx virtual hosts. Do not overwrite an unrelated configuration. Verify the HTTP challenge directory is reachable externally before requesting a certificate.

## 2. Issue the certificate

Install Certbot into its own environment using an HTTPS package source:

```bash
python3.11 -m venv /opt/remote-monitor-certbot
/opt/remote-monitor-certbot/bin/python -m pip --isolated install --index-url https://pypi.org/simple 'certbot>=5.4,<6'
```

For a **DNS hostname** (replace the example):

```bash
PYTHONUTF8=1 /opt/remote-monitor-certbot/bin/certbot certonly \
  --webroot --webroot-path /usr/share/nginx/html/remote-monitor-acme \
  --cert-name remote-monitor-ip -d monitor.example.com
```

For an **IPv4 address**, replace the documentation-only address below with your actual public IP:

```bash
PYTHONUTF8=1 /opt/remote-monitor-certbot/bin/certbot certonly \
  --webroot --webroot-path /usr/share/nginx/html/remote-monitor-acme \
  --preferred-profile shortlived \
  --ip-address 192.0.2.10 --cert-name remote-monitor-ip
```

Enter your own email and review the CA terms interactively. This produces:

```text
/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem
/etc/letsencrypt/live/remote-monitor-ip/privkey.pem
```

The certificate name is only a local label; it can be used for either path above. The address in `MONITOR_ORIGIN` must match the certificate.

## 3. Enable renewal

Create `/etc/systemd/system/remote-monitor-cert-renew.service`:

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

Create `/etc/systemd/system/remote-monitor-cert-renew.timer`:

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

Check the executable paths on your distribution, then run:

```bash
systemctl daemon-reload
systemctl enable --now remote-monitor-cert-renew.timer
PYTHONUTF8=1 /opt/remote-monitor-certbot/bin/certbot renew \
  --cert-name remote-monitor-ip --dry-run --run-deploy-hooks \
  --deploy-hook '/usr/sbin/nginx -t && /usr/bin/systemctl reload nginx'
systemctl list-timers remote-monitor-cert-renew.timer --no-pager
```

Keep port 80 and the challenge location available for renewal. A successful dry run verifies that attempt, not all future renewals. Check journal output and certificate expiry periodically. If you already have a working renewal setup, preserve it rather than adding a duplicate timer.
