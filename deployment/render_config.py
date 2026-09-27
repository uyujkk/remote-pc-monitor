"""Validate a deployment origin before inserting it into nginx configuration."""
import os, re
from pathlib import Path
from urllib.parse import urlsplit

def render(origin, certificate, private_key, template):
    url=urlsplit(origin)
    host=url.hostname or ''
    if (url.scheme!='https' or url.username or url.password or url.port not in (None,443)
        or url.path or url.query or url.fragment or not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?',host)):
        raise ValueError('MONITOR_ORIGIN must be https://HOST with no path, query, userinfo or nonstandard port')
    for value in (certificate,private_key):
        if not re.fullmatch(r'/[A-Za-z0-9_./-]+',value):
            raise ValueError('Certificate paths must be absolute, without spaces or nginx metacharacters')
    return template.replace('@HOST@',host).replace('@CERTIFICATE@',certificate).replace('@PRIVATE_KEY@',private_key)

if __name__=='__main__':
    root=Path(__file__).resolve().parent
    output=render(os.environ['MONITOR_ORIGIN'],os.environ.get('MONITOR_CERTIFICATE','/etc/letsencrypt/live/remote-monitor-ip/fullchain.pem'),os.environ.get('MONITOR_PRIVATE_KEY','/etc/letsencrypt/live/remote-monitor-ip/privkey.pem'),(root/'nginx-https.conf.in').read_text())
    (root/'nginx-https.conf').write_text(output)
