"""Keep tool entry points grouped and reject stale tool command paths in guides/CI."""
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
TOOL_PATH = re.compile(r'\btool/[\w./-]+\.(?:py|dart|cjs|ps1|json|txt)\b')
GROUPS = {'quality', 'build', 'data', 'benchmarks', 'browser', 'maintenance', 'scenery'}


def check(root=ROOT):
    root = Path(root).resolve()
    manifest = root / 'tool/maintenance/repository_cleanup.json'
    retired = {entry['path'] for entry in json.loads(manifest.read_text(encoding='utf-8'))['files']}
    errors = []
    if not (root / 'tool/README.md').is_file():
        errors.append('Missing tool/README.md')
    for path in (root / 'tool').iterdir():
        rel = path.relative_to(root).as_posix()
        if path.name == '__pycache__':
            continue
        if path.is_file() and path.name != 'README.md' and rel not in retired:
            errors.append(f'Unclassified tool at repository tool root: {rel}')
        if path.is_dir() and path.name not in GROUPS:
            # An extracted ZIP can still contain empty/retired directories.
            if any(p.is_file() and p.relative_to(root).as_posix() not in retired
                   for p in path.rglob('*')):
                errors.append(f'Unclassified tool group: {rel}')
    guides = [root / name for name in ('README.md', 'CONTRIBUTING.md', 'tool/README.md')]
    guides += list((root / 'docs').rglob('*.md'))
    guides += list((root / '.github/workflows').glob('*.yml'))
    for path in guides:
        if not path.is_file() or path.relative_to(root).as_posix() in retired:
            continue
        for match in TOOL_PATH.finditer(path.read_text(encoding='utf-8')):
            name = match.group()
            if name in retired or not (root / name).is_file():
                errors.append(f'{path.relative_to(root).as_posix()}: stale tool path: {name}')
    return errors


if __name__ == '__main__':
    errors = check()
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)
    print('Tool groups and documented/CI command paths are valid.')
