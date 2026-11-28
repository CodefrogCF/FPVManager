import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('check_version', ROOT / 'tool/quality/check_version.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseVersionTests(unittest.TestCase):
    def test_release_metadata_agree(self):
        self.assertEqual(module.check(ROOT), [])


class VersionBumpTests(unittest.TestCase):
    def setUp(self):
        import shutil
        import tempfile
        from importlib.util import spec_from_file_location, module_from_spec
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ('pubspec.yaml', 'README.md', 'CHANGELOG.md', module.FIXTURE):
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, dest)
        # Independent from the version of the repository under test.
        (self.root / 'pubspec.yaml').write_text('version: 0.20.0+57\n', encoding='utf-8')
        (self.root / 'README.md').write_text('**Current source version:** `0.20.0+57` (published downloads may differ).\n', encoding='utf-8')
        (self.root / 'CHANGELOG.md').write_text('# Changelog\n\n## [Unreleased]\n\n- Example change\n\n## [0.20.0] - 2026-11-28\n\n- Older release\n', encoding='utf-8')
        spec = spec_from_file_location('bump_version', ROOT / 'tool/maintenance/bump_version.py')
        self.bump = module_from_spec(spec)
        spec.loader.exec_module(self.bump)

    def test_bump_preserves_binary_fixture_and_history(self):
        fixture = self.root / module.FIXTURE
        before = fixture.read_bytes()
        changes = self.bump.plan(self.root, '0.20.1', release_date='2026-11-28')
        self.assertNotIn(module.FIXTURE, changes)
        self.assertFalse((self.root / module.GENERATED).exists())
        self.bump.apply(self.root, changes)
        self.assertEqual(module.check(self.root), [])
        self.assertEqual(fixture.read_bytes(), before)
        self.assertIn('version: 0.20.1+58', (self.root / 'pubspec.yaml').read_text())
        log = (self.root / 'CHANGELOG.md').read_text()
        self.assertIn('## [0.20.1] - 2026-11-28\n\n- Example change', log)
        self.assertIn('## [0.20.0]', log)
        self.assertEqual(self.bump.plan(self.root), {})

    def test_sync_manual_pubspec_edit_keeps_build(self):
        (self.root / 'pubspec.yaml').write_text('version: 0.20.1+62\n')
        changes = self.bump.plan(self.root)
        self.assertNotIn('pubspec.yaml', changes)
        self.bump.apply(self.root, changes)
        self.assertEqual(module.check(self.root), [])
        self.assertIn('applicationBuildNumber = 62', (self.root / module.GENERATED).read_text())

    def test_corrupt_fixture_reported_without_traceback_or_writes(self):
        (self.root / module.FIXTURE).write_bytes(b'corrupt')
        self.assertTrue(any('Restore the original binary fixture' in e for e in module.check(self.root)))
        with self.assertRaisesRegex(ValueError, 'Restore the original binary fixture'):
            self.bump.plan(self.root, '0.20.1')
        self.assertEqual((self.root / 'pubspec.yaml').read_text(), 'version: 0.20.0+57\n')

    def test_version_and_build_cannot_decrease(self):
        for version, build in [('0.19.99', 58), ('0.20.1', 57), ('0.20.0', 56)]:
            with self.assertRaises(ValueError):
                self.bump.plan(self.root, version, build)

    def test_stale_generated_metadata_detected(self):
        self.bump.apply(self.root, self.bump.plan(self.root))
        (self.root / 'pubspec.yaml').write_text('version: 0.20.1+58\n')
        self.assertTrue(any('stale' in e for e in module.check(self.root)))
