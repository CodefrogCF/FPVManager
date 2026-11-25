"""Preview/apply the exact checksum-protected cleanup after a ZIP overlay.

Only manifest-listed tool/document paths are eligible. Replacements must already
be installed. Local edits are retained; malformed plans fail before any deletion.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = 'tool/maintenance/repository_cleanup.json'


def safe_path(root, name):
    if not isinstance(name, str) or any(c in name for c in ('\\', ':', '\0')):
        raise ValueError('Invalid cleanup path')
    rel = PurePosixPath(name)
    if (rel.is_absolute() or '..' in rel.parts or len(rel.parts) < 2
            or rel.parts[0] not in {'tool', 'docs'} or rel.as_posix() != name):
        raise ValueError(f'Unsafe cleanup path: {name}')
    target = root.joinpath(*rel.parts)
    if not target.resolve().is_relative_to(root):
        raise ValueError(f'Cleanup path leaves project: {name}')
    for parent in (target, *target.parents):
        if parent == root:
            break
        if parent.is_symlink() or getattr(parent, 'is_junction', lambda: False)():
            raise ValueError(f'Cleanup path is a link: {name}')
    return target


def known_hashes(values):
    if not isinstance(values, list) or not values or not all(
            isinstance(v, str) and re.fullmatch(r'[0-9a-f]{64}', v) for v in values):
        raise ValueError('Invalid cleanup hashes')
    return set(values)


def matches(path, expected):
    data = path.read_bytes()
    return bool(expected.intersection(
        hashlib.sha256(value).hexdigest() for value in (data, data.replace(b'\r\n', b'\n'))))


def cleanup(project_root=ROOT, apply=False):
    root = Path(project_root).resolve()
    if not re.search(r'^name:\s*fpvmanager\s*$',
                     (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M):
        raise ValueError('Expected a complete FPVManager project')
    manifest_path = safe_path(root, MANIFEST)
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    if manifest.get('version') != 1 or not isinstance(manifest.get('files'), list):
        raise ValueError('Invalid repository cleanup manifest')
    plans, seen = [], set()
    for entry in manifest['files']:
        name = entry['path']
        target = safe_path(root, name)
        hashes = known_hashes(entry['known_sha256'])
        replacement = entry['replacement']
        destination = safe_path(root, replacement['path'])
        destination_hashes = known_hashes(replacement['known_sha256'])
        if name in seen or target == destination or name == MANIFEST:
            raise ValueError(f'Duplicate/self-referential cleanup entry: {name}')
        seen.add(name)
        if not target.exists():
            status = 'absent'
        elif not target.is_file():
            raise ValueError(f'Cleanup target is not a file: {name}')
        elif not destination.is_file() or not matches(destination, destination_hashes):
            raise ValueError(f'Install the unchanged replacement first: {replacement["path"]}')
        else:
            status = 'remove' if matches(target, hashes) else 'keep-local-edits'
        plans.append((name, target, target.resolve(), hashes, destination,
                      destination_hashes, status))
    if any(destination.relative_to(root).as_posix() in seen
           for _, _, _, _, destination, _, _ in plans):
        raise ValueError('A replacement must not also be retired by this plan')
    # Every entry/replacement is checked before the first file can be removed.
    results = []
    for name, target, resolved, hashes, destination, destination_hashes, status in plans:
        if apply and status == 'remove':
            if safe_path(root, name).resolve() != resolved:
                raise ValueError(f'Cleanup path changed: {name}')
            if not matches(target, hashes) or not matches(destination, destination_hashes):
                raise ValueError(f'Cleanup content changed: {name}')
            target.unlink()
            status = 'removed'
            # Remove only empty obsolete subdirectories; never recursively delete.
            for parent in target.parents:
                if parent == root or parent.parent == root:
                    break
                try:
                    parent.rmdir()
                except OSError:
                    break
        results.append((name, status))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Remove only verified obsolete files')
    args = parser.parse_args()
    try:
        results = cleanup(apply=args.apply)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f'{error}\n')
    for name, status in results:
        print(f'{status}: {name}')
    counts = {status: sum(s == status for _, s in results)
              for status in ('remove', 'removed', 'absent', 'keep-local-edits')}
    print('Summary: ' + ', '.join(f'{key}={value}' for key, value in counts.items()))
    if not args.apply:
        print('Preview only. Use --apply after reviewing the plan.')
    return 2 if counts['keep-local-edits'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
