import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'cleanup_docs', Path(__file__).resolve().parents[2] / 'tool/clean_obsolete_docs.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DocumentationUpdateTest(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[2] / '.dart_tool/documentation-cleanup-tests'
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=scratch)
        self.assertTrue(Path(self.temporary.name).resolve().is_relative_to(scratch.resolve()))
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'pubspec.yaml').write_text('name: fpvmanager\n')
        (self.root / 'docs').mkdir()
        self.old = self.root / 'docs/old.md'
        self.old.write_bytes(b'Old document\n')
        self.entry = {'path': 'docs/old.md',
                      'known_sha256': [hashlib.sha256(self.old.read_bytes()).hexdigest()]}
        self.manifest([self.entry])

    def manifest(self, entries):
        (self.root / 'docs/obsolete_files.json').write_text(
            json.dumps({'version': 1, 'files': entries}))

    def test_preview_does_not_delete_and_apply_only_removes_known_content(self):
        self.assertEqual(MODULE.cleanup(self.root), [('docs/old.md', 'remove')])
        self.assertTrue(self.old.exists())
        untouched = self.root / 'docs/current.md'
        untouched.write_text('Current guide')
        self.assertEqual(MODULE.cleanup(self.root, True), [('docs/old.md', 'removed')])
        self.assertEqual(untouched.read_text(), 'Current guide')
        self.assertEqual(MODULE.cleanup(self.root, True), [('docs/old.md', 'absent')])

    def test_locally_edited_documents_are_preserved(self):
        self.old.write_text('My local edits')
        self.assertEqual(MODULE.cleanup(self.root, True), [('docs/old.md', 'keep-local-edits')])
        self.assertEqual(self.old.read_text(), 'My local edits')

    def test_line_ending_only_difference_can_be_cleaned(self):
        self.old.write_bytes(b'Old document\r\n')
        self.assertEqual(MODULE.cleanup(self.root, True), [('docs/old.md', 'removed')])

    def test_entire_manifest_is_validated_before_deleting_files(self):
        for unsafe in ['../outside.md', 'docs/../../outside.md', 'docs\\old.md',
                       '/outside.md', 'LICENSE', 'docs/old.md:stream']:
            with self.subTest(path=unsafe):
                self.manifest([self.entry, {**self.entry, 'path': unsafe}])
                with self.assertRaises(ValueError):
                    MODULE.cleanup(self.root, True)
                self.assertTrue(self.old.exists())

    def test_unknown_project_and_missing_hashes_are_rejected(self):
        self.manifest([{'path': 'docs/old.md', 'known_sha256': []}])
        with self.assertRaises(ValueError):
            MODULE.cleanup(self.root, True)
        (self.root / 'pubspec.yaml').write_text('name: another_project\n')
        self.manifest([self.entry])
        with self.assertRaises(ValueError):
            MODULE.cleanup(self.root, True)
        self.assertTrue(self.old.exists())


if __name__ == '__main__':
    unittest.main()
