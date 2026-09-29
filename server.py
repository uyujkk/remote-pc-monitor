"""Single-owner, read-only PC monitoring receiver. Run behind the provided nginx config."""
import hashlib
import hmac
import json
import math
import os
import secrets
import sqlite3
import time
import uuid
from datetime import datetime, timedelta
from contextlib import contextmanager
from pathlib import Path

from flask import Flask, jsonify, request, session, send_from_directory, g
from werkzeug.security import check_password_hash

ROOT = Path(__file__).resolve().parent
LIMITS = dict(cpu=100, memory=100, gpu=100, cpuTemp=200, gpuTemp=200,
              netUp=100000, netDown=100000, memoryUsedGb=100000, memoryTotalGb=100000,
              gpuMemoryUsedGb=100000, gpuMemoryTotalGb=100000, gpuPowerW=10000,
              cpuMhz=20000, uptimeSeconds=1e10, diskRead=1e6, diskWrite=1e6)
CHART = ['cpu', 'memory', 'gpu', 'cpuTemp', 'gpuTemp', 'netUp', 'netDown', 'gpuPowerW']
HARDWARE_NAMES = ('cpuName', 'motherboardName', 'cpuTempSource')
HARDWARE_LISTS = {'memoryModules': (16, 'capacityGb', 'speedMhz'),
                  'storageModels': (16, 'sizeGb')}


