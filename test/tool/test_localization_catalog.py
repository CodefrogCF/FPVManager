"""Protect completeness and reproducibility of the ARB migration."""
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LocalizationCatalogTest(unittest.TestCase):
    def test_arb_parity_and_generated_bridge(self):
        subprocess.run(
            [sys.executable, 'tool/check_localizations.py', '--check'],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

    def test_de_and_en_catalogs_contain_all_legacy_entries(self):
        data = {
            language: json.loads((ROOT / f'lib/l10n/app_{language}.arb').read_text())
            for language in ('en', 'de')
        }
        legacy = [
            k[1:]
            for k, metadata in data['en'].items()
            if k.startswith('@')
            and not k.startswith('@@')
            and metadata['description'].startswith('Legacy key: ')
        ]
        self.assertGreater(len(legacy), 1600)
        for key in legacy:
            self.assertIn(key, data['en'])
            self.assertIn(key, data['de'])


if __name__ == '__main__':
    unittest.main()
