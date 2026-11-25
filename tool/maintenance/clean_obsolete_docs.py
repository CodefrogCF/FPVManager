"""Preview or remove checksum-matched obsolete documentation after a ZIP update.

Only explicitly allowlisted Markdown and two superseded cleanup helpers are
eligible. Never delete a file whose content changed locally.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re


def cleanup(project_root, apply=False):
    root = Path(project_root).resolve()
    pubspec = root / 'pubspec.yaml'
    if not pubspec.is_file() or not re.search(
            r'^name:\s*fpvmanager\s*$', pubspec.read_text(encoding='utf-8'), re.M):
        raise ValueError('Run this tool from a complete FPVManager project.')
    manifest = json.loads((root / 'docs/obsolete_files.json').read_text(encoding='utf-8'))
    if manifest.get('version') != 1 or not isinstance(manifest.get('files'), list):
        raise ValueError('Invalid documentation cleanup manifest.')
    plans = []
    seen = set()
    for entry in manifest['files']:
        name = entry.get('path')
        hashes = entry.get('known_sha256')
        if not isinstance(name, str) or any(c in name for c in ('\\', ':', '\0')):
            raise ValueError('Invalid retired documentation path.')
        path = PurePosixPath(name)
        legacy_root = name in {'AENDERUNGEN_3D_TUNNEL.md', 'AENDERUNGEN_MENUES.md'}
        allowed_helper = name in {'tool/cleanup_legacy_docs.py', 'test/tool/test_cleanup_legacy_docs.py'}
        # Rüdersdorf incremental READMEs can live under tool/scenery/, never
        # allow arbitrary deletion of source code or unrelated tool assets.
        scenery_readme = (len(path.parts) >= 3 and path.parts[0:2] == ('tool', 'scenery')
            and path.suffix.lower() == '.md' and (
                path.name.startswith('README_') or path.name == 'README.md'
                or re.fullmatch(r'R[0-9]+_README\.md', path.name) is not None))
        allowed = (name.startswith('docs/') and path.suffix == '.md') or legacy_root or scenery_readme or allowed_helper
        if (path.is_absolute() or '..' in path.parts or name != path.as_posix()
                or not allowed or name in seen):
            raise ValueError(f'Unsafe retired documentation path: {name}')
        if not isinstance(hashes, list) or not hashes or not all(
                isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value) for value in hashes):
            raise ValueError(f'Missing known file hashes: {name}')
        seen.add(name)
        target = root.joinpath(*path.parts)
        resolved = target.resolve()
        if not resolved.is_relative_to(root) or target.is_symlink():
            raise ValueError(f'Path leaves the project or is a symlink: {name}')
        if not target.exists():
            status = 'absent'
        elif not target.is_file():
            raise ValueError(f'Retired path is not a regular file: {name}')
        else:
            data = target.read_bytes()
            actual = {hashlib.sha256(value).hexdigest()
                      for value in (data, data.replace(b'\r\n', b'\n'))}
            status = 'remove' if actual.intersection(hashes) else 'keep-local-edits'
        plans.append((name, target, resolved, status))
    # Validate the entire manifest before deleting even one file.
    result = []
    for name, target, resolved, status in plans:
        if apply and status == 'remove':
            if target.is_symlink() or target.resolve() != resolved:
                raise ValueError(f'Path changed during cleanup: {name}')
            target.unlink()
            status = 'removed'
        result.append((name, status))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Remove only matched old documents.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    try:
        results = cleanup(root, args.apply)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f'{error}\n')
    labels = {'absent': 'Already absent', 'remove': 'Would remove',
              'removed': 'Removed', 'keep-local-edits': 'Kept (locally changed)'}
    for name, status in results:
        print(f'{labels[status]}: {name}')
    if not args.apply:
        print('Preview only. Use --apply to remove matching files.')


if __name__ == '__main__':
    main()
