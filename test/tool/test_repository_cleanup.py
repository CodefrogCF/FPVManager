import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'repository_cleanup', ROOT / 'tool/maintenance/cleanup_repository.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
LAYOUT_SPEC = importlib.util.spec_from_file_location(
    'repository_layout', ROOT / 'tool/quality/check_repository_layout.py')
LAYOUT = importlib.util.module_from_spec(LAYOUT_SPEC)
LAYOUT_SPEC.loader.exec_module(LAYOUT)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class RepositoryCleanupTest(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / '.dart_tool/repository-cleanup-tests'
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.assertTrue(self.root.is_relative_to(scratch.resolve()))
        (self.root / 'pubspec.yaml').write_text('name: fpvmanager\n')
        (self.root / 'tool/maintenance').mkdir(parents=True)
        (self.root / 'docs/developer/obsolete').mkdir(parents=True)
        self.old = self.root / 'docs/developer/obsolete/old.md'
        self.new = self.root / 'docs/developer/current.md'
        self.old.write_bytes(b'old\n')
        self.new.write_bytes(b'current\n')
        self.entry = {'path': self.old.relative_to(self.root).as_posix(),
                      'known_sha256': [digest(b'old\n')],
                      'replacement': {'path': self.new.relative_to(self.root).as_posix(),
                                      'known_sha256': [digest(b'current\n')]}}
        self.manifest([self.entry])

    def manifest(self, entries):
        (self.root / MODULE.MANIFEST).write_text(json.dumps({'version': 1, 'files': entries}))

    def test_preview_apply_idempotence_and_only_empty_directory_removal(self):
        other = self.old.parent / 'private.txt'
        other.write_text('keep')
        self.assertEqual(MODULE.cleanup(self.root), [(self.entry['path'], 'remove')])
        self.assertTrue(self.old.is_file())
        self.assertEqual(MODULE.cleanup(self.root, True), [(self.entry['path'], 'removed')])
        self.assertEqual(other.read_text(), 'keep')
        self.assertEqual(MODULE.cleanup(self.root, True), [(self.entry['path'], 'absent')])

    def test_empty_obsolete_subdirectory_is_removed_but_docs_root_stays(self):
        MODULE.cleanup(self.root, True)
        self.assertFalse(self.old.parent.exists())
        self.assertTrue((self.root / 'docs').is_dir())

    def test_local_edits_are_retained(self):
        self.old.write_text('local edit')
        self.assertEqual(MODULE.cleanup(self.root, True), [(self.entry['path'], 'keep-local-edits')])
        self.assertEqual(self.old.read_text(), 'local edit')

    def test_line_ending_conversion_does_not_prevent_verified_cleanup(self):
        self.old.write_bytes(b'old\r\n')
        self.new.write_bytes(b'current\r\n')
        self.assertEqual(MODULE.cleanup(self.root, True), [(self.entry['path'], 'removed')])

    def test_replacement_must_be_installed_before_any_file_is_removed(self):
        self.manifest([self.entry, {**self.entry, 'path': 'tool/legacy.py',
            'replacement': {'path': 'tool/quality/missing.py', 'known_sha256': [digest(b'new')]}}])
        (self.root / 'tool/legacy.py').write_bytes(b'old\n')
        with self.assertRaisesRegex(ValueError, 'replacement first'):
            MODULE.cleanup(self.root, True)
        self.assertTrue(self.old.is_file())

    def test_modified_replacement_is_not_accepted(self):
        self.new.write_text('local replacement')
        with self.assertRaises(ValueError):
            MODULE.cleanup(self.root, True)
        self.assertTrue(self.old.is_file())

    def test_a_replacement_cannot_itself_be_removed(self):
        self.manifest([self.entry, {'path': self.entry['replacement']['path'],
            'known_sha256': [digest(b'current\n')],
            'replacement': {'path': self.entry['path'], 'known_sha256': [digest(b'old\n')]}}])
        with self.assertRaisesRegex(ValueError, 'replacement must not also be retired'):
            MODULE.cleanup(self.root, True)
        self.assertTrue(self.old.is_file())
        self.assertTrue(self.new.is_file())

    def test_all_entries_are_validated_before_deletion(self):
        for path in ['../outside.md', '/tmp/file', 'tool/../pubspec.yaml',
                     'tool\\bad.py', 'C:/outside.py', 'lib/main.dart']:
            with self.subTest(path=path):
                self.manifest([self.entry, {**self.entry, 'path': path}])
                with self.assertRaises(ValueError):
                    MODULE.cleanup(self.root, True)
                self.assertTrue(self.old.is_file())

    def test_duplicate_and_invalid_hash_entries_are_rejected(self):
        for entries in [[self.entry, self.entry], [{**self.entry, 'known_sha256': []}],
                        [{**self.entry, 'known_sha256': ['bad']}]]:
            self.manifest(entries)
            with self.assertRaises(ValueError):
                MODULE.cleanup(self.root, True)
            self.assertTrue(self.old.is_file())

    def test_wrong_project_is_rejected(self):
        (self.root / 'pubspec.yaml').write_text('name: unrelated\n')
        with self.assertRaises(ValueError):
            MODULE.cleanup(self.root, True)
        self.assertTrue(self.old.is_file())

    def test_absent_old_file_does_not_require_an_unchanged_future_replacement(self):
        self.old.unlink()
        self.new.write_text('future version')
        self.assertEqual(MODULE.cleanup(self.root, True), [(self.entry['path'], 'absent')])


class RepositoryLayoutTest(unittest.TestCase):
    def test_actual_repository_uses_valid_groups_and_paths(self):
        self.assertEqual(LAYOUT.check(ROOT), [])

    def test_new_flat_tool_and_stale_ci_command_are_detected(self):
        scratch = ROOT / '.dart_tool/repository-layout-tests'
        scratch.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch) as name:
            root = Path(name)
            (root / 'tool/maintenance').mkdir(parents=True)
            (root / 'tool/maintenance/repository_cleanup.json').write_text(json.dumps({'version': 1, 'files': []}))
            (root / 'tool/README.md').write_text('# Tools\n')
            (root / 'tool/stray.py').write_text('')
            (root / '.github/workflows').mkdir(parents=True)
            (root / '.github/workflows/check.yml').write_text('run: python tool/missing.py\n')
            errors = LAYOUT.check(root)
            self.assertTrue(any('Unclassified tool' in error for error in errors), errors)
            self.assertTrue(any('stale tool path' in error for error in errors), errors)


if __name__ == '__main__':
    unittest.main()
