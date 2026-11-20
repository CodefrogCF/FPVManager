"""Safety regression tests for checksum-gated documentation cleanup."""

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tool.cleanup_legacy_docs import clean


class CleanupLegacyDocsTest(unittest.TestCase):
    def test_dry_run_only_reports_and_apply_preserves_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'docs').mkdir()
            untouched = root / 'docs' / 'old.md'
            untouched.write_text('Original notes\n', encoding='utf-8')
            edited = root / 'docs' / 'custom.md'
            edited.write_text('Edited locally\n', encoding='utf-8')
            records = [
                {'path': 'docs/old.md', 'replacement': 'docs/archive/old.md',
                 'sha256': hashlib.sha256(untouched.read_bytes()).hexdigest()},
                {'path': 'docs/custom.md', 'replacement': 'docs/archive/custom.md',
                 'sha256': hashlib.sha256(b'Original\n').hexdigest()},
            ]
            (root / 'docs' / 'obsolete_files.json').write_text(
                json.dumps({'files': records}), encoding='utf-8')
            first = clean(root=root)
            self.assertEqual(first['would_remove'], 1)
            self.assertEqual(first['preserved'], 1)
            self.assertTrue(untouched.exists())
            self.assertTrue(edited.exists())
            after = clean(root=root, apply=True)
            self.assertEqual(after['removed'], 1)
            self.assertEqual(after['preserved'], 1)
            self.assertFalse(untouched.exists())
            self.assertTrue(edited.exists())

    def test_rejects_retired_paths_outside_docs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'docs').mkdir()
            (root / 'docs' / 'obsolete_files.json').write_text(
                json.dumps({'files': [
                    {'path': 'docs/../../secrets.txt', 'replacement': 'docs/archive/notes.md',
                     'sha256': '0' * 64}
                ]}), encoding='utf-8')
            with self.assertRaises(ValueError):
                clean(root=root, apply=True)


if __name__ == '__main__':
    unittest.main()