def validate_sample(data):
    if not isinstance(data, dict) or set(data) - set(LIMITS) - {'sampleId', 'gpuName', 'disks', 'autoMas'} - set(HARDWARE_NAMES) - set(HARDWARE_LISTS):
        raise ValueError('Invalid fields')
    sid = str(uuid.UUID(data['sampleId']))
    clean = {}
    for key, maximum in LIMITS.items():
        value = data.get(key)
        if value is not None and (type(value) not in (float, int) or not math.isfinite(value) or not 0 <= value <= maximum):
            raise ValueError('Invalid metric')
        clean[key] = value
    name = data.get('gpuName')
    if name is not None and (not isinstance(name, str) or len(name) > 160):
        raise ValueError('Invalid GPU name')
    clean['gpuName'] = name
    for field in HARDWARE_NAMES:
        value = data.get(field)
        if value is not None and (not isinstance(value, str) or len(value) > 160):
            raise ValueError('Invalid hardware name')
        clean[field] = value
    for field, (limit, *numbers) in HARDWARE_LISTS.items():
        items = data.get(field, [])
        if not isinstance(items, list) or len(items) > limit:
            raise ValueError('Invalid hardware list')
        for item in items:
            if not isinstance(item, dict) or set(item) != {'name', *numbers}:
                raise ValueError('Invalid hardware item')
            if not isinstance(item['name'], str) or not 1 <= len(item['name']) <= 160:
                raise ValueError('Invalid hardware item name')
            for number in numbers:
                value = item[number]
                if value is not None and (type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1e7):
                    raise ValueError('Invalid hardware value')
        clean[field] = items
    disks = data.get('disks', [])
    if not isinstance(disks, list) or len(disks) > 32:
        raise ValueError('Invalid disks')
    for disk in disks:
        if not isinstance(disk, dict) or set(disk) != {'name', 'usedGb', 'totalGb'}:
            raise ValueError('Invalid disk')
        if not isinstance(disk['name'], str) or not 1 <= len(disk['name']) <= 32:
            raise ValueError('Invalid disk name')
        used, total = disk['usedGb'], disk['totalGb']
        if any(type(v) not in (int, float) or not math.isfinite(v) for v in (used, total)) or not 0 <= used <= total <= 1e8 or total == 0:
            raise ValueError('Invalid capacity')
    clean['disks'] = disks
    auto_mas = data.get('autoMas')
    if auto_mas is not None:
        required = {'state', 'version', 'activeTasks', 'scheduledCount', 'tasks', 'lastResultAt', 'lastResult'}
        if not isinstance(auto_mas, dict) or not required <= set(auto_mas) or set(auto_mas) - required - {'recentResults', 'resultCounts', 'historyUpdatedAt'}:
            raise ValueError('Invalid AUTO-MAS status')
        if auto_mas['state'] not in ('ready', 'limited', 'starting', 'unavailable', 'unsupported'):
            raise ValueError('Invalid AUTO-MAS state')
        version = auto_mas['version']
        if version is not None and (not isinstance(version, str) or len(version) > 40):
            raise ValueError('Invalid AUTO-MAS version')
        for number in ('activeTasks', 'scheduledCount'):
            if type(auto_mas[number]) is not int or not 0 <= auto_mas[number] <= 10000:
                raise ValueError('Invalid AUTO-MAS count')
        result_at, result = auto_mas['lastResultAt'], auto_mas['lastResult']
        if result_at is not None:
            if not isinstance(result_at, str) or len(result_at) != 19:
                raise ValueError('Invalid AUTO-MAS result date')
            try:
                if datetime.strptime(result_at, '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S') != result_at:
                    raise ValueError('Invalid AUTO-MAS result date')
            except ValueError as exc:
                raise ValueError('Invalid AUTO-MAS result date') from exc
        if result not in (None, 'DONE', 'ERROR') or (result_at is None) != (result is None):
            raise ValueError('Invalid AUTO-MAS result')
        tasks = auto_mas['tasks']
        if not isinstance(tasks, list) or len(tasks) > 8:
            raise ValueError('Invalid AUTO-MAS tasks')
        for task in tasks:
            if not isinstance(task, dict) or set(task) != {'mode', 'stopping', 'scripts'}:
                raise ValueError('Invalid AUTO-MAS task')
            if task['mode'] not in ('AutoProxy', 'ScriptConfig', 'Update') or type(task['stopping']) is not bool:
                raise ValueError('Invalid AUTO-MAS task state')
            scripts = task['scripts']
            if not isinstance(scripts, list) or len(scripts) > 6:
                raise ValueError('Invalid AUTO-MAS scripts')
            for script in scripts:
                if not isinstance(script, dict) or set(script) != {'name', 'status'}:
                    raise ValueError('Invalid AUTO-MAS script')
                if not all(isinstance(script[k], str) and len(script[k]) <= (80 if k == 'name' else 40) for k in ('name', 'status')):
                    raise ValueError('Invalid AUTO-MAS script value')
        results = auto_mas.get('recentResults', [])
        counts = auto_mas.get('resultCounts', {'done': 0, 'error': 0})
        if not isinstance(results, list) or len(results) > 12 or not isinstance(counts, dict) or set(counts) != {'done', 'error'}:
            raise ValueError('Invalid AUTO-MAS results')
        if any(type(counts[k]) is not int or not 0 <= counts[k] <= 100000 for k in counts):
            raise ValueError('Invalid AUTO-MAS result counts')
        for item in results:
            if not isinstance(item, dict) or set(item) != {'at', 'status', 'message'} or item['status'] not in ('DONE', 'ERROR') or not isinstance(item['message'], str) or len(item['message']) > 160:
                raise ValueError('Invalid AUTO-MAS result item')
            try:
                if datetime.strptime(item['at'], '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S') != item['at']:
                    raise ValueError('Invalid AUTO-MAS result item date')
            except (ValueError, TypeError, KeyError) as exc:
                raise ValueError('Invalid AUTO-MAS result item date') from exc
        history_updated_at = auto_mas.get('historyUpdatedAt')
        if history_updated_at is not None:
            try:
                if datetime.strptime(history_updated_at, '%Y-%m-%d %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S') != history_updated_at:
                    raise ValueError('Invalid AUTO-MAS history update date')
            except (ValueError, TypeError) as exc:
                raise ValueError('Invalid AUTO-MAS history update date') from exc
        auto_mas = {**auto_mas, 'recentResults': results, 'resultCounts': counts, 'historyUpdatedAt': history_updated_at}
    clean['autoMas'] = auto_mas
    return sid, clean


