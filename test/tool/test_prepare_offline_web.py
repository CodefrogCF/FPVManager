import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('prepare_offline_web',ROOT/'tool/prepare_offline_web.py')
MODULE=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class OfflineManifestTest(unittest.TestCase):
    def test_snapshot_is_deterministic_and_changes_with_application_content(self):
        with tempfile.TemporaryDirectory(prefix='fpv-offline-web-') as directory:
            root=Path(directory)
            for name in ['index.html','flutter_bootstrap.js','main.dart.js','offline_service_worker.js','offline_maps.js']:
                (root/name).write_text('test '+name,encoding='utf-8')
            (root/'main.dart.js.map').write_text('debug',encoding='utf-8')
            first=MODULE.prepare(root)
            self.assertEqual(MODULE.prepare(root),first)
            self.assertNotIn('main.dart.js.map',[a['path'] for a in first['assets']])
            for asset in first['assets']:
                data=(root/asset['path']).read_bytes()
                self.assertEqual(asset['sha256'],hashlib.sha256(data).hexdigest())
                self.assertEqual(asset['size'],len(data))
            (root/'main.dart.js').write_text('new application',encoding='utf-8')
            self.assertNotEqual(MODULE.prepare(root)['version'],first['version'])

    def test_source_or_incomplete_build_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='fpv-offline-web-') as directory:
            with self.assertRaises(ValueError):
                MODULE.prepare(Path(directory))

    def test_personal_files_cannot_be_published_as_offline_application_assets(self):
        with tempfile.TemporaryDirectory(prefix='fpv-offline-web-') as directory:
            root=Path(directory)
            for name in ['index.html','flutter_bootstrap.js','main.dart.js','offline_service_worker.js','offline_maps.js']:
                (root/name).write_text('test',encoding='utf-8')
            (root/'personal.fpvbackup').write_bytes(b'private')
            with self.assertRaisesRegex(ValueError,'Personal'):
                MODULE.prepare(root)


if __name__=='__main__':
    unittest.main()
