#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" = 0
backup=$(readlink -f -- "${1:?Pass the backup directory printed by upgrade.sh}")
case "$backup" in /var/backups/remote-monitor-hardening/update-*) ;; *) echo 'Invalid backup path'; exit 1;; esac
test -f "$backup/ready"
systemctl stop remote-monitor-ecs
cp -p "$backup/server.py" /opt/remote-monitor-ecs/server.py
cp -p "$backup/nginx.conf" /etc/nginx/conf.d/remote-monitor-https.conf
drop=/etc/systemd/system/remote-monitor-ecs.service.d/50-hardening.conf
if [ -f "$backup/dropin.conf" ]; then cp -p "$backup/dropin.conf" "$drop"; else rm -f -- "$drop"; fi
systemctl daemon-reload
nginx -t
systemctl start remote-monitor-ecs
systemctl reload nginx
echo 'Previous application restored. Database and device history retained.'
