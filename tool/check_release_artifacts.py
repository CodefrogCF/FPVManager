"""Check built FPVManager packages before attaching them to a release."""

import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import struct
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


def validate_glb_meshes(blob, name='scene.glb'):
    """Reject structurally invalid GLB meshes before shipping local scenery.

    This checks the low-cost glTF JSON contract without loading its large BIN
    payload or requiring graphics hardware. The full GLB may be optional from
    public CI because its original scan licence is different from the code.
    """
    if len(blob) < 28:
        raise ValueError(f'{name}: truncated GLB')
    magic, version, length = struct.unpack_from('<4sII', blob)
    if magic != b'glTF' or version != 2 or length != len(blob):
        raise ValueError(f'{name}: invalid GLB header or length')
    json_len, chunk_type = struct.unpack_from('<I4s', blob, 12)
    if chunk_type != b'JSON' or 20 + json_len > len(blob):
        raise ValueError(f'{name}: missing or incomplete GLB JSON')
    try:
        doc = json.loads(blob[20:20 + json_len])
    except (ValueError, UnicodeDecodeError) as error:
        raise ValueError(f'{name}: unreadable GLB JSON') from error
    meshes = doc.get('meshes', [])
    for i, mesh in enumerate(meshes):
        if not isinstance(mesh.get('primitives'), list) or not mesh['primitives']:
            raise ValueError(f'{name}: empty glTF mesh at index {i}')
    for i, node in enumerate(doc.get('nodes', [])):
        if 'mesh' in node and (not isinstance(node['mesh'], int) or
                              node['mesh'] < 0 or node['mesh'] >= len(meshes)):
            raise ValueError(f'{name}: node {i} refers to missing mesh')
    return len(meshes)


def check_optional_local_scenery(read, prefix, root=ROOT,
                                 transform=lambda path: path):
    """Check local-only scenery when installed, skip unbundled NC originals.

    If an author has installed the private scenery assets in the source tree,
    a release must package those exact bytes and contain valid glTF meshes.
    Public-source CI can build without the untracked CC BY-NC scan assets.
    """
    catalog = root / 'web/assets/scenery/catalog.json'
    if not catalog.is_file():
        return
    data = json.loads(catalog.read_text(encoding='utf-8'))
    for scene in data.get('sceneries', []):
        names = [item['path'] for item in scene.get('assets', [])]
        if scene.get('collisionAsset'):
            names.append(scene['collisionAsset'])
        underlay = scene.get('terrainUnderlay') or {}
        names += [underlay[key] for key in ('asset', 'collisionAsset') if underlay.get(key)]
        for name in set(names):
            source_path = root / 'web/assets/scenery' / name
            if not source_path.is_file():
                continue
            bundle_path = 'web/assets/scenery/' + name
            content = read(prefix + transform(bundle_path))
            if content != source_path.read_bytes():
                raise ValueError(f'Packaged scenery differs from local source: {name}')
            if name.endswith('.glb'):
                validate_glb_meshes(content, name)


def check_apk(path):
    with ZipFile(path) as archive:
        check_payload(archive.read, 'assets/flutter_assets/', renderer_files())
        check_optional_local_scenery(archive.read, 'assets/flutter_assets/')


def check_windows(path):
    def verify(read, prefix):
        check_payload(read, prefix + 'data/flutter_assets/', renderer_files())
        check_optional_local_scenery(read, prefix + 'data/flutter_assets/')
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
    check_optional_local_scenery(read_packaged, '',
                                 transform=lambda name: name[4:])


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
