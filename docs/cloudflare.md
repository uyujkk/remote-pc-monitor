# Cloudflare domain options

[简体中文版](cloudflare.zh-CN.md) · [English README](../README.md)

This guide uses `monitor.example.com` and `192.0.2.10` as **examples**. Replace them with a domain you control and your server's public IPv4 address. Do not publish a device token, dashboard account, TLS private key or Tunnel token in DNS, GitHub, screenshots or support requests.

## Choose a route

| Route | Traffic path | When to use it | Origin ports |
| --- | --- | --- | --- |
| Cloudflare DNS-only (gray cloud) | PC/browser → your ECS server | Recommended first test when Cloudflare-hosted names time out on your network | 443, plus 80 for HTTP-01 renewal |
| Cloudflare proxy (orange cloud) | PC/browser → Cloudflare → ECS | Use only after testing from the actual Windows PC and viewing device | 443, plus 80 if your existing renewal uses HTTP-01 |
| Cloudflare Tunnel | PC/browser → Cloudflare → `cloudflared` → nginx on ECS | Optional after a working domain-based installation, when you want to avoid public inbound web ports | None for the web app; preserve SSH/other services separately |

All three routes require a domain you control. A Cloudflare account by itself does not provide a reusable hostname for this installer. The old `*.workers.dev` timeout is **not** fixed merely by replacing it with another proxied Cloudflare hostname. DNS-only uses Cloudflare for DNS while sending application traffic directly to ECS; a proxied record and Tunnel both put Cloudflare in the application path. Test from your actual networks before switching the collector.

Cloudflare's [proxy status documentation](https://developers.cloudflare.com/dns/proxy-status/) describes the DNS-only and proxied paths. Standard Cloudflare proxying does not cover the old FRP/SSH TCP ports; leave those records/services separate. The application itself uses HTTPS on 443 only. For the existing Alibaba Cloud instance in mainland China, check your domain's applicable ICP/hosting requirements with your provider before making the hostname public. Cloudflare's [China Network](https://developers.cloudflare.com/china-network/) is a separate Enterprise subscription, not a feature automatically enabled by ordinary Cloudflare DNS.

## Recommended: Cloudflare DNS-only + your nginx HTTPS

1. Register a domain and add it to Cloudflare. Change the domain's nameservers at its registrar to the pair shown in **your** Cloudflare account. Wait until Cloudflare shows the zone as active.
2. In **DNS → Records**, add an `A` record: name `monitor`, content **your ECS public IPv4**, proxy status **DNS only** (gray cloud). Do not put `https://` or a port in the DNS record. Avoid an `AAAA` record unless your server actually serves IPv6.
3. From the Windows PC and from the viewing device, verify that `monitor.example.com` resolves to your ECS public IP and that TCP 80/443 can reach the server. DNS-only reveals that IP and does not add Cloudflare's HTTP security layer.
4. Obtain a publicly trusted certificate for `monitor.example.com` using the [TLS guide](tls.md). Use the hostname in the certificate and in `MONITOR_ORIGIN`. Keep the HTTP-01 challenge on port 80 reachable for renewal, or use a separately configured DNS-01 renewal method. A certificate for the old IP does not validate the new hostname.
5. For a **fresh** installation, use the release installer with your certificate paths:

   ```bash
   export MONITOR_ORIGIN='https://monitor.example.com'
   export MONITOR_CERTIFICATE='/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem'
   export MONITOR_PRIVATE_KEY='/etc/letsencrypt/live/remote-monitor-ip/privkey.pem'
   bash install.sh
   ```

   The `remote-monitor-ip` directory is just the Certbot certificate label used by the TLS guide; it can hold a domain certificate. Verify the actual paths with `certbot certificates` rather than assuming these defaults.
6. Open `https://monitor.example.com/` from both devices. On the Windows PC, sign in, select **接入电脑** (Connect PC), download a new `config.json` from **your** dashboard, and import it in the tray collector. Verify **上报成功** (Upload succeeded). A local `curl --resolve` test is useful but does not prove the remote network works.

## Optional: enable Cloudflare proxy

After the DNS-only path works, switch **only** the monitor hostname's `A` record to **Proxied** (orange cloud). In **SSL/TLS → Overview**, select **Full (strict)**. Keep a valid certificate on nginx; the [Full (strict) documentation](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/) requires Cloudflare to validate the origin certificate. Do not use Flexible mode to work around TLS errors. Keep the origin certificate's renewal working. A Let's Encrypt certificate also allows a DNS-only fallback; a Cloudflare Origin CA certificate is generally trusted only on the Cloudflare-to-origin leg and can cause browser trust errors if you later disable proxying. See [Cloudflare Origin CA](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/).

