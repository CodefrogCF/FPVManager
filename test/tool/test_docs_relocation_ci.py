"""Canonical documentation checks tolerate ZIP overlays, not stale links."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'docs_ci_check', Path(__file__).resolve().parents[2] / 'tool/check_docs.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DocumentationIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'docs/developer').mkdir(parents=True)
        (self.root / 'assets/licenses').mkdir(parents=True)
        (self.root / 'web/assets/scenery').mkdir(parents=True)
        for name in MODULE.ROOT_DOCS:
            (self.root / name).write_text('# ' + name + '\n', encoding='utf-8')
        (self.root / 'assets/licenses/README.md').write_text('# License\n', encoding='utf-8')
        (self.root / 'web/assets/scenery/ATTRIBUTION.md').write_text('# Original scan attribution\n', encoding='utf-8')
        (self.root / 'docs/README.md').write_text('# Docs\n', encoding='utf-8')
        (self.root / 'docs/developer/architecture.md').write_text('# Architecture\n', encoding='utf-8')
        (self.root / 'docs/developer/globe_bridge.md').write_text('# Globe bridge\n', encoding='utf-8')
        for filename in ('cesium_assets.md', 'performance.md', 'offline_swiss_tunnel_index.md'):
            (self.root / 'docs/developer' / filename).write_text(
                '# ' + filename + '\n[architecture](architecture.md)\n', encoding='utf-8')
        self.old = self.root / 'docs/cesium_assets.md'
        self.old.write_text('# Old redundant guide\n')
        (self.root / 'docs/obsolete_files.json').write_text(json.dumps({
            'version': 1, 'files': [{'path': 'docs/cesium_assets.md',
                 'replacement': 'docs/developer/cesium_assets.md',
                 'known_sha256': [hashlib.sha256(self.old.read_bytes()).hexdigest()]}]}))

    def test_retired_duplicate_in_overlay_is_ignored(self):
        count, errors = MODULE.check(self.root)
        self.assertEqual(errors, [])
        self.assertEqual(count, 13)

    def test_current_doc_still_fails_for_broken_link(self):
        (self.root / 'docs/developer/performance.md').write_text('[broken](nonexistent.md)\n')
        _, errors = MODULE.check(self.root)
        self.assertIn('docs/developer/performance.md: missing or retired link: nonexistent.md', errors)

    def test_current_doc_may_not_link_to_retired_duplicate(self):
        (self.root / 'docs/README.md').write_text('[old](cesium_assets.md)\n')
        _, errors = MODULE.check(self.root)
        self.assertIn('docs/README.md: missing or retired link: cesium_assets.md', errors)

    def test_duplicate_current_guide_is_rejected(self):
        (self.root / 'docs/duplicate.md').write_text('# Architecture\n')
        _, errors = MODULE.check(self.root)
        self.assertTrue(any('duplicate guide content' in e for e in errors), errors)

    def test_unmoved_root_doc_is_checked(self):
        (self.root / 'docs/standalone.md').write_text('[broken](none.md)')
        _, errors = MODULE.check(self.root)
        self.assertIn('docs/standalone.md: missing or retired link: none.md', errors)


if __name__ == '__main__':
    unittest.main()
