"""Check release version and scenery metadata consistency without Flutter."""
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def check(root=ROOT):
    root = Path(root)
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
                      (root / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)
    if not match:
        return ['pubspec.yaml: expected major.minor.patch+build']
    version, build = match.groups()
    checks = {
        'lib/features/scenery/scenery_asset_provider.dart': r"const sceneryApplicationVersion = '([^']+)'",
        'lib/features/scenery/scenery_manifest.dart': r"'minimumAppVersion': '([^']+)'",
        'lib/features/scenery/scenery_tileset_dialog.dart': r"'minimumAppVersion'\] \?\? '([^']+)'",
        'test/support/scenery_fixture.dart': r"'minimumAppVersion': '([^']+)'",
        'test/support/scenery_tileset_fixture.dart': r"'minimumAppVersion': '([^']+)'",
        'test/support/scenery_model_fixture.dart': r"'minimumAppVersion': '([^']+)'",
        'tool/scenery/conversion/convert.py': r"minimumAppVersion='([^']+)'",
    }
    errors = []
    for path, pattern in checks.items():
        values = re.findall(pattern, (root / path).read_text(encoding='utf-8'))
        if values != [version]:
            errors.append(f'{path}: expected {version}, found {values}')
    fixture = 'test/fixtures/scenery/conversion_open_wall.fpvscenery'
    with zipfile.ZipFile(root / fixture) as archive:
        manifest = json.loads(archive.read('manifest.json'))
        if manifest['scenery']['minimumAppVersion'] != version or archive.testzip() is not None:
            errors.append(f'{fixture}: version or ZIP integrity mismatch')
    if f'`{version}+{build}`' not in (root / 'README.md').read_text(encoding='utf-8'):
        errors.append('README.md: current source version mismatch')
    if not re.search(r'^## \[' + re.escape(version) + r'\]',
                     (root / 'CHANGELOG.md').read_text(encoding='utf-8'), re.M):
        errors.append('CHANGELOG.md: missing version entry')
    return errors


if __name__ == '__main__':
    errors = check()
    if errors:
        raise SystemExit('\n'.join(errors))
    print('Application version, scenery defaults, fixture and release docs agree.')
