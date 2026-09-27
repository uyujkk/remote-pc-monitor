"""Run as root on ECS. Preserves device credentials and history."""
import getpass, json, os, secrets, subprocess
from pathlib import Path
from werkzeug.security import generate_password_hash
path = Path('/etc/remote-monitor-ecs/config.json')
if os.geteuid() != 0:
    raise SystemExit('Run as root.')
password = getpass.getpass('New password (12-256 characters): ')
if not 12 <= len(password) <= 256 or password != getpass.getpass('Repeat password: '):
    raise SystemExit('Password length or confirmation invalid; unchanged.')
data = json.loads(path.read_text())
data['password_hash'] = generate_password_hash(password)
data['session_secret'] = secrets.token_hex(32)
stat = path.stat()
tmp = path.with_name('config.' + secrets.token_hex(8) + '.tmp')
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as stream:
    json.dump(data, stream)
    stream.flush()
    os.fsync(stream.fileno())
os.chown(tmp, stat.st_uid, stat.st_gid)
os.chmod(tmp, 0o640)
os.replace(tmp, path)
subprocess.run(['systemctl', 'restart', 'remote-monitor-ecs'], check=True)
print('Password changed. All previous browser cookies invalidated. Device token unchanged.')
