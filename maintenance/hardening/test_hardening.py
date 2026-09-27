import hashlib, sqlite3, time
from test_server import MonitorTests

class HardeningTests(MonitorTests):
    def test_logout_revokes_copied_cookie(self):
        self.login()
        cookie=self.client.get_cookie('__Host-monitor',domain='192.0.2.10').value
        other=self.app.test_client()
        other.set_cookie('__Host-monitor',cookie,domain='192.0.2.10')
        self.assertEqual(other.get('/api/status',base_url=self.origin).status_code,200)
        self.post('/api/logout',{})
        self.assertEqual(other.get('/api/status',base_url=self.origin).status_code,401)

    def test_old_cookie_rejected(self):
        cookie=self.app.session_interface.get_signing_serializer(self.app).dumps({'owner':True,'_permanent':True})
        self.client.set_cookie('__Host-monitor',cookie,domain='192.0.2.10')
        self.assertEqual(self.client.get('/api/status',base_url=self.origin).status_code,401)

    def test_expiry_and_hashed_session(self):
        self.login()
        cookie=self.client.get_cookie('__Host-monitor',domain='192.0.2.10').value
        sid=self.app.session_interface.get_signing_serializer(self.app).loads(cookie)['sid']
        with sqlite3.connect(self.tmp.name+'/test.db') as conn:
            self.assertEqual(conn.execute('SELECT token_hash FROM web_sessions').fetchone()[0],hashlib.sha256(sid.encode()).hexdigest())
            conn.execute('UPDATE web_sessions SET expires=?',(int(time.time())-1,))
        conn.close()
        self.assertFalse(self.client.get('/api/session',base_url=self.origin).json['authenticated'])

    def test_other_ips_do_not_lock_owner(self):
        with sqlite3.connect(self.tmp.name+'/test.db') as conn:
            conn.executemany('INSERT INTO login_attempts VALUES(?,?,?)',[(str(i),int(time.time()),8) for i in range(20)])
        conn.close()
        self.login()

    def test_restart_retains_device_and_history(self):
        self.login()
        cfg=self.post('/api/device',dict(name='Keep me')).json
        import uuid
        headers={'X-Device-Id':cfg['deviceId'],'Authorization':'Bearer '+cfg['deviceToken']}
        payload={'sampleId':str(uuid.uuid4()),'cpu':42,'disks':[]}
        self.assertEqual(self.client.post('/api/ingest',json=payload,headers=headers).status_code,200)
        from server import create_app
        self.app=create_app(self.settings)
        self.client=self.app.test_client()
        self.login()
        self.assertEqual(self.client.get('/api/status',base_url=self.origin).json['latest']['cpu'],42)
        with sqlite3.connect(self.tmp.name+'/test.db') as conn:
            self.assertEqual(conn.execute('SELECT count(*) FROM samples').fetchone()[0],1)
        conn.close()
        self.assertTrue(self.client.post('/api/ingest',json=payload,headers=headers).json['duplicate'])

    def test_secret_rotation_invalidates_cookie(self):
        self.login()
        cookie=self.client.get_cookie('__Host-monitor',domain='192.0.2.10').value
        from server import create_app
        changed=create_app({**self.settings,'session_secret':'new-secret-for-test'})
        client=changed.test_client()
        client.set_cookie('__Host-monitor',cookie,domain='192.0.2.10')
        self.assertEqual(client.get('/api/status',base_url=self.origin).status_code,401)

def load_tests(loader, tests, pattern):
    return loader.loadTestsFromTestCase(HardeningTests)
