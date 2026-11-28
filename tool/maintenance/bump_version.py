"""Synchronize release metadata from pubspec or bump the application version."""
import argparse
from datetime import date
from pathlib import Path
import re
import sys
import tempfile
import os

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'quality'))
from check_version import (ROOT, VERSION, PUBSPEC_PATTERN, GENERATED, README_PATTERN,
                           read_version, generated_version, fixture_errors)


def plan(root, target=None, build=None, release_date=None):
    root = Path(root)
    pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
    old_version, old_build = read_version(pubspec)
    version = target or old_version
    if not re.fullmatch(VERSION, version):
        raise ValueError('Expected major.minor.patch')
    if tuple(map(int, version.split('.'))) < tuple(map(int, old_version.split('.'))):
        raise ValueError('Application version must not decrease')
    if build is None:
        build = old_build + int(version != old_version)
    if build < old_build or (version != old_version and build <= old_build):
        raise ValueError('Build number must not decrease and must increase for a new version')
    if release_date is not None:
        release_date = date.fromisoformat(release_date).isoformat()
    errors = fixture_errors(root, version)
    if errors:
        raise ValueError('\n'.join(errors))
    readme = (root / 'README.md').read_text(encoding='utf-8')
    if len(README_PATTERN.findall(readme)) != 1:
        raise ValueError('README.md: expected exactly one Current source version line')
    changelog = (root / 'CHANGELOG.md').read_text(encoding='utf-8')
    heading = f'## [{version}]' + (f' - {release_date}' if release_date else '')
    if not re.search(r'^## \[' + re.escape(version) + r'\]', changelog, re.M):
        unreleased = re.compile(r'^## \[Unreleased\][ \t]*$', re.M | re.I)
        if unreleased.search(changelog):
            changelog = unreleased.sub(heading, changelog, count=1)
        else:
            first = re.search(r'^# Changelog[ \t]*$', changelog, re.M)
            if first is None:
                raise ValueError('CHANGELOG.md: missing title')
            changelog = changelog[:first.end()] + '\n\n' + heading + '\n' + changelog[first.end():]
    proposed = {
        'pubspec.yaml': PUBSPEC_PATTERN.sub(f'version: {version}+{build}', pubspec),
        GENERATED: generated_version(version, build),
        'README.md': README_PATTERN.sub(lambda m: m[1] + f'{version}+{build}' + m[2], readme),
        'CHANGELOG.md': changelog,
    }
    return {name: text for name, text in proposed.items()
            if not (root / name).exists() or (root / name).read_text(encoding='utf-8') != text}


def apply(root, changes):
    # Stage all files before replacing any. Each replacement is atomic; restore
    # already replaced files if a later replacement fails.
    root = Path(root)
    staged = {}
    originals = {}
    replaced = []
    try:
        for name, text in changes.items():
            path = root / name
            originals[path] = path.read_bytes() if path.exists() else None
            path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
                staged[path] = Path(stream.name)
                stream.write(text.encode('utf-8'))
        for path, temp in staged.items():
            os.replace(temp, path)
            replaced.append(path)
    except OSError:
        for path in reversed(replaced):
            original = originals[path]
            if original is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(original)
        raise
    finally:
        for temp in staged.values():
            temp.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version', nargs='?', help='New semantic version')
    parser.add_argument('--sync', action='store_true', help='Use existing pubspec version/build')
    parser.add_argument('--build', type=int, help='Explicit build number (otherwise increment for new version)')
    parser.add_argument('--date', help='Date for a new changelog heading (YYYY-MM-DD)')
    parser.add_argument('--dry-run', action='store_true', help='List changes without writing')
    args = parser.parse_args()
    if bool(args.version) == args.sync or (args.sync and args.build is not None):
        parser.error('Specify a version (optionally --build) or --sync')
    try:
        changes = plan(ROOT, args.version, args.build, args.date)
        if not args.dry_run:
            apply(ROOT, changes)
    except (OSError, ValueError) as exc:
        parser.exit(1, f'{exc}\n')
    print(('Would update: ' if args.dry_run else 'Updated: ') + (', '.join(changes) or 'nothing; already synchronized'))
    if 'CHANGELOG.md' in changes:
        print('Review the new changelog section and add the actual release notes.')


if __name__ == '__main__':
    main()
