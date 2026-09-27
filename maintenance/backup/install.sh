#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
test "$(id -u)" = 0
test -f /etc/remote-monitor-ecs/config.json
command -v python3.11 >/dev/null
# Prove a real backup succeeds before enabling the schedule.
PYTHONUTF8=1 python3.11 backup.py
install -d -m 700 /opt/remote-monitor-backup
install -m 600 backup.py /opt/remote-monitor-backup/backup.py
cat > /etc/systemd/system/remote-monitor-backup.service <<'UNIT'
[Unit]
Description=Verified private monitor database and configuration backup
[Service]
Type=oneshot
User=root
UMask=0077
Environment=PYTHONUTF8=1
ExecStart=/usr/bin/python3.11 /opt/remote-monitor-backup/backup.py
TimeoutStartSec=15min
Nice=10
IOSchedulingClass=idle
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
UNIT
# Use the actual Python path on this host.
monitor_python=$(command -v python3.11)
sed -i "s|ExecStart=/usr/bin/python3.11 |ExecStart=$monitor_python |" /etc/systemd/system/remote-monitor-backup.service
cat > /etc/systemd/system/remote-monitor-backup.timer <<'UNIT'
[Unit]
Description=Daily monitor backup at 04:15 Asia/Shanghai
[Timer]
OnCalendar=*-*-* 04:15:00 Asia/Shanghai
RandomizedDelaySec=10min
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now remote-monitor-backup.timer
systemctl start remote-monitor-backup.service
systemctl list-timers remote-monitor-backup.timer --no-pager
echo BACKUP_SETUP_OK
