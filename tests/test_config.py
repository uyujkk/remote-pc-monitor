import unittest
from deployment.render_config import render

class ConfigTests(unittest.TestCase):
    def test_valid_domain_and_ip(self):
        for origin in ('https://monitor.example.com','https://192.0.2.10'):
            result=render(origin,'/etc/cert/fullchain.pem','/etc/cert/privkey.pem','@HOST@ @CERTIFICATE@ @PRIVATE_KEY@')
            self.assertNotIn('@',result)
            self.assertIn('/etc/cert/fullchain.pem',result)
    def test_reject_unsafe_origin_and_paths(self):
        for origin in ('http://example.com','https://example.com/','https://user@example.com','https://example.com:8443','https://example.com/?q=x','https://example.com;return'):
            with self.assertRaises(ValueError):render(origin,'/etc/cert.pem','/etc/key.pem','@HOST@')
        with self.assertRaises(ValueError):render('https://example.com','/etc/cert;bad','/etc/key','')
