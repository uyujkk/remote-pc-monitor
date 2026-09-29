# Remote PC Monitor

Self-hosted monitoring for one Windows PC. A small tray collector sends hardware and optional AUTO-MAS status to your Linux server over HTTPS; the private dashboard works in a browser on your phone or another computer. The project does not provide remote control.

**[简体中文](README.zh-CN.md)** · [Latest release](https://github.com/uyujkk/remote-pc-monitor/releases/latest) · [Security](SECURITY.md)

## Choose your guide

| Your situation | English | 简体中文 |
| --- | --- | --- |
| First installation, with the shortest deployment path | [Quick deployment](docs/quick-start.md) | [快速部署](docs/quick-start.zh-CN.md) |
| Existing server, update or recovery, all options and explanations | [Complete manual](docs/manual.md) | [完整手册](docs/manual.zh-CN.md) |
| HTTPS certificate and renewal | [TLS guide](docs/tls.md) | [HTTPS 证书与续期](docs/tls.zh-CN.md) |
| A domain managed by Cloudflare | [Cloudflare guide](docs/cloudflare.md) | [Cloudflare 接入](docs/cloudflare.zh-CN.md) |
| Optional AUTO-MAS task history | [AUTO-MAS guide](docs/auto-mas.md) | [AUTO-MAS 接入](docs/auto-mas.zh-CN.md) |

**Already running a monitor?** Use the **update** procedure in the [complete manual](docs/manual.md#update-an-original-deployment). The fresh-install script refuses an existing configuration. The server and Windows collector are separate; update the part that changed. Download an archive and its `SHA256SUMS.txt` from the **same Release** before installing.

## What you get

- CPU, memory, GPU, supported temperatures and GPU power, disk, network and uptime. Hardware models are shown without collecting serial numbers. Unavailable sensors display “—”.
- Sidebar views for Overview, Hardware, Trends, Health & Stability, Automation, Results and Security. One-hour, 24-hour and seven-day trends are available; samples are retained for about 30 days.
- A resource-pressure health score and the Windows Reliability Monitor stability index. WHEA event counts are limited to errors recorded by Windows; zero does not prove that hardware is healthy.
- Optional read-only AUTO-MAS status and recent results. An online PC or an earlier successful result does not prove that a script is currently progressing.
- Chinese and English in the website and Windows tray collector. The collector can start after its Windows user signs in.
- HTTPS, password and device-token hashing, revocable sessions, rate limits, optional authenticator codes, and optional encryption of AUTO-MAS result **message text** before upload. See [security boundaries](SECURITY.md).
- Optional verified daily SQLite backups. Copy backups off the server separately.

```text
Windows tray collector -- HTTPS --> nginx :443 --> Gunicorn 127.0.0.1:18081
                                        ^                   |
                                        |                SQLite
                              Phone / desktop browser
```

The intended setup is **one administrator, one monitored PC and one receiver**. It requires an x86-64 Linux server with systemd, Python 3.11 and nginx; a reachable public IPv4 address or hostname with a trusted matching HTTPS certificate; and Windows 10/11 with Windows PowerShell 5.1. Keep port **18081 private**. Ports **443** and, when using HTTP-01 certificate renewal, **80** must be reachable. The original deployment was validated on Alibaba Cloud Linux 3; other distributions need their own checks.

## Release files

| Asset | Use |
| --- | --- |
| `remote-monitor-ecs.tar.gz` | Fresh Linux server installation |
| `windows-tray-collector.zip` | Windows tray collector |
| `remote-monitor-hardening-v2.tar.gz` | Update an existing `/opt/remote-monitor-ecs` deployment |
| `remote-monitor-backup-v1.tar.gz` | Optional daily backup timer |
| `SHA256SUMS.txt` | SHA-256 hashes for the four archives |

Public archives exclude personal server addresses, account configuration, passwords, device tokens, databases, backups and certificate keys. A downloaded connection file (`config.json`) **does** contain credentials; keep it private and never commit it.

The `main` branch can contain changes that have **not yet been packaged into a Release**. For installation or updates, use the release archive and matching checksum rather than assuming the latest source code is already deployed.

For source layout, builds and tests, see [development](docs/development.md). Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
