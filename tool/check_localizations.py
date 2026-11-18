#!/usr/bin/env python3
"""Validate ARB parity and regenerate the type-checked compatibility bridge.

Usage: python tool/check_localizations.py --write
       python tool/check_localizations.py --check
"""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EN = ROOT / 'lib/l10n/app_en.arb'
DE = ROOT / 'lib/l10n/app_de.arb'
OUT = ROOT / 'lib/core/localization/legacy_message_lookup.g.dart'
ARG = re.compile(r'\{arg(\d+)\}')

def literal(value: str) -> str:
    # Dart double-quoted constant with explicit escaping of interpolation.
    return json.dumps(value, ensure_ascii=False).replace('$', r'\$')

def generated() -> str:
    en = json.loads(EN.read_text(encoding='utf-8'))
    de = json.loads(DE.read_text(encoding='utf-8'))
    keys = sorted(k for k in en if not k.startswith('@'))
    translated = {k for k in de if not k.startswith('@')}
    if missing := set(keys) - translated:
        raise ValueError(f'German translations missing: {len(missing)}: {sorted(missing)[:5]}')
    if extra := translated - set(keys):
        raise ValueError(f'German translations without English keys: {len(extra)}')
    lines = [
        '// GENERATED FILE - DO NOT EDIT.',
        '// Regenerate with: python tool/check_localizations.py --write',
        "import 'generated/fpv_strings.dart';",
        '',
        'String lookupLocalizedMessage(',
        '  FpvStrings l10n,',
        '  String source,',
        '  List<Object?> arguments,',
        ') {',
        '  switch (source) {',
    ]
    sources = set()
    for key in keys:
        metadata = en.get('@' + key, {})
        description = metadata.get('description', '')
        if not description.startswith('Legacy key: '):
            # New, directly typed gen-l10n keys need no legacy bridge entry.
            continue
        source = description.removeprefix('Legacy key: ')
        if source in sources:
            raise ValueError(f'Duplicate source: {source}')
        sources.add(source)
        placeholders = metadata.get('placeholders', {})
        args = sorted((int(p[3:]) for p in placeholders), key=int)
        enargs = {int(i) for i in ARG.findall(en[key])}
        deargs = {int(i) for i in ARG.findall(de[key])}
        if set(args) != enargs or enargs != deargs:
            raise ValueError(f'Placeholder mismatch: {key} {args} {enargs} {deargs}')
        call = f'l10n.{key}'
        if args:
            call += '(' + ', '.join(f'_arg(arguments, {i})' for i in args) + ')'
        lines.append(f'    case {literal(source)}:')
        lines.append(f'      return {call};')
    lines += [
        '    default:',
        '      return interpolateSource(source, arguments);',
        '  }',
        '}',
        '',
        r'final _legacyPlaceholder = RegExp(r"\{(\d+)\}");',
        '',
        'String interpolateSource(String source, List<Object?> arguments) {',
        '  if (arguments.isEmpty) return source;',
        '  return source.replaceAllMapped(_legacyPlaceholder, (match) {',
        '    final index = int.parse(match.group(1)!);',
        "    return index < arguments.length ? '${arguments[index]}' : match.group(0)!;",
        '  });',
        '}',
        '',
        'String _arg(List<Object?> arguments, int index) =>',
        "    index < arguments.length ? '${arguments[index]}' : '{$index}';",
        '',
    ]
    return '\n'.join(lines)

def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = generated()
    if args.write:
        OUT.write_text(data, encoding='utf-8')
        print(f'Updated {OUT.relative_to(ROOT)}')
    elif not OUT.exists() or OUT.read_text(encoding='utf-8') != data:
        raise SystemExit('Localization bridge is stale; run python tool/check_localizations.py --write')
    else:
        print('Localization catalogs and compatibility bridge verified')

if __name__ == '__main__':
    main()
