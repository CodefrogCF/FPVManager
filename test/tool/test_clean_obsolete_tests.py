"""The test-retirement script cannot delete arbitrary or locally changed files."""
from __future__ import annotations
import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('test_retirement', ROOT / 'tool/clean_obsolete_tests.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ObsoleteTestCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'test/js').mkdir(parents=True)
        (self.root / 'pubspec.yaml').write_text('name: fpvmanager\n')

    def _manifest(self, entries):
        (self.root/'test/obsolete_tests.json').write_text(json.dumps({
            'version':1,'files':entries}))

    @staticmethod
    def _entry(name, contents=b'old'):
        return {'path':name,'known_sha256':[hashlib.sha256(contents).hexdigest()]}

    def test_exact_known_file_removed_only_with_apply(self):
        name='test/js/scenery_r27_old.test.cjs'; target=self.root/name
        target.write_bytes(b'old');self._manifest([self._entry(name)])
        self.assertEqual(MODULE.cleanup(self.root), [(name,'remove')])
        self.assertTrue(target.exists())
        self.assertEqual(MODULE.cleanup(self.root,True),[(name,'removed')])
        self.assertFalse(target.exists())

    def test_local_edits_are_retained(self):
        name='test/js/scenery_r28_old.test.cjs'; target=self.root/name
        target.write_bytes(b'changed');self._manifest([self._entry(name)])
        self.assertEqual(MODULE.cleanup(self.root,True),[(name,'modified')])
        self.assertEqual(target.read_bytes(),b'changed')

    def test_rejects_unrelated_or_parent_paths_before_any_deletion(self):
        valid='test/js/scenery_r19_old.test.cjs';(self.root/valid).write_bytes(b'old')
        for bad in ['test/js/flight_physics.test.cjs', 'test/js/../../lib/main.dart',
                    'test/js/scenery_site_integrity.test.cjs']:
            self._manifest([self._entry(valid),self._entry(bad)])
            with self.assertRaises(ValueError):MODULE.cleanup(self.root,True)
            self.assertTrue((self.root/valid).exists())

    def test_duplicate_manifest_entries_fail_closed(self):
        name='test/js/scenery_r20_old.test.cjs';(self.root/name).write_bytes(b'old')
        self._manifest([self._entry(name),self._entry(name)])
        with self.assertRaises(ValueError):MODULE.cleanup(self.root,True)
        self.assertTrue((self.root/name).exists())


if __name__=='__main__':unittest.main()
