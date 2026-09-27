# Remote PC Monitor

Self-hosted hardware monitoring for a Windows PC, with a browser dashboard and a small Windows tray collector. The receiver runs on your own Linux server. View it from a phone or another computer without installing a viewer.

**[Download the latest release](https://github.com/uyujkk/remote-pc-monitor/releases/latest)** · [TLS setup](docs/tls.md) · [Development](docs/development.md) · [Security](SECURITY.md)

The current dashboard and tray UI are **Chinese**. This README provides English installation and usage instructions, including translations of the important buttons.

## Features

- CPU, memory, GPU, temperature (where supported), disk capacity/IO, network throughput and uptime.
- One-hour, 24-hour and seven-day charts; 30-day sample retention.
- Hidden collector process, visible tray icon, start/stop controls and optional startup after Windows sign-in.
- HTTPS receiver, hashed account passwords and device tokens, revocable browser sessions, request validation and rate limits.
- Optional daily SQLite backups with integrity checks, archive hash verification and 14-day retention.
- No external CDN required to display the dashboard; no remote command execution or game input features.

```text
Windows tray collector -- HTTPS --> nginx :443 --> Gunicorn 127.0.0.1:18081
                                        ^                   |
                                        |                SQLite
                              Phone / desktop browser
```

## Release files

| File | Purpose |
| --- | --- |
| `remote-monitor-ecs.tar.gz` | Fresh server installation, including hardened code, built dashboard and offline Linux dependencies |
| `windows-tray-collector.zip` | Windows collector; also downloadable after signing into the dashboard |
| `remote-monitor-hardening-v2.tar.gz` | Update an existing deployment that uses the original `/opt/remote-monitor-ecs` layout; not needed after a fresh install from this release |
| `remote-monitor-backup-v1.tar.gz` | Optional daily backup service and timer |
| `SHA256SUMS.txt` | Checksums for all four installable archives |

These are reusable public packages rebuilt from the running project's code. They contain **no personal server address, account configuration, password, device token, certificate private key, database or user backup**. They are not byte-for-byte copies of earlier private delivery archives.

## Requirements

- Linux x86-64 with systemd, Python 3.11 and nginx. The original deployment was validated on Alibaba Cloud Linux 3; other distributions require independent validation.
- A public IPv4 address or DNS hostname reachable from both the monitored PC and the viewing device.
- A trusted HTTPS certificate for that IP/hostname. You can use a domain or a supported IP certificate; see [TLS setup](docs/tls.md).
- Inbound TCP **443** for the dashboard and upload API; **80** for HTTP-01 certificate validation/renewal. Keep **18081 private**. Preserve existing SSH access.
- Windows 10/11, Windows PowerShell 5.1 and .NET/WinForms. Optional sensor support is described below.

The packaged Python wheels target **CPython 3.11 on Linux x86-64**. Do not install them on ARM or a different Python ABI.

## Install the server

Run server commands as root in a trusted terminal. No Node.js build is required when using a release archive.

1. Install the prerequisites. On Alibaba Cloud Linux 3:

   ```bash
   dnf install -y python3.11 nginx
   ```

2. Set up your certificate, HTTP challenge endpoint and automatic renewal using [the TLS guide](docs/tls.md). Confirm that the certificate matches the address you will use.

3. Download `remote-monitor-ecs.tar.gz` and `SHA256SUMS.txt` from the same release; upload them to the server. Verify the archive:

   ```bash
   sha256sum --check --ignore-missing SHA256SUMS.txt
   ```

4. Extract and install. Replace the example hostname with **your own** DNS name or IPv4 address. The certificate paths below match the TLS guide.

   ```bash
   tar -xzf remote-monitor-ecs.tar.gz
   cd remote-monitor-ecs
   export MONITOR_ORIGIN='https://monitor.example.com'
   export MONITOR_CERTIFICATE='/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem'
   export MONITOR_PRIVATE_KEY='/etc/letsencrypt/live/remote-monitor-ip/privkey.pem'
   bash install.sh
   ```

   `MONITOR_ORIGIN` must be an HTTPS origin on port 443, without a trailing slash or path. IPv6 literals and custom HTTPS ports are not supported by this installer.

5. Enter a username and a 12–256 character password. Password input is hidden. Open your configured origin and sign in.

The installer uses local, hash-locked wheels; creates the `remotemon` service account; installs code under `/opt/remote-monitor-ecs`; stores private configuration under `/etc/remote-monitor-ecs`; and stores SQLite data under `/var/lib/remote-monitor-ecs`. nginx terminates TLS; Gunicorn listens only on `127.0.0.1:18081`. On an enforcing SELinux host, the installer enables `httpd_can_network_connect` for nginx proxying.

**Do not rerun the fresh installer against an existing deployment.** It refuses existing configuration. It does not change your cloud security group, SSH, FRP or system firewall. Allow 80/443 in the correct cloud and host firewall rules yourself; do not disable the firewall.

## Connect the Windows PC

1. Sign into the dashboard and click **接入电脑** (Connect PC).
2. Download the collector ZIP and generate/download `config.json`. Generating a new configuration rotates the device token; old collectors using the previous token will stop authenticating.
3. Extract the collector into a permanent directory, such as `D:\RemotePcMonitor`. Stop any previous collector first.
4. Double-click **启动监控.vbs**. Click **导入接入配置** (Import configuration) and select the downloaded `config.json` from your own server.
5. Wait for **上报成功** (Upload succeeded), then click **最小化到托盘** (Minimize to tray). Closing the window also hides it in the tray.
6. Optionally enable **登录 Windows 后自动启动并收到托盘** to start after this user signs into Windows. Test it at your next convenient reboot/sign-in.

Double-click the tray icon to reopen. Choose **退出并停止采集** from its right-click menu to exit and stop collecting. **查看日志** opens the collector log; **打开监控网站** opens the host from your imported configuration.

The collector stores imported credentials using Windows DPAPI for the current user and machine. The original downloaded JSON remains plaintext; remove it or store it securely. Never commit it to GitHub. Import only a configuration from a server you control: importing starts uploads to that address.

The collector normally reports every 30 seconds. The dashboard marks it offline after roughly two minutes without a sample. This is a hardware heartbeat, **not proof that a game or automation task completed successfully**.

If VBScript is disabled, see the alternative PowerShell shortcut in [collector/README.txt](collector/README.txt). The scripts are not code-signed.

## Daily backups

After the site works, upload and install the optional backup archive:

```bash
tar -xzf remote-monitor-backup-v1.tar.gz
cd remote-monitor-backup-v1
bash install.sh
```

Wait for `BACKUP_SETUP_OK`. Backups run daily at **04:15–04:25 Asia/Shanghai** and are stored in `/var/backups/remote-monitor-daily/`. Archive timestamps use UTC. New backups are verified before archives older than 14 days are removed. Files are root-only. The installation can create two initial backups while validating the script and service.

Backups include a consistent SQLite snapshot, account settings, application code/static assets and selected nginx/systemd files. They are **not full-machine images** and do not include Python environments, TLS private keys or FRP data. Protect them as credentials. Download a copy to a separate machine periodically; off-server backup is not automated.

```bash
systemctl list-timers remote-monitor-backup.timer --no-pager
journalctl -u remote-monitor-backup.service -n 30 --no-pager
```

Before restoring, stop the receiver, preserve the current data/configuration, recreate the runtime and TLS setup, and restore matching configuration and database files with their original permissions. Do not unpack an archive over a live database or restore stale WAL files. Validate restoration in isolation first.

## Update an original deployment

The separate hardening archive preserves the original account, device token and history and requires the existing standard directory layout. It reads the HTTPS origin from the server's own configuration. If certificate paths differ from the defaults above, export `MONITOR_CERTIFICATE` and `MONITOR_PRIVATE_KEY` before running it.

```bash
tar -xzf remote-monitor-hardening-v2.tar.gz
cd remote-monitor-hardening-v2
bash upgrade.sh
```

The updater installs offline dependencies and runs isolated tests before switching. It briefly restarts the receiver, creates a root-only rollback backup, and attempts rollback on failure. On success, it prints `HARDENING_OK`, a backup path, a password-reset command and a rollback command. Keep this output. Sign in again afterward; the Windows collector does not need a new key.

## Operations and troubleshooting

```bash
systemctl status remote-monitor-ecs --no-pager
journalctl -u remote-monitor-ecs -n 50 --no-pager
nginx -t
curl --fail https://monitor.example.com/healthz
```

- `/healthz` should return `{"ok":true}`; an unauthenticated `/api/status` should return HTTP 401.
- **Missing sensors:** the dashboard shows a dash. NVIDIA metrics use `nvidia-smi`; optional LibreHardwareMonitor WMI provides additional readings. No sensor driver is installed automatically.
- **HTTP 401 from the collector:** check whether a new configuration rotated its key. Reimport the current configuration without sharing it.
- **HTTP 429:** stop duplicate collectors or repeated login attempts and wait. A shared public IP also shares nginx rate limits.
- **Timeout:** check address, network reachability, nginx, the cloud security group and the active firewalld zone. Test HTTPS from the actual Windows PC.
- **Diagnostics:** `诊断连接.cmd` deliberately sends an invalid device credential. A device-authentication 401 indicates the endpoint is reachable; it does not mean your saved token is invalid.
- **Untrusted/expired certificate:** repair issuance or renewal; do not disable certificate verification.

## Scope and limitations

One administrator and one monitored PC per instance. No multi-user tenancy, MFA, remote control, email/push alerts, automatic task-progress integration, offline upload queue or independent collector watchdog. Only the first GPU is displayed. Virtual network interfaces may cause aggregate throughput double-counting. Capacity uses GiB while the UI abbreviates it as GB; MB/s is decimal.

The deployed predecessor was verified end-to-end on ECS and Windows. This public release adds configurable endpoints and reusable packaging, with local tests; it has not been freshly deployed to every supported environment. Security hardening is not a penetration-test certification. Keep the OS, SSH, FRP and dependencies maintained separately.

## Source layout

```text
server.py                 Flask API, authentication and SQLite storage
web/                      React dashboard, types and CSS
collector/                PowerShell collector, WinForms tray UI and VBS launcher
deployment/               Fresh installation and nginx template rendering
maintenance/hardening/    Existing-install updater, rollback and password reset
maintenance/backup/       Online SQLite backup and daily systemd timer
scripts/                  Frontend build and release packaging
docs/                     TLS and development instructions
```

See [development instructions](docs/development.md) for building and testing. Third-party dependencies retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
