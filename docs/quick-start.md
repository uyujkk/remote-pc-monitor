# Quick deployment: one Windows PC and one Linux server

[简体中文](quick-start.zh-CN.md) · [Complete manual](manual.md) · [Repository home](../README.md) · [Latest release](https://github.com/uyujkk/remote-pc-monitor/releases/latest)

This page is for a **fresh installation**. If `/etc/remote-monitor-ecs/config.json` already exists or `remote-monitor-ecs` is running, follow the [existing-deployment update](manual.md#update-an-original-deployment). Do not run `install.sh` again.

## 0. Check the environment

- An x86-64 Alibaba Cloud Linux 3 server with root access, systemd, Python 3.11 and nginx. Other distributions need independent validation.
- One Windows 10/11 PC with Windows PowerShell 5.1.
- Your own public IPv4 address **or** DNS hostname, reachable from the Windows PC and the viewing device, with a **trusted HTTPS certificate** covering that address. A domain is optional.
- Inbound TCP **443** in the cloud security group and active host firewall zone; **80** if using HTTP-01 to issue or renew the certificate. Preserve SSH access. **Keep 18081 private.**

For a Cloudflare-managed domain, read the [Cloudflare options](cloudflare.md) first. `monitor.example.com` below is a placeholder, not a working service address.

In a root terminal on the Linux host, install the prerequisites, then complete [certificate setup and renewal](tls.md):

```bash
dnf install -y python3.11 nginx
```

## 1. Install the server

Create a directory on the server:

```bash
mkdir -p /root/remote-monitor-install
```

Download `remote-monitor-ecs.tar.gz` and `SHA256SUMS.txt` from the **same** [GitHub Release](https://github.com/uyujkk/remote-pc-monitor/releases/latest). Upload both into `/root/remote-monitor-install/`, then run:

```bash
cd /root/remote-monitor-install
sha256sum --check --ignore-missing SHA256SUMS.txt
```

**Run the next block only if the check prints `remote-monitor-ecs.tar.gz: OK`.** If a file is missing or the hash fails, download and upload it again.

```bash
tar -xzf remote-monitor-ecs.tar.gz
cd remote-monitor-ecs
```

Run `/opt/remote-monitor-certbot/bin/certbot certificates` to find the real certificate paths. Replace the sample hostname below with **your own address covered by the certificate**. For an IP certificate, use `https://YOUR_PUBLIC_IP` as `MONITOR_ORIGIN`. Adjust the paths as needed:

```bash
export MONITOR_ORIGIN='https://monitor.example.com'
export MONITOR_CERTIFICATE='/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem'
export MONITOR_PRIVATE_KEY='/etc/letsencrypt/live/remote-monitor-ip/privkey.pem'
bash install.sh
```

Set a login name and a **12–256 character** password when prompted. Password input is hidden. `MONITOR_ORIGIN` must be an HTTPS origin on port 443, without a trailing slash or path. The installer does not edit your cloud security group or host firewall.

## 2. Connect the Windows PC

1. On that PC, open and sign in to your `MONITOR_ORIGIN`. Choose **Connect PC**. Download `windows-tray-collector.zip` (or get it from the same Release) and the site-generated `config.json`.
2. Extract the ZIP into a permanent folder, for example `D:\RemotePcMonitor`. Stop any older collector or scheduled task first.
3. Double-click `启动监控.vbs`. In the GUI, choose **Import configuration** and select `config.json` from **your own server**.
4. Wait for **Upload succeeded**, then minimize to the tray. Right-click the tray icon to **Exit and stop collecting**. Starting after this Windows user signs in is optional.

`config.json` contains the device token and result-summary key. **Never publish or commit it.** Delete it securely after import or keep it offline. Generating another connection file rotates the token and stops an old collector configuration from uploading.

## 3. Verify and continue

On the server:

```bash
systemctl is-active remote-monitor-ecs
nginx -t
curl --fail "$MONITOR_ORIGIN/healthz"
```

Expected results are `active`, a successful nginx syntax check and `{"ok":true}`. Open the dashboard **from the monitored Windows PC** and confirm fresh data appears; a loopback-only check on the server does not prove external reachability.

On the site's **Security** page, download the script-summary recovery key and keep it offline. An authenticator code is optional. See the [daily backup](manual.md#daily-backups) and [operations and troubleshooting](manual.md#operations-and-troubleshooting) sections of the complete manual for ongoing use and updates.
