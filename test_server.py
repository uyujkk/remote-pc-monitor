import json
import secrets
import tempfile
import unittest
import uuid
from pathlib import Path
from werkzeug.security import generate_password_hash
from server import create_app

class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.origin='https://192.0.2.10'
        self.settings=dict(session_secret=secrets.token_hex(32),username='tester',password_hash=generate_password_hash('test-password-123'),origin=self.origin,database=str(Path(self.tmp.name)/'test.db'))
        self.app=create_app(self.settings)
        self.client=self.app.test_client()
    def tearDown(self): self.tmp.cleanup()
    def post(self,path,data,**kwargs):
        return self.client.post(path,json=data,base_url=self.origin,headers={'Origin':self.origin,**kwargs})
    def login(self):
        r=self.post('/api/login',dict(username='tester',password='test-password-123'))
        self.assertEqual(r.status_code,200)
        self.assertIn('Secure',r.headers['Set-Cookie']);self.assertIn('HttpOnly',r.headers['Set-Cookie'])
    def test_auth_and_csrf(self):
        self.assertEqual(self.client.get('/api/status').status_code,401)
        self.assertEqual(self.client.get('/collector.zip').status_code,401)
        self.assertEqual(self.client.post('/api/login',json={}).status_code,403)
        self.assertEqual(self.post('/api/login',dict(username='tester',password='bad')).status_code,401)
        self.login()
        self.assertEqual(self.client.get('/api/status',base_url=self.origin).json['device'],None)
        self.post('/api/logout',{})
        self.assertEqual(self.client.get('/api/status',base_url=self.origin).status_code,401)
    def test_metrics_and_rotation(self):
        self.login()
        cfg=self.post('/api/device',dict(name='Windows')).json
        headers={'X-Device-Id':cfg['deviceId'],'Authorization':'Bearer '+cfg['deviceToken']}
        self.assertNotIn('gatewayToken',cfg)
        sample=dict(sampleId=str(uuid.uuid4()),cpu=40,memory=60,gpu=None,disks=[])
        def ingest(body):return self.client.post('/api/ingest',json=body,headers=headers)
        self.assertEqual(ingest({**sample,'cpu':101}).status_code,400)
        self.assertEqual(ingest({**sample,'cpu':True}).status_code,400)
        self.assertEqual(ingest({**sample,'x':'unknown'}).status_code,400)
        self.assertEqual(ingest(sample).status_code,200)
        self.assertTrue(ingest(sample).json['duplicate'])
        self.assertEqual(ingest({**sample,'sampleId':str(uuid.uuid4())}).status_code,429)
        for h in (1,24,168):
            r=self.client.get('/api/status?hours='+str(h),base_url=self.origin)
            self.assertEqual(r.status_code,200);self.assertEqual(r.json['latest']['cpu'],40);self.assertIsNone(r.json['latest']['gpu'])
        self.assertEqual(self.client.get('/api/status?hours=3',base_url=self.origin).status_code,400)
        self.post('/api/device',dict(name='new'))
        self.assertEqual(ingest(sample).status_code,401)
    def test_login_throttle_and_size(self):
        self.assertEqual(self.post('/api/login',{'password':'x'*17000}).status_code,413)
        for _ in range(7):self.assertEqual(self.post('/api/login',dict(username='x',password='bad')).status_code,401)
        self.assertEqual(self.post('/api/login',dict(username='x',password='bad')).status_code,429)

if __name__=='__main__':unittest.main()
