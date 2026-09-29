#!/usr/bin/env bash
set -euo pipefail
export PYTHONUTF8=1
umask 022
cd -- "$(dirname -- "$0")"
test "$(id -u)" = 0
test -f /opt/remote-monitor-ecs/server.py
test -f /etc/remote-monitor-ecs/config.json
systemctl is-active --quiet remote-monitor-ecs
nginx -t
MONITOR_ORIGIN=$(python3.11 -c 'import json; print(json.load(open("/etc/remote-monitor-ecs/config.json"))["origin"])')
export MONITOR_ORIGIN
python3.11 render_config.py
MONITOR_HOST=$(python3.11 -c 'import os, urllib.parse; print(urllib.parse.urlsplit(os.environ["MONITOR_ORIGIN"]).hostname)')
stamp=$(date +%Y%m%d-%H%M%S)-$$
venv=/opt/remote-monitor-ecs/venv-hardened-$stamp
python3.11 -m venv "$venv"
"$venv/bin/python" -m pip --isolated install --no-index --find-links wheels --require-hashes -r requirements.lock
"$venv/bin/python" -m unittest -v test_server test_hardening
"$venv/bin/gunicorn" --version
backup=/var/backups/remote-monitor-hardening/update-$stamp
install -d -m 700 /var/backups/remote-monitor-hardening "$backup"
cp -p /opt/remote-monitor-ecs/server.py "$backup/server.py"
if [ -f /opt/remote-monitor-ecs/totp.py ]; then cp -p /opt/remote-monitor-ecs/totp.py "$backup/totp.py"; fi
if [ -d /opt/remote-monitor-ecs/static ]; then cp -a /opt/remote-monitor-ecs/static "$backup/static"; fi
cp -p /etc/nginx/conf.d/remote-monitor-https.conf "$backup/nginx.conf"
cp /etc/remote-monitor-ecs/config.json "$backup/config.json"
chmod 600 "$backup/config.json"
drop=/etc/systemd/system/remote-monitor-ecs.service.d/50-hardening.conf
if [ -f "$drop" ]; then cp -p "$drop" "$backup/dropin.conf"; fi
touch "$backup/ready"
rollback() { echo "Upgrade failed; restoring $backup"; bash ./rollback.sh "$backup"; }
trap 'rollback; exit 1' ERR INT TERM
systemctl stop remote-monitor-ecs
"$venv/bin/python" - "$backup" <<'PY'
import json, sqlite3, sys, os
settings=json.load(open('/etc/remote-monitor-ecs/config.json'))
dest=sys.argv[1]+'/monitor.sqlite3'
with sqlite3.connect(settings['database']) as source, sqlite3.connect(dest) as target:
    source.backup(target)
    assert target.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
os.chmod(dest,0o600)
PY
install -m 644 server.py /opt/remote-monitor-ecs/server.py
install -m 644 totp.py /opt/remote-monitor-ecs/totp.py
install -d -m 755 /opt/remote-monitor-ecs/static
cp -a static/. /opt/remote-monitor-ecs/static/
install -m 600 reset_password.py /opt/remote-monitor-ecs/reset_password.py
install -d -m 755 /etc/systemd/system/remote-monitor-ecs.service.d
cat > "$drop" <<UNIT
[Service]
ExecStart=
ExecStart=$venv/bin/gunicorn --bind 127.0.0.1:18081 --workers 1 --threads 4 --timeout 30 --error-logfile - server:create_app()
CapabilityBoundingSet=
RestrictSUIDSGID=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
UNIT
install -m 644 nginx-https.conf /etc/nginx/conf.d/remote-monitor-https.conf
nginx -t
systemctl daemon-reload
systemctl start remote-monitor-ecs
ready=0
for attempt in $(seq 1 20); do
  if curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:18081/healthz >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
test "$ready" = 1
systemctl reload nginx
curl --noproxy '*' -fsS --max-time 10 --resolve "$MONITOR_HOST:443:127.0.0.1" "$MONITOR_ORIGIN/healthz"
code=$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' --max-time 10 --resolve "$MONITOR_HOST:443:127.0.0.1" "$MONITOR_ORIGIN/api/status")
test "$code" = 401
trap - ERR INT TERM
printf '\nHARDENING_OK\nBackup: %s\nPassword reset: %s/bin/python /opt/remote-monitor-ecs/reset_password.py\nRollback: bash %s/rollback.sh %s\n' "$backup" "$venv" "$PWD" "$backup"
