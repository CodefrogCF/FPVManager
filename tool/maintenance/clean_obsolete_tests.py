"""Preview or remove only known, obsolete incremental scenery JavaScript tests.

Old test files linger after changed-files ZIPs are overlaid on an existing
checkout. Their historical JSON/report requirements no longer apply to the
current scene. Only exact, checksum-matched paths listed in the versioned
manifest can be removed. Locally modified tests are NEVER deleted.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath


TARGET_NAME = re.compile(r'scenery_r\d+[a-z0-9_]*\.test\.cjs\Z')
SHA256 = re.compile(r'[0-9a-f]{64}\Z')


def cleanup(root: Path, apply: bool = False) -> list[tuple[str, str]]:
    root = Path(root).resolve()
    if not re.search(r'^name:\s*fpvmanager\s*$',
                     (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M):
        raise ValueError('Expected FPVManager project root')
    manifest = json.loads((root / 'test/obsolete_tests.json').read_text(encoding='utf-8'))
    if manifest.get('version') != 1 or not isinstance(manifest.get('files'), list):
        raise ValueError('Unsupported test cleanup manifest')
    plan = []
    seen = set()
    for item in manifest['files']:
        name = item.get('path')
        hashes = item.get('known_sha256')
        if not isinstance(name, str) or '\\' in name or ':' in name or '\0' in name:
            raise ValueError(f'Unsafe obsolete path: {name}')
        rel = PurePosixPath(name)
        if (rel.is_absolute() or '..' in rel.parts or len(rel.parts) != 3 or
                rel.parts[:2] != ('test', 'js') or
                not TARGET_NAME.fullmatch(rel.name) or
                rel.as_posix() != name or name in seen):
            raise ValueError(f'Unsafe obsolete test path: {name}')
        if (not isinstance(hashes, list) or not hashes or
                not all(isinstance(h, str) and SHA256.fullmatch(h) for h in hashes)):
            raise ValueError(f'Missing checksums for {name}')
        seen.add(name)
        target = root.joinpath(*rel.parts)
        if target.is_symlink() or not target.resolve().is_relative_to(root):
            raise ValueError(f'Symlink or outside project: {name}')
        if not target.exists():
            status = 'absent'
        elif not target.is_file():
            raise ValueError(f'Not a regular file: {name}')
        else:
            source = target.read_bytes()
            checks = {hashlib.sha256(source).hexdigest(),
                      hashlib.sha256(source.replace(b'\r\n', b'\n')).hexdigest()}
            status = 'remove' if not checks.isdisjoint(hashes) else 'modified'
        plan.append((name,target,status))
    # Validate the whole manifest first: a later invalid item cannot cause a
    # partially applied destructive cleanup.
    result = []
    for name,target,status in plan:
        if apply and status == 'remove':
            if target.is_symlink():
                raise ValueError(f'File changed during cleanup: {name}')
            target.unlink()
            status = 'removed'
        result.append((name,status))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true',
                        help='Remove obsolete tests only if their SHA-256 matches the manifest')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    labels = {'absent':'Already absent', 'remove':'Would remove',
              'removed':'Removed', 'modified':'Kept (modified locally)'}
    try:
        results=cleanup(root,args.apply)
    except (ValueError,OSError,KeyError,TypeError) as error:
        parser.exit(1,f'{error}\n')
    for name,status in results:
        print(f'{labels[status]}: {name}')
    if not args.apply:
        print('Preview only; rerun with --apply to remove matching obsolete tests.')
    if any(s=='modified' for _,s in results):
        print('Locally modified old tests were preserved; review them manually.')


if __name__ == '__main__':
    main()
