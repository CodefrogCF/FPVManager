#!/usr/bin/env python3
"""Generate Dart and JS chemistry constants from one reviewed model catalog."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / 'assets/battery/chemistries.json'
DART = ROOT / 'lib/core/models/generated/battery_chemistries.g.dart'
JAVASCRIPT = ROOT / 'web/features/flight/physics/battery_chemistries.generated.js'


def generate() -> dict[Path, str]:
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    assert data['schemaVersion'] == 1
    records = data['chemistries']
    assert len({r['id'] for r in records}) == len(records)
    for record in records:
        curve = record['curve']
        assert curve[0][0] == 0 and curve[-1][0] == 1
        assert all(b[0] > a[0] and b[1] >= a[1] for a, b in zip(curve, curve[1:]))
        assert all(record[k] > 0 for k in ('nominalVolts', 'lowVolts', 'criticalVolts', 'resistanceOhmsAt1Ah', 'referenceContinuousC'))
        assert record['criticalVolts'] < record['lowVolts'] < curve[-1][1]
        assert record['chargeMethod'] in ('cc_cv', 'delta_peak_temperature')
        if record['chargeMethod'] == 'cc_cv':
            assert record['maxChargeVoltsPerCell'] is not None
            assert record['maxChargeVoltsPerCell'] >= curve[-1][1]
        else:
            assert record['maxChargeVoltsPerCell'] is None  # no voltage-only termination for nickel packs
    dart = [
        '// GENERATED from assets/battery/chemistries.json; do not edit by hand.',
        '// Run: python tool/data/generate_battery_chemistries.py',
        "import '../battery_chemistry.dart';", '',
        'const batteryChemistryPresets = <BatteryChemistryDefinition>[',
    ]
    for item in records:
        q = lambda v: json.dumps(v, ensure_ascii=False)
        dart += [
            '  BatteryChemistryDefinition(',
            f"    id: {q(item['id'])}, label: {q(item['label'])},",
            '    aliases: [' + ', '.join(q(v) for v in item['aliases']) + '],',
            f"    nominalVolts: {item['nominalVolts']}, lowVolts: {item['lowVolts']}, criticalVolts: {item['criticalVolts']},",
            f"    chargeMethod: {q(item['chargeMethod'])}, maxChargeVoltsPerCell: {item['maxChargeVoltsPerCell'] if item['maxChargeVoltsPerCell'] is not None else 'null'},",
            f"    resistanceOhmsAt1Ah: {item['resistanceOhmsAt1Ah']}, referenceContinuousC: {item['referenceContinuousC']},",
            '    curve: [',
            *[f'      BatteryCurvePoint({soc}, {volt}),' for soc, volt in item['curve']],
            '    ],',
            '  ),',
        ]
    dart.append('];')
    js = [
        '// GENERATED from assets/battery/chemistries.json; do not edit by hand.',
        '// Run: python tool/data/generate_battery_chemistries.py',
        '(function(root, factory){',
        '  const model=factory();',
        "  if(typeof module==='object'&&module.exports)module.exports=model;",
        '  else root.FPVBatteryChemistries=model;',
        '})(typeof globalThis!=="undefined"?globalThis:this,function(){',
        '  "use strict";',
        '  return Object.freeze(' + json.dumps({r['id']: {k: v for k, v in r.items() if k != 'label'} for r in records}, ensure_ascii=False, separators=(',', ':')) + ');',
        '});',
    ]
    return {DART: '\n'.join(dart) + '\n', JAVASCRIPT: '\n'.join(js) + '\n'}


def comparable_source(value: str) -> str:
    """Ignore formatter-only whitespace outside quoted literals."""
    result = []
    quote = None
    escaped = False
    for ch in value:
        if quote is not None:
            result.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        elif ch in ("'", '"'):
            quote = ch
            result.append(ch)
        elif not ch.isspace():
            result.append(ch)
    return ''.join(result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    outputs = generate()
    for target, content in outputs.items():
        if args.check:
            if not target.is_file() or comparable_source(target.read_text(encoding='utf-8')) != comparable_source(content):
                raise SystemExit(f'Stale battery chemistry artifact: {target.relative_to(ROOT)}')
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding='utf-8')
    print('Battery chemistry artifacts verified' if args.check else 'Battery chemistry artifacts generated')


if __name__ == '__main__':
    main()
