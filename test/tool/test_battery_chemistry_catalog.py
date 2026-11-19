"""Guard the single-source chemistry definitions used by Dart and JavaScript."""
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BatteryCatalogTest(unittest.TestCase):
    def test_generated_dart_and_js_are_current(self):
        spec = importlib.util.spec_from_file_location(
            'battery_catalog_generator', ROOT / 'tool/generate_battery_chemistries.py'
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for file, expected in module.generate().items():
            self.assertTrue(file.is_file(), str(file))
            self.assertEqual(module.comparable_source(file.read_text(encoding='utf-8')),
                             module.comparable_source(expected), str(file))

    def test_curve_segments_are_monotonic_and_ids_unique(self):
        data = json.loads((ROOT / 'assets/battery/chemistries.json').read_text(encoding='utf-8'))
        self.assertEqual(data['schemaVersion'], 1)
        keys = set()
        for chem in data['chemistries']:
            self.assertNotIn(chem['id'], keys)
            keys.add(chem['id'])
            self.assertEqual(chem['curve'][0][0], 0)
            self.assertEqual(chem['curve'][-1][0], 1)
            self.assertGreater(chem['curve'][-1][1], chem['curve'][0][1])
            for a, b in zip(chem['curve'], chem['curve'][1:]):
                self.assertGreater(b[0], a[0]); self.assertGreaterEqual(b[1], a[1])
            self.assertLess(chem['criticalVolts'], chem['lowVolts'])
            self.assertLess(chem['lowVolts'], chem['curve'][-1][1])
            if chem['id'] in ('NiMH','NiCd'):
                self.assertIsNone(chem['maxChargeVoltsPerCell'])
                self.assertEqual(chem['chargeMethod'], 'delta_peak_temperature')
            else:
                self.assertGreaterEqual(chem['maxChargeVoltsPerCell'], chem['curve'][-1][1])
                self.assertEqual(chem['chargeMethod'], 'cc_cv')


if __name__ == '__main__':
    unittest.main()