For this private dashboard, do not enable **Cache Everything**. If custom cache rules exist, add a bypass rule for the whole `monitor.example.com` hostname so dashboard HTML, login/session responses and `/api/*` never enter an edge cache. [Cloudflare's cache guidance](https://developers.cloudflare.com/cache/troubleshooting/dynamic-content-and-login-issues/) explains why dynamic login pages must not be cached. Keep browser challenges and interactive Access checks away from `/api/ingest`: the unattended PowerShell collector cannot solve them. Treat a Cloudflare challenge page in place of the API response as a network/configuration failure, not as a bad device token.

The packaged nginx rate limits use `$remote_addr`. Through a proxy, this normally groups visitors by Cloudflare edge IP rather than by individual client; false HTTP 429 responses are possible. Do **not** blindly trust `CF-Connecting-IP` or `X-Forwarded-For` from any Internet client. If per-client nginx limits are needed, configure nginx `set_real_ip_from` for Cloudflare's **current, verified** IP ranges and `real_ip_header CF-Connecting-IP`, then restrict direct origin access appropriately. Cloudflare publishes its [current IP ranges](https://www.cloudflare.com/ips/). This is a separate server change; the release installer does not do it.

Test from both devices: load the dashboard, sign in, verify `/healthz`, and watch the tray collector report successfully for several intervals. If the proxied hostname times out on your network, turn the record back to DNS-only. Allow time for DNS caches to update; do not change the collector's origin while troubleshooting the proxy if the hostname itself stays the same.

## Optional: Cloudflare Tunnel

Only attempt this after the normal domain and HTTPS deployment works. Follow Cloudflare's [Tunnel setup](https://developers.cloudflare.com/tunnel/get-started/) to install `cloudflared` from Cloudflare's official distribution, create a **named** tunnel and add a **Published application** route for `monitor.example.com`. On the ECS host, set the service URL to `https://localhost:443` (or `https://127.0.0.1:443`) and set **Origin Server Name** to `monitor.example.com`; keep **Disable TLS certificate verification** off. The certificate served by nginx must cover that hostname. These HTTPS-origin settings are described in [Cloudflare's Tunnel troubleshooting guide](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/). Protect the tunnel token as a credential.

Confirm from the Windows PC and viewing device that login and telemetry work through the tunnel before closing inbound 80/443. Once closed, HTTP-01 certificate renewal cannot reach nginx; move to a working DNS-01 renewal method first or retain port 80 as needed. Keep emergency SSH access. Do not map a production app to an ephemeral Quick Tunnel hostname: the app's configured origin and the collector endpoint must remain stable. Tunnel health alone does not prove nginx or the monitor API is healthy.

Tunnel and orange-cloud proxying still depend on access to Cloudflare from the monitored PC. Neither is a reliable remedy for a network that cannot reach Cloudflare. Cloudflare Access may require additional machine-to-machine authentication that this collector does not send; use it only after deliberately integrating that authentication. Do not disable the application's own login or device-token checks.

## Migrating an existing IP-based installation

**Do not rerun the fresh installer over a working deployment.** Preserve the existing IP-based URL until the new domain, certificate and remote reachability are proven. Download an off-server backup of the database and private configuration, and record the previous nginx settings. The application checks browser request `Origin` against `/etc/remote-monitor-ecs/config.json` and generates Windows endpoints from that file. Merely adding a DNS record or changing nginx's `server_name` is insufficient.

In a planned maintenance window, update the existing private config's `origin` to `https://monitor.example.com`, configure nginx with the matching `server_name` and trusted certificate, test `nginx -t`, then reload nginx and restart `remote-monitor-ecs`. Preserve the existing username, password hash, session secret, database path and device credentials. Sign in at the new hostname and generate/import its new Windows collector configuration. Generating it rotates the device token, so stop any old collector first. Verify login and fresh metrics before retiring the IP URL. If anything fails, restore the backed-up configuration/nginx files and services, then retry after diagnosis. Do not publish the backup or downloaded `config.json`.

## Checks and failure clues

```bash
nginx -t
systemctl status nginx remote-monitor-ecs --no-pager
curl --fail https://monitor.example.com/healthz
```

Run the final `curl` from the Windows PC too (PowerShell: `Invoke-RestMethod -Uri 'https://monitor.example.com/healthz'`). Expected response is `{"ok":true}`. A timeout calls for DNS, routing, security-group/firewall and Cloudflare-path checks. A certificate warning means fix the certificate or hostname; never disable certificate verification. A `403 Invalid origin` after migration points to the app's configured origin. A Cloudflare `52x` response points toward the proxy/tunnel-to-origin path. A `401` from device ingestion may indicate an outdated collector configuration. Use the repository [README](../README.md) for application-specific troubleshooting.
