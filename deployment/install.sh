#!/usr/bin/env bash
set -euo pipefail
export PYTHONUTF8=1
cd -- "$(dirname -- "$0")"
if [ "$(id -u)" -ne 0 ]; then echo 'Run as root.'; exit 1; fi
export MONITOR_ORIGIN="${MONITOR_ORIGIN:?Set MONITOR_ORIGIN=https://your-host}"
export MONITOR_CERTIFICATE="${MONITOR_CERTIFICATE:-/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem}"
export MONITOR_PRIVATE_KEY="${MONITOR_PRIVATE_KEY:-/etc/letsencrypt/live/remote-monitor-ip/privkey.pem}"
python3.11 render_config.py
test -f "$MONITOR_CERTIFICATE"
test -f "$MONITOR_PRIVATE_KEY"
if [ -f /etc/remote-monitor-ecs/config.json ]; then echo 'Existing configuration found. Use the hardening update package.'; exit 1; fi
command -v python3.11 >/dev/null
command -v nginx >/dev/null
if systemctl is-active --quiet remote-monitor-ecs; then echo 'Already running. Stop here; use an update procedure.'; exit 1; fi
if ss -lnt 'sport = :18081' | tail -n +2 | grep -q .; then echo 'Port 18081 is occupied; no changes made.'; exit 1; fi
getent passwd remotemon >/dev/null || useradd --system --home-dir /var/lib/remote-monitor-ecs --shell /sbin/nologin remotemon
install -d -m 755 /opt/remote-monitor-ecs
install -d -o remotemon -g remotemon -m 700 /var/lib/remote-monitor-ecs
install -d -o root -g remotemon -m 750 /etc/remote-monitor-ecs
cp server.py requirements-linux.lock setup_account.py /opt/remote-monitor-ecs/
cp -R static /opt/remote-monitor-ecs/
python3.11 -m venv /opt/remote-monitor-ecs/venv
/opt/remote-monitor-ecs/venv/bin/python -m pip --isolated install --no-index --find-links wheels --require-hashes -r requirements-linux.lock
if [ ! -f /etc/remote-monitor-ecs/config.json ]; then
  /opt/remote-monitor-ecs/venv/bin/python /opt/remote-monitor-ecs/setup_account.py
fi
chown root:remotemon /etc/remote-monitor-ecs/config.json
chmod 640 /etc/remote-monitor-ecs/config.json
cat > /etc/systemd/system/remote-monitor-ecs.service <<'UNIT'
[Unit]
Description=Private PC monitoring dashboard
After=network.target

[Service]
User=remotemon
Group=remotemon
WorkingDirectory=/opt/remote-monitor-ecs
Environment=PYTHONUTF8=1
Environment=MONITOR_CONFIG=/etc/remote-monitor-ecs/config.json
ExecStart=/opt/remote-monitor-ecs/venv/bin/gunicorn --bind 127.0.0.1:18081 --workers 1 --threads 4 --timeout 30 --error-logfile - server:create_app()
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
CapabilityBoundingSet=
RestrictSUIDSGID=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
ReadWritePaths=/var/lib/remote-monitor-ecs

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now remote-monitor-ecs
ready=0
for attempt in $(seq 1 15); do
  if curl --noproxy '*' -fsS http://127.0.0.1:18081/healthz >/dev/null; then ready=1; break; fi
  sleep 1
done
if [ "$ready" != 1 ]; then systemctl status remote-monitor-ecs --no-pager; exit 1; fi
# SELinux requires this boolean for nginx to connect to a localhost application.
if command -v getenforce >/dev/null && [ "$(getenforce)" = Enforcing ]; then
  setsebool -P httpd_can_network_connect 1
fi
conf=/etc/nginx/conf.d/remote-monitor-https.conf
backup="${conf}.before-app.$(date +%Y%m%d%H%M%S).bak"
if [ -f "$conf" ]; then cp -p "$conf" "$backup"; fi
cp nginx-https.conf "$conf"
if ! nginx -t; then if [ -f "$backup" ]; then cp -p "$backup" "$conf"; else rm -f -- "$conf"; fi; echo 'Nginx config restored.'; exit 1; fi
if ! systemctl reload nginx; then if [ -f "$backup" ]; then cp -p "$backup" "$conf"; else rm -f -- "$conf"; fi; nginx -t && systemctl reload nginx; exit 1; fi
monitor_host=$(python3.11 -c 'import os, urllib.parse; print(urllib.parse.urlsplit(os.environ["MONITOR_ORIGIN"]).hostname)')
curl --noproxy '*' -fsS --max-time 15 --resolve "$monitor_host:443:127.0.0.1" "$MONITOR_ORIGIN/healthz"
echo
echo "Installed. Open $MONITOR_ORIGIN/ and sign in."
echo 'Do not open port 18081 in the security group. Only nginx needs access.'
