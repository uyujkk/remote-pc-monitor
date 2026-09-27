import getpass
import json
import os
import re
import secrets
from pathlib import Path
from werkzeug.security import generate_password_hash

target = Path('/etc/remote-monitor-ecs/config.json')
if target.exists():
    raise SystemExit('Account already exists; no changes made.')
username = input('Login username [admin]: ').strip() or 'admin'
if not re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', username):
    raise SystemExit('Use 1-64 English letters, digits, dots, underscores or hyphens.')
password = getpass.getpass('Set password (12+ characters, hidden): ')
if not 12 <= len(password) <= 256:
    raise SystemExit('Password must contain 12-256 characters.')
if password != getpass.getpass('Repeat password: '):
    raise SystemExit('Passwords do not match.')
config = dict(username=username, password_hash=generate_password_hash(password),
              session_secret=secrets.token_hex(32), origin=os.environ['MONITOR_ORIGIN'],
              database='/var/lib/remote-monitor-ecs/monitor.sqlite3')
fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o640)
with os.fdopen(fd, 'w') as stream:
    json.dump(config, stream)
print('Account created. Password is not stored in plaintext.')
