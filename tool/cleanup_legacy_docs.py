"""Safely remove unchanged documentation files relocated by the docs reorganization.

Preview by default. --apply removes a retired file only if its SHA-256 matches
exactly the original content recorded in docs/obsolete_files.json. Local edits
are intentionally retained. This tool never touches files outside the project.
"""

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'docs/obsolete_files.json'


def clean(*, apply=False, root=ROOT):
    root = Path(root).resolve()
    data = json.loads((root / 'docs/obsolete_files.json').read_text(encoding='utf-8'))
    outcomes = {'removed': 0, 'would_remove': 0, 'preserved': 0, 'absent': 0}
    for record in data['files']:
        relative = Path(record['path'])
        if relative.is_absolute() or '..' in relative.parts or relative.parts[0] != 'docs':
            raise ValueError(f'Unsafe retired path: {relative}')
        target = (root / relative).resolve()
        if not target.is_relative_to(root / 'docs'):
            raise ValueError(f'Retired path is outside documentation: {relative}')
        if not target.exists():
            outcomes['absent'] += 1
            continue
        if not target.is_file():
            print(f'PRESERVED (not a regular file): {relative}')
            outcomes['preserved'] += 1
            continue
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        if digest != record['sha256']:
            print(f'PRESERVED (locally edited): {relative}')
            outcomes['preserved'] += 1
            continue
        if apply:
            target.unlink()
            print(f'REMOVED: {relative} (moved to {record["replacement"]})')
            outcomes['removed'] += 1
        else:
            print(f'WOULD REMOVE: {relative} (moved to {record["replacement"]})')
            outcomes['would_remove'] += 1
    print('Summary:', ', '.join(f'{name}={count}' for name, count in outcomes.items()))
    return outcomes


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='delete only unchanged retired copies')
    args = parser.parse_args()
    clean(apply=args.apply)
