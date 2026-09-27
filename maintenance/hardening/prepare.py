"""Build an offline Linux CPython 3.11 dependency bundle, verified against PyPI."""
import hashlib, json, pathlib, subprocess, sys, urllib.request
root = pathlib.Path(__file__).resolve().parent
wheels = root / 'wheels'
wheels.mkdir(exist_ok=True)
subprocess.run([sys.executable, '-m', 'pip', '--isolated', 'download', '--index-url', 'https://pypi.org/simple', '--only-binary=:all:', '--platform', 'manylinux2014_x86_64', '--python-version', '311', '--implementation', 'cp', '--abi', 'cp311', '--dest', str(wheels), 'Flask==3.1.3', 'gunicorn==26.0.0'], check=True)
lines = []
for wheel in sorted(wheels.glob('*.whl')):
    name, version = wheel.name.split('-')[:2]
    with urllib.request.urlopen(f'https://pypi.org/pypi/{name}/{version}/json', timeout=30) as response:
        meta = json.load(response)
    digest = hashlib.sha256(wheel.read_bytes()).hexdigest()
    assert any(item['filename'] == wheel.name and item['digests']['sha256'] == digest for item in meta['urls']), wheel.name
    if meta.get('vulnerabilities'):
        raise RuntimeError(f'PyPI reports vulnerabilities: {name} {version}')
    lines.append(f'{name}=={version} --hash=sha256:{digest}')
(root / 'requirements.lock').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('Verified', len(lines), 'wheels against HTTPS PyPI metadata.')
