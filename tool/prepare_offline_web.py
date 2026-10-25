"""After flutter build web, create the integrity manifest for atomic offline install."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent


def prepare(root):
    root=Path(root).resolve()
    for required in ['index.html','flutter_bootstrap.js','main.dart.js','offline_service_worker.js','offline_maps.js']:
        if not (root/required).is_file():
            raise ValueError(f'Missing Web build asset: {required}; run flutter build web first')
    assets=[]
    total=0
    for file in sorted(root.rglob('*')):
        if file.is_symlink():
            raise ValueError('Offline application assets must not be symbolic links')
        if not file.is_file():
            continue
        path=file.relative_to(root).as_posix()
        if file.suffix.lower() in {'.fpvbackup','.sqlite','.db'}:
            raise ValueError('Personal database/backup files must not be part of a Web build')
        # Native-only duplicate assets and development/debug artifacts are not
        # requested by the Web app. Keep runtime data and bundled licences.
        if (path=='offline_asset_manifest.json' or path.startswith('assets/web/') or
                file.suffix in {'.map','.cjs','.md'} or file.name.startswith('.')):
            continue
        size=file.stat().st_size
        total+=size
        if size>20*1024*1024 or total>256*1024*1024 or len(assets)>=2000:
            raise ValueError('Web snapshot exceeds offline installation limits')
        digest=hashlib.sha256()
        with file.open('rb') as source:
            for chunk in iter(lambda:source.read(1024*1024),b''):
                digest.update(chunk)
        assets.append({'path':path,'size':size,'sha256':digest.hexdigest()})
    encoded=json.dumps(assets,separators=(',',':'),ensure_ascii=True).encode()
    manifest={'version':hashlib.sha256(encoded).hexdigest(),'assets':assets}
    (root/'offline_asset_manifest.json').write_text(json.dumps(manifest,separators=(',',':')),encoding='utf-8')
    return manifest


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT/'build/web')
    args=parser.parse_args()
    manifest=prepare(args.root)
    print(f"Prepared {len(manifest['assets'])} assets for offline use; version {manifest['version'][:12]}")
