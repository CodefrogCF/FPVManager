"""The docs checker must support ZIP overlays and validate maintained links."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'docs_ci_check', Path(__file__).resolve().parents[2] / 'tool/check_docs.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DocumentationRelocationCITest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'docs/developer').mkdir(parents=True)
        (self.root / 'assets/licenses').mkdir(parents=True)
        for name in MODULE.ROOT_DOCS:
            (self.root / name).write_text('# Project\n', encoding='utf-8')
        (self.root / 'assets/licenses/README.md').write_text('# License\n', encoding='utf-8')
        (self.root / 'docs/README.md').write_text('# Docs\n', encoding='utf-8')
        (self.root / 'docs/developer/architecture.md').write_text('# Architecture\n', encoding='utf-8')
        (self.root / 'docs/developer/globe_bridge.md').write_text('# Globe bridge\n', encoding='utf-8')
        for filename, text in {
            'cesium_assets.md': '[architecture](architecture.md)',
            'performance.md': '[architecture](architecture.md) [bridge](globe_bridge.md)',
            'offline_swiss_tunnel_index.md': '[architecture](architecture.md)',
        }.items():
            (self.root / 'docs' / filename).write_text(text, encoding='utf-8')
            (self.root / 'docs/developer' / filename).write_text(
                '[architecture](architecture.md)\n', encoding='utf-8')

    def test_old_docs_do_not_fail_without_cleanup_manifest(self):
        count, errors = MODULE.check(self.root)
        self.assertEqual(errors, [])
        self.assertEqual(count, 12)

    def test_current_doc_still_fails_for_broken_link(self):
        (self.root / 'docs/developer/performance.md').write_text(
            '[broken](nonexistent.md)\n', encoding='utf-8')
        _, errors = MODULE.check(self.root)
        self.assertIn('docs/developer/performance.md: missing or retired link: nonexistent.md', errors)

    def test_current_doc_may_not_link_to_retired_duplicate(self):
        (self.root / 'docs/README.md').write_text(
            '[old](cesium_assets.md)\n', encoding='utf-8')
        _, errors = MODULE.check(self.root)
        self.assertIn('docs/README.md: missing or retired link: cesium_assets.md', errors)

    def test_unmoved_root_doc_is_still_checked(self):
        (self.root / 'docs/standalone.md').write_text('[broken](none.md)', encoding='utf-8')
        _, errors = MODULE.check(self.root)
        self.assertIn('docs/standalone.md: missing or retired link: none.md', errors)


if __name__ == '__main__':
    unittest.main()
