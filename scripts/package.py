"""Build allowlisted, credential-free release assets from the curated source tree."""
from pathlib import Path
import hashlib, shutil, tarfile, zipfile
root=Path(__file__).resolve().parents[1]
out=root/'dist';out.mkdir(exist_ok=True)
collector=out/'windows-tray-collector.zip'
names=['Collect.ps1','AutoMas.ps1','Diagnostics.ps1','Diagnose.ps1','Monitor.ps1','启动监控.vbs','诊断连接.cmd','README.txt']
with zipfile.ZipFile(collector,'w',zipfile.ZIP_DEFLATED) as z:
    for name in names:z.write(root/'collector'/name,name)
shutil.copyfile(collector,root/'static/collector.zip')
def archive(name,prefix,entries):
    with tarfile.open(out/name,'w:gz') as tar:
        for source,dest in entries:
            info=tar.gettarinfo(str(source),prefix+'/'+dest)
            info.mode=0o644;info.uid=info.gid=0;info.uname=info.gname='root'
            with source.open('rb') as stream:tar.addfile(info,stream)
wheels=[(p,'wheels/'+p.name) for p in sorted((root/'vendor/wheels').glob('*.whl'))]
if len(wheels)!=9:raise RuntimeError('Expected verified wheels; see docs/development.md')
static=[(p,p.relative_to(root).as_posix()) for p in (root/'static').rglob('*') if p.is_file()]
common=[(root/n,n) for n in ('server.py','setup_account.py','requirements-linux.lock','README.md')]
deployment=[(root/'deployment'/n,n) for n in ('install.sh','render_config.py','nginx-https.conf.in')]
archive('remote-monitor-ecs.tar.gz','remote-monitor-ecs',common+deployment+static+wheels)
hard=root/'maintenance/hardening'
entries=[(hard/n,n) for n in ('upgrade.sh','rollback.sh','reset_password.py','test_hardening.py','requirements.lock')]
entries += [(root/n,n) for n in ('server.py','test_server.py')]
entries += static
entries += [(root/'deployment'/n,n) for n in ('render_config.py','nginx-https.conf.in')]
archive('remote-monitor-hardening-v2.tar.gz','remote-monitor-hardening-v2',entries+wheels)
archive('remote-monitor-backup-v1.tar.gz','remote-monitor-backup-v1',[(root/'maintenance/backup'/n,n) for n in ('backup.py','install.sh')])
assets=[collector,*(out/n for n in ('remote-monitor-ecs.tar.gz','remote-monitor-hardening-v2.tar.gz','remote-monitor-backup-v1.tar.gz'))]
(out/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in assets),encoding='utf-8')
print((out/'SHA256SUMS.txt').read_text())
