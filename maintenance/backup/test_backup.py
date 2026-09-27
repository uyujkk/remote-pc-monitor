import contextlib, io, json, os, sqlite3, tarfile, tempfile, time, unittest
from pathlib import Path
from backup import run

class BackupTests(unittest.TestCase):
    def test_snapshot_contents_rotation_and_missing_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/'host'; out=Path(tmp)/'archives'
            cfg=root/'etc/remote-monitor-ecs/config.json';cfg.parent.mkdir(parents=True)
            cfg.write_text(json.dumps({'database':'/var/lib/remote-monitor-ecs/monitor.sqlite3','session_secret':'test-only'}))
            db=root/'var/lib/remote-monitor-ecs/monitor.sqlite3';db.parent.mkdir(parents=True)
            conn=sqlite3.connect(db)
            conn.execute('PRAGMA journal_mode=WAL')
            conn.execute('CREATE TABLE sample(value)');conn.execute('INSERT INTO sample VALUES(42)');conn.commit()
            out.mkdir()
            old=out/'monitor-20200101T000000Z-12345678.tar.gz';old.write_bytes(b'old')
            unrelated=out/'keep-me.tar.gz';unrelated.write_bytes(b'keep')
            os.utime(old,(1,1))
            try:
                with contextlib.redirect_stdout(io.StringIO()): archive=run(root,out)
                self.assertFalse(old.exists());self.assertTrue(unrelated.exists())
                with tarfile.open(archive) as tar:
                    data=tar.extractfile('database/monitor.sqlite3').read()
                    self.assertEqual(json.load(tar.extractfile('etc/remote-monitor-ecs/config.json'))['session_secret'],'test-only')
                restored=Path(tmp)/'restore.db';restored.write_bytes(data)
                check=sqlite3.connect(restored)
                try:self.assertEqual(check.execute('SELECT value FROM sample').fetchone()[0],42)
                finally:check.close()
            finally:conn.close()
            db.unlink()
            before=set(out.iterdir())
            with self.assertRaises(RuntimeError):run(root,out)
            self.assertEqual(before,set(out.iterdir()))

if __name__=='__main__':unittest.main()
