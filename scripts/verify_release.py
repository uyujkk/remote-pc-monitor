"""Check package contents and checksums before publishing; never print secret values."""
import hashlib, io, re, tarfile, zipfile
from pathlib import Path, PurePosixPath

root=Path(__file__).resolve().parents[1]
dist=root/'dist'
blocked_names={'config.json','config.protected.xml','collector.log','diagnostic.txt','monitor.sqlite3','privkey.pem'}
secret_patterns=[rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',rb'gh[pousr]_[A-Za-z0-9]{30,}',rb'github_pat_[A-Za-z0-9_]{30,}']
count=0
def inspect(name,data):
    global count
    path=PurePosixPath(name)
    if path.name in blocked_names or '..' in path.parts or path.is_absolute():
        raise RuntimeError('Disallowed archive member: '+name)
    if name.endswith('.whl'):return  # Unmodified upstream dependencies, verified by requirements.lock.
    if name.endswith('.zip'):
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for member in z.infolist():inspect(member.filename,z.read(member))
        return
    if any(re.search(pattern,data) for pattern in secret_patterns):
        raise RuntimeError('Potential credential in '+name)
    count+=1
for line in (dist/'SHA256SUMS.txt').read_text().splitlines():
    digest,name=line.split('  ',1);path=dist/name
    if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise RuntimeError('Checksum mismatch: '+name)
    if name.endswith('.zip'):inspect(name,path.read_bytes())
    else:
        with tarfile.open(path) as tar:
            for member in tar.getmembers():
                if not member.isfile():raise RuntimeError('Unexpected archive entry: '+member.name)
                inspect(member.name,tar.extractfile(member).read())
print('Release checks passed:',count,'application files; checksums match.')
