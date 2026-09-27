# Build and test

Node.js 22+ builds the frontend. Python 3.11 is the Linux deployment target. The Windows collector uses Windows PowerShell 5.1. Do not commit runtime credentials, diagnostic logs or databases.

```bash
npm install
npm run build
python3.11 -m venv .venv
.venv/bin/python -m pip --isolated install --index-url https://pypi.org/simple Flask==3.1.3
.venv/bin/python -m unittest -v test_server
```

The isolated hardening tests import `server` and `test_server` from the root:

```bash
PYTHONPATH=. .venv/bin/python -m unittest discover -s maintenance/hardening -p 'test_*.py' -v
.venv/bin/python -m unittest discover -s maintenance/backup -p 'test_*.py' -v
.venv/bin/python -m unittest discover -s tests -p 'test_*.py' -v
```

On Windows, use `.venv\Scripts\python.exe` and set `$env:PYTHONPATH=(Get-Location).Path` for the hardening tests. The backup implementation's command-line entry point is Linux-only; its filesystem/SQLite tests run on Windows too.

## Offline release dependencies

`requirements-linux.lock` contains exact versions and SHA256 digests for Linux CPython 3.11 wheels. From a machine with HTTPS access to PyPI:

```bash
python -m pip --isolated download --index-url https://pypi.org/simple \
  --only-binary=:all: --platform manylinux2014_x86_64 \
  --python-version 311 --implementation cp --abi cp311 \
  --require-hashes -r requirements-linux.lock --dest vendor/wheels
python scripts/package.py
```

This creates the four release archives and `dist/SHA256SUMS.txt`. Release server archives include the prebuilt dashboard and nine offline wheels. The source repository ignores generated builds, wheel binaries and release archives; installable files live in GitHub Releases. Keep third-party notices when distributing them.

`maintenance/hardening/prepare.py` is the dependency refresh helper from the original project. It resolves newer transitive dependencies and verifies their digests against PyPI metadata. Review its results, security changes and both lock files before any new release; do not treat resolution as an automatic production update.

## Validation boundaries

The original deployment was exercised on Alibaba Cloud Linux 3 and a remote Windows PC. The public version removes hardcoded deployment addresses. Local API, session revocation, backup restore and configuration-render tests are repeatable; Windows syntax can be checked with the PowerShell parser. Fresh public-package installation, nginx/systemd behavior and user-visible Windows startup must still be checked on the target machine.

## Release checklist

1. Run the tests and frontend build.
2. Verify that public source and every archive contain no credentials, personal addresses, database files, logs, certificates or backups.
3. Build packages and verify `SHA256SUMS.txt`.
4. Test the complete installation on an isolated Linux host and Windows client before claiming new platform support.
5. Publish versioned release notes distinguishing verified behavior from remaining validation.
