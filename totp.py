"""Small RFC 6238 TOTP verifier using Python's standard library."""
import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote


def new_secret():
    return base64.b32encode(secrets.token_bytes(20)).decode('ascii').rstrip('=')


def code_for_step(secret, step):
    key = base64.b32decode(secret + '=' * (-len(secret) % 8), casefold=True)
    digest = hmac.new(key, struct.pack('>Q', step), hashlib.sha1).digest()
    offset = digest[-1] & 15
    value = struct.unpack('>I', digest[offset:offset + 4])[0] & 0x7fffffff
    return f'{value % 1000000:06d}'


def matching_step(secret, code, now=None, last_step=-1):
    if not isinstance(code, str) or len(code) != 6 or not code.isascii() or not code.isdigit():
        return None
    current = int((time.time() if now is None else now) // 30)
    for step in (current, current - 1, current + 1):
        if step > last_step and hmac.compare_digest(code_for_step(secret, step), code):
            return step
    return None


def provisioning_uri(secret, username):
    label = quote(f'Remote Monitor:{username}', safe='')
    return f'otpauth://totp/{label}?secret={secret}&issuer=Remote%20Monitor&algorithm=SHA1&digits=6&period=30'
