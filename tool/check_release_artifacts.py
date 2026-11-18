"""Check built FPVManager packages before attaching them to a release."""

import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parent.parent
DECODERS = (
    'web/vendor/geotiff/geotiff.js',
    'web/vendor/geotiff/LICENSE',
    'web/vendor/geotiff/THIRD_PARTY_NOTICES.txt',
    'web/vendor/h5wasm/hdf5_hl.js',
    'web/vendor/h5wasm/hdf5_util.js',
    'web/vendor/h5wasm/file_handlers.js',
    'web/vendor/h5wasm/LICENSE.txt',
    'web/vendor/h5wasm/THIRD_PARTY_NOTICES.txt',
)
WINDOWS_NOTICES = (
    'licenses/CppWinRT/LICENSE',
    'licenses/WebView2/LICENSE.txt',
    'licenses/WebView2/NOTICE.txt',
    'licenses/WindowsImplementationLibrary/LICENSE',
    'licenses/WindowsImplementationLibrary/ThirdPartyNotices.txt',
)


class RendererScripts(HTMLParser):
    def __init__(self):
        super().__init__()
        self.paths = []

    def handle_starttag(self, tag, attrs):
        if tag == 'script' and (source := dict(attrs).get('src')):
            self.paths.append(source)


def renderer_files(root=ROOT):
    paths = ['NOTICE', *DECODERS]
    for page in ('web/globe.html', 'web/offline_preparation.html'):
        scripts = RendererScripts()
        scripts.feed((root / page).read_text(encoding='utf-8'))
        paths.extend([page, *('web/' + script for script in scripts.paths)])
    return sorted(set(paths))


def check_payload(read, prefix, paths, root=ROOT, transform=lambda path: path):
    for name in paths:
        artifact = read(prefix + transform(name))
        expected = (root / name).read_bytes()
        if artifact != expected:
            raise ValueError(f'Packaged file differs from source: {name}')


def check_apk(path):
    with ZipFile(path) as archive:
        check_payload(archive.read, 'assets/flutter_assets/', renderer_files())


def check_windows(path):
    def verify(read, prefix):
        check_payload(read, prefix + 'data/flutter_assets/', renderer_files())
        for notice in WINDOWS_NOTICES:
            if not read(prefix + notice).strip():
                raise ValueError(f'Empty Windows licence file: {notice}')

    if path.is_dir():
        verify(lambda name: (path / name).read_bytes(), '')
        return
    with ZipFile(path) as archive:
        anchor = 'data/flutter_assets/web/globe.html'
        entries = [name for name in archive.namelist() if name.endswith(anchor)]
        if len(entries) != 1:
            raise ValueError('Expected exactly one Windows Flutter asset bundle')
        verify(archive.read, entries[0][:-len(anchor)])


def check_web(path):
    version = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    name, build = re.search(r'^version:\s*(\S+)\+(\d+)\s*$', version, re.M).groups()
    actual = json.loads((path / 'version.json').read_text(encoding='utf-8'))
    if str(actual.get('version')) != name or str(actual.get('build_number')) != build:
        raise ValueError('Web package version does not match pubspec.yaml')

    def read_packaged(filename):
        return (path / filename).read_bytes()

    check_payload(read_packaged, '', renderer_files(),
                  transform=lambda name: 'assets/NOTICE' if name == 'NOTICE' else name[4:])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for kind in ('apk', 'windows', 'web'):
        parser.add_argument('--' + kind, type=Path)
    args = parser.parse_args()
    if not any(vars(args).values()):
        parser.error('Specify at least one built artifact')
    for kind, check in [('apk', check_apk), ('windows', check_windows), ('web', check_web)]:
        path = getattr(args, kind)
        if path is not None:
            try:
                check(path)
            except (OSError, KeyError, ValueError) as error:
                parser.exit(1, f'{kind}: {error}\n')
            print(f'{kind}: renderer and licences verified')


if __name__ == '__main__':
    main()
