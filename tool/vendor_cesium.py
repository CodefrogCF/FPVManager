"""Pinned Cesium runtime assets. --check verifies the committed bundle offline."""
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / 'web' / 'cesium'
LOCK = json.loads((ROOT / 'tool' / 'cesium_vendor.json').read_text())


def check():
    manifest = json.loads((DEST / 'manifest.json').read_text())
    assert manifest['version'] == LOCK['version']
    assert manifest['integrity'] == LOCK['integrity']
    actual = {p.relative_to(DEST).as_posix() for p in DEST.rglob('*') if p.is_file()}
    assert actual == set(manifest['files']) | {'manifest.json'}, 'Vendor file list differs'
    for name, expected in manifest['files'].items():
        content = (DEST / name).read_bytes()
        assert len(content) == expected['bytes'], name
        assert hashlib.sha256(content).hexdigest() == expected['sha256'], name
    for name in ['Cesium.js', 'Widgets/widgets.css', 'LICENSE.md', 'ThirdParty.json']:
        assert name in actual, f'Missing required asset: {name}'
    for prefix in ['Workers/', 'ThirdParty/', 'Assets/', 'Widgets/']:
        assert any(name.startswith(prefix) for name in actual), prefix
    html = (ROOT / 'web' / 'globe.html').read_text(encoding='utf-8')
    assert 'cdn.jsdelivr.net' not in html and 'https://cesium.com/' not in html
    assert 'cesium/Cesium.js' in html and 'cesium/Widgets/widgets.css' in html
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    directories = {str(PurePosixPath(name).parent) for name in actual}
    for directory in directories:
        entry = 'web/cesium/' + (directory + '/' if directory != '.' else '')
        assert f'    - {entry}\n' in pubspec, f'Missing Flutter asset directory: {entry}'
    print(f'Cesium {LOCK["version"]}: {len(actual)} files, hashes and Flutter asset paths verified.')


def vendor():
    archive = ROOT / '.dart_tool' / f'cesium-{LOCK["version"]}.tgz'
    archive.parent.mkdir(exist_ok=True)
    digest = hashlib.sha512()
    size = 0
    with urllib.request.urlopen(LOCK['url'], timeout=60) as response, archive.open('wb') as output:
        while block := response.read(1024 * 1024):
            size += len(block)
            if size > 128 * 1024 * 1024:
                raise ValueError('Cesium download exceeds size limit')
            digest.update(block)
            output.write(block)
    integrity = 'sha512-' + base64.b64encode(digest.digest()).decode()
    if integrity != LOCK['integrity']:
        raise ValueError('Cesium archive integrity mismatch')
    # Only write regular, bounded files below this exact workspace directory.
    assert DEST.resolve().is_relative_to(ROOT.resolve())
    if DEST.exists():
        raise ValueError('Vendor directory already exists; move it aside before an intentional update')
    files = {}
    with tarfile.open(archive, 'r:gz') as package:
        for member in package.getmembers():
            prefix = 'package/Build/Cesium/'
            if member.name.startswith(prefix):
                name = member.name[len(prefix):]
            elif member.name in ['package/LICENSE.md', 'package/ThirdParty.json']:
                name = member.name.removeprefix('package/')
            else:
                continue
            if not member.isfile() or name.endswith('.map'):
                continue
            target = DEST / name
            if not target.resolve().is_relative_to(DEST.resolve()) or member.size > 32 * 1024 * 1024:
                raise ValueError('Invalid archive member')
            content = package.extractfile(member).read()
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            files[name] = {'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest()}
    if not {'LICENSE.md', 'ThirdParty.json'}.issubset(files):
        raise ValueError('Upstream license files are missing')
    manifest = {**LOCK, 'files': dict(sorted(files.items()))}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    pubspec_path = ROOT / 'pubspec.yaml'
    pubspec = pubspec_path.read_text(encoding='utf-8')
    start, end = '    # BEGIN CESIUM ASSETS', '    # END CESIUM ASSETS'
    directories = sorted({str(PurePosixPath(name).parent) for name in files} | {'.'})
    entries = '\n'.join('    - web/cesium/' + (directory + '/' if directory != '.' else '')
                        for directory in directories)
    section = start + '\n' + entries + '\n' + end
    if start in pubspec:
        before, rest = pubspec.split(start, 1)
        _, after = rest.split(end, 1)
        pubspec = before + section + after
    else:
        pubspec = pubspec.replace('    - web/globe.html', '    - web/globe.html\n' + section)
    pubspec_path.write_text(pubspec, encoding='utf-8')
    print(f'Vendored {len(files)} Cesium files, {sum(f["bytes"] for f in files.values())} bytes.')


if __name__ == '__main__':
    if sys.argv[1:] == ['--check']:
        check()
    elif not sys.argv[1:]:
        vendor()
    else:
        raise SystemExit('Usage: python tool/vendor_cesium.py [--check]')
