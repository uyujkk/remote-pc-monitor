"""Online SQLite backup; root-only archives, verified before publication and rotation."""
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sqlite3
import tarfile
import tempfile
import time
from datetime import datetime, timezone

PATTERN = re.compile(r'^monitor-\d{8}T\d{6}Z-[0-9a-f]{8}\.tar\.gz$')

def run(root=Path('/'), output=Path('/var/backups/remote-monitor-daily'), now=None):
    now = time.time() if now is None else now
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    if output.is_symlink():
        raise RuntimeError('Backup directory must not be a symlink')
    os.chmod(output, 0o700)
    config_path = root / 'etc/remote-monitor-ecs/config.json'
    config_bytes = config_path.read_bytes()
    config = json.loads(config_bytes)
    database = root / config['database'].lstrip('/')
    if not database.is_file():
        raise RuntimeError('Configured database missing; no backup produced')
    name = 'monitor-' + datetime.fromtimestamp(now, timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + os.urandom(4).hex() + '.tar.gz'
    final = output / name
    with tempfile.TemporaryDirectory(prefix='.building-', dir=output) as work:
        work = Path(work)
        snapshot = work / 'monitor.sqlite3'
        source = sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True, timeout=30)
        target = sqlite3.connect(snapshot)
        try:
            source.backup(target, pages=256, sleep=0.1)
            if target.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise RuntimeError('Database integrity check failed')
        finally:
            target.close()
            source.close()
        # Reject a simultaneous password/configuration change; next run can retry.
        if config_path.read_bytes() != config_bytes:
            raise RuntimeError('Configuration changed during backup; retry')
        files = {'database/monitor.sqlite3': snapshot, 'etc/remote-monitor-ecs/config.json': config_path}
        for relative in ('etc/nginx/nginx.conf', 'etc/nginx/conf.d/remote-monitor-http.conf',
                         'etc/nginx/conf.d/remote-monitor-https.conf',
                         'etc/systemd/system/remote-monitor-ecs.service',
                         'etc/systemd/system/remote-monitor-cert-renew.service',
                         'etc/systemd/system/remote-monitor-cert-renew.timer'):
            path = root / relative
            if path.is_file():
                files[relative] = path
        for relative in ('etc/systemd/system/remote-monitor-ecs.service.d', 'opt/remote-monitor-ecs/static'):
            directory = root / relative
            if directory.exists():
                for path in directory.rglob('*'):
                    if path.is_symlink():
                        raise RuntimeError('Unexpected symlink: ' + str(path))
                    if path.is_file():
                        files[path.relative_to(root).as_posix()] = path
        for filename in ('server.py', 'requirements.txt', 'reset_password.py'):
            path = root / 'opt/remote-monitor-ecs' / filename
            if path.is_file():
                files[path.relative_to(root).as_posix()] = path
        archive = work / 'archive.tar.gz'
        manifest = {}
        with tarfile.open(archive, 'w:gz') as tar:
            for relative, path in sorted(files.items()):
                data = config_bytes if path == config_path else path.read_bytes()
                manifest[relative] = hashlib.sha256(data).hexdigest()
                info = tarfile.TarInfo(relative)
                info.size = len(data)
                info.mode = 0o600
                tar.addfile(info, io.BytesIO(data))
            data = json.dumps({'created_utc': datetime.fromtimestamp(now, timezone.utc).isoformat(), 'sha256': manifest}, indent=2).encode()
            info = tarfile.TarInfo('manifest.json')
            info.size = len(data)
            info.mode = 0o600
            tar.addfile(info, io.BytesIO(data))
        with tarfile.open(archive, 'r:gz') as tar:
            for relative, digest in manifest.items():
                if hashlib.sha256(tar.extractfile(relative).read()).hexdigest() != digest:
                    raise RuntimeError('Archive verification failed')
        os.chmod(archive, 0o600)
        os.replace(archive, final)
    # Only this tool's named archives; never traverse directories or delete other backups.
    for old in output.iterdir():
        if old != final and PATTERN.fullmatch(old.name) and not old.is_symlink() and old.is_file() and old.stat().st_mtime < now - 14 * 86400:
            old.unlink()
    print('BACKUP_OK ' + str(final))
    return final

if __name__ == '__main__':
    if os.geteuid() != 0:
        raise SystemExit('Run as root')
    import fcntl
    os.umask(0o077)
    with open('/run/remote-monitor-backup.lock', 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run()