def create_app(settings=None):
    if settings is None:
        settings = json.loads(Path(os.environ.get('MONITOR_CONFIG', '/etc/remote-monitor-ecs/config.json')).read_text())
    app = Flask(__name__, static_folder=None)
    app.config.update(SECRET_KEY=settings['session_secret'], MAX_CONTENT_LENGTH=16384,
                      SESSION_COOKIE_NAME='__Host-monitor', SESSION_COOKIE_SECURE=True,
                      SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Strict',
                      PERMANENT_SESSION_LIFETIME=timedelta(hours=12), SESSION_REFRESH_EACH_REQUEST=False)
    db_path = settings['database']

    @contextmanager
    def db():
        conn = sqlite3.connect(db_path, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute('PRAGMA foreign_keys=ON')
        try:
            with conn:
                yield conn
        finally:
            conn.close()

    with db() as conn:
        conn.execute('PRAGMA journal_mode=WAL')
        conn.executescript('''
        CREATE TABLE IF NOT EXISTS device(id TEXT PRIMARY KEY,name TEXT NOT NULL,token_hash TEXT NOT NULL,last_received INTEGER,latest TEXT);
        CREATE TABLE IF NOT EXISTS samples(sample_id TEXT PRIMARY KEY,device_id TEXT NOT NULL REFERENCES device(id),t INTEGER NOT NULL,cpu REAL,memory REAL,gpu REAL,cpuTemp REAL,gpuTemp REAL,netUp REAL,netDown REAL);
        CREATE INDEX IF NOT EXISTS sample_time ON samples(t);
        CREATE TABLE IF NOT EXISTS login_attempts(ip TEXT PRIMARY KEY,started INTEGER NOT NULL,n INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS web_sessions(token_hash TEXT PRIMARY KEY,expires INTEGER NOT NULL);
        ''')
        if 'gpuPowerW' not in {row['name'] for row in conn.execute('PRAGMA table_info(samples)')}:
            conn.execute('ALTER TABLE samples ADD COLUMN gpuPowerW REAL')

    def error(message, status):
        return jsonify(error=message), status

    @app.before_request
    def protect():
        g.authenticated = False
        sid = session.get('sid')
        if isinstance(sid, str) and len(sid) == 64:
            with db() as conn:
                g.authenticated = conn.execute('SELECT 1 FROM web_sessions WHERE token_hash=? AND expires>?',
                    (hashlib.sha256(sid.encode()).hexdigest(), int(time.time()))).fetchone() is not None
        if request.method in ('POST', 'PUT', 'PATCH', 'DELETE') and request.path != '/api/ingest':
            if request.headers.get('Origin') != settings['origin']:
                return error('Invalid origin', 403)
        if request.path in ('/api/status', '/api/device', '/collector.zip') and not g.authenticated:
            return error('Sign in required', 401)

    @app.after_request
    def headers(response):
        response.headers['Cache-Control'] = 'no-store'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['Referrer-Policy'] = 'no-referrer'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
        return response

    @app.get('/api/session')
    def identity():
        return jsonify(authenticated=g.authenticated, username=settings['username'] if g.authenticated else None)

    @app.post('/api/login')
    def login():
        # nginx overwrites this header; gunicorn binds only to localhost.
        peer = request.headers.get('X-Real-IP', request.remote_addr or 'unknown')
        ip = hashlib.sha256(peer.encode()).hexdigest()
        now = int(time.time())
        with db() as conn:
            conn.execute('BEGIN IMMEDIATE')
            conn.execute('DELETE FROM login_attempts WHERE started<?', (now - 900,))
            row = conn.execute('SELECT n FROM login_attempts WHERE ip=?', (ip,)).fetchone()
            if row and row['n'] >= 8:
                return error('Too many attempts; try in 15 minutes', 429)
            conn.execute('INSERT INTO login_attempts VALUES(?,?,1) ON CONFLICT(ip) DO UPDATE SET n=n+1', (ip, now))
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return error('Invalid request', 400)
        username, password = body.get('username'), body.get('password')
        if not isinstance(username, str) or not isinstance(password, str) or len(password) > 256:
            return error('Invalid credentials', 401)
        password_ok = check_password_hash(settings['password_hash'], password)
        if username != settings['username'] or not password_ok:
            return error('Invalid credentials', 401)
        with db() as conn:
            conn.execute('DELETE FROM login_attempts WHERE ip=?', (ip,))
            conn.execute('DELETE FROM web_sessions WHERE expires<=?', (now,))
            old_sid = session.get('sid')
            if isinstance(old_sid, str):
                conn.execute('DELETE FROM web_sessions WHERE token_hash=?', (hashlib.sha256(old_sid.encode()).hexdigest(),))
            sid = secrets.token_hex(32)
            conn.execute('INSERT INTO web_sessions VALUES(?,?)', (hashlib.sha256(sid.encode()).hexdigest(), now + 43200))
        session.clear()
        session['sid'] = sid
        session.permanent = True
        return jsonify(ok=True)

    @app.post('/api/logout')
    def logout():
        sid = session.get('sid')
        if isinstance(sid, str):
            with db() as conn:
                conn.execute('DELETE FROM web_sessions WHERE token_hash=?', (hashlib.sha256(sid.encode()).hexdigest(),))
        session.clear()
        return jsonify(ok=True)

    @app.post('/api/device')
    def device():
        data = request.get_json(silent=True)
        if not isinstance(data, dict) or not isinstance(data.get('name'), str) or not 1 <= len(data['name']) <= 80:
            return error('Invalid name', 400)
        token = secrets.token_hex(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        with db() as conn:
            conn.execute('BEGIN IMMEDIATE')
            old = conn.execute('SELECT id FROM device LIMIT 1').fetchone()
            did = old['id'] if old else str(uuid.uuid4())
            conn.execute('INSERT INTO device(id,name,token_hash) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,token_hash=excluded.token_hash', (did, data['name'], token_hash))
        return jsonify(endpoint=settings['origin'] + '/api/ingest', deviceId=did, deviceToken=token, intervalSeconds=30)

    @app.post('/api/ingest')
    def ingest():
        did, auth = request.headers.get('X-Device-Id', ''), request.headers.get('Authorization', '')
        if len(did) != 36 or not auth.startswith('Bearer ') or len(auth) != 71:
            return error('Invalid device credential', 401)
        now = int(time.time() * 1000)
        with db() as conn:
            conn.execute('BEGIN IMMEDIATE')
            row = conn.execute('SELECT * FROM device WHERE id=?', (did,)).fetchone()
            if not row or not hmac.compare_digest(row['token_hash'], hashlib.sha256(auth[7:].encode()).hexdigest()):
                return error('Invalid device credential', 401)
            try:
                sid, metrics = validate_sample(request.get_json(silent=True))
            except (ValueError, TypeError, KeyError, AttributeError, OverflowError):
                return error('Invalid metrics', 400)
            if conn.execute('SELECT 1 FROM samples WHERE sample_id=?', (sid,)).fetchone():
                return jsonify(ok=True, duplicate=True)
            if row['last_received'] and now - row['last_received'] < 10000:
                return error('Wait at least 10 seconds between samples', 429)
            columns = ','.join(('sample_id', 'device_id', 't', *CHART))
            placeholders = ','.join('?' for _ in range(3 + len(CHART)))
            conn.execute(f'INSERT INTO samples ({columns}) VALUES ({placeholders})', (sid, did, now, *(metrics[k] for k in CHART)))
            metrics['t'] = now
            conn.execute('UPDATE device SET last_received=?,latest=? WHERE id=?', (now, json.dumps(metrics), did))
            conn.execute('DELETE FROM samples WHERE t<?', (now - 30 * 86400000,))
        return jsonify(ok=True, receivedAt=now)

    @app.get('/api/status')
    def status():
        try:
            hours = int(request.args.get('hours', '24'))
            bucket = {1: 30000, 24: 300000, 168: 1800000}[hours]
        except (ValueError, KeyError):
            return error('Invalid range', 400)
        now = int(time.time() * 1000)
        with db() as conn:
            conn.execute('DELETE FROM samples WHERE t<?', (now - 30 * 86400000,))
            device = conn.execute('SELECT * FROM device LIMIT 1').fetchone()
            if device is None:
                return jsonify(device=None, latest=None, history=[])
            averages = ','.join('AVG(%s) AS %s' % (k, k) for k in CHART)
            rows = conn.execute('SELECT CAST(t/? AS INTEGER)*? AS t,' + averages + ' FROM samples WHERE t>=? GROUP BY CAST(t/? AS INTEGER) ORDER BY t', (bucket, bucket, now - hours * 3600000, bucket)).fetchall()
        history = []
        for row in rows:
            if history and row['t'] - history[-1]['t'] > bucket * 1.5:
                history.append(dict(t=history[-1]['t'] + bucket, **{k: None for k in CHART}))
            history.append(dict(row))
        recent = device['last_received'] and device['last_received'] >= now - 30 * 86400000
        return jsonify(device=dict(name=device['name'], lastReceived=device['last_received']), latest=json.loads(device['latest']) if recent else None, history=history)

    @app.get('/collector.zip')
    def collector():
        return send_from_directory(ROOT / 'static', 'collector.zip', as_attachment=True)

    @app.get('/')
    def index():
        return send_from_directory(ROOT / 'static', 'index.html')

    @app.get('/assets/<path:name>')
    def assets(name):
        return send_from_directory(ROOT / 'static' / 'assets', name)

    @app.get('/healthz')
    def health():
        return jsonify(ok=True)

    @app.errorhandler(413)
    def large(_):
        return error('Payload too large', 413)

    return app
