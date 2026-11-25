"""Protect completeness and reproducibility of the ARB migration."""
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LocalizationCatalogTest(unittest.TestCase):
    def test_arb_parity_and_generated_bridge(self):
        result = subprocess.run(
            [sys.executable, 'tool/quality/check_localizations.py', '--check'],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


    def test_bridge_verification_ignores_formatter_only_changes(self):
        spec = importlib.util.spec_from_file_location(
            'check_localizations', ROOT / 'tool/quality/check_localizations.py'
        )
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        self.assertIsNone(module.first_token_difference(
            'case "key with spaces":\n  return l10n.label;',
            'case  "key with spaces" :\n    return\n      l10n.label ;',
        ))
        self.assertIsNone(module.first_token_difference(
            'return l10n.label(_arg(arguments, 0), _arg(arguments, 1));',
            'return l10n.label(\n  _arg(arguments, 0),\n  _arg(arguments, 1),\n);',
        ))
        self.assertIsNotNone(module.first_token_difference(
            'case "key with spaces": return l10n.label;',
            'case "keywithout spaces": return l10n.label;',
        ))
        self.assertIsNotNone(module.first_token_difference(
            'return l10n.label;', 'return l10n.other;',
        ))

    def test_de_and_en_catalogs_contain_all_legacy_entries(self):
        data = {
            language: json.loads((ROOT / f'lib/l10n/app_{language}.arb').read_text(encoding='utf-8'))
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
