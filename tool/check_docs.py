"""Check maintained documentation for broken local links and ticket references."""
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
ROOT_DOCS = ('README.md', 'CONTRIBUTING.md', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md')
TICKET = re.compile(r'github\.com/[^\s/)]+/[^\s/)]+/issues(?:\b|/)|'
                    r'\bissues?\s*#?\s*\d+|\bissue[_-]\d+|\bissue\d+', re.I)
LINK = re.compile(r'!?\[[^\]]*\]\(([^)]+)\)')


def check(root=ROOT):
    root = Path(root).resolve()
    manifest = root / 'docs/obsolete_files.json'
    retired = {item['path'] for item in json.loads(manifest.read_text(encoding='utf-8'))['files']}
    files = [root / name for name in ROOT_DOCS]
    files += list((root / 'docs').rglob('*.md'))
    files += [root / 'assets/licenses/README.md']
    errors = []
    count = 0
    for file in files:
        relative = file.relative_to(root).as_posix()
        if relative in retired:
            continue  # A ZIP update may have preserved locally edited old notes.
        if not file.is_file():
            errors.append(f'Missing guide: {relative}')
            continue
        text = file.read_text(encoding='utf-8')
        count += 1
        for number, line in enumerate(text.splitlines(), 1):
            if TICKET.search(line):
                errors.append(f'{relative}:{number}: remove ticket reference')
        for match in LINK.finditer(text):
            href = match.group(1).strip().strip('<>')
            url = urlsplit(href)
            if url.scheme or url.netloc or not url.path:
                continue
            target = (file.parent / unquote(url.path)).resolve()
            if not target.is_relative_to(root):
                errors.append(f'{relative}: link leaves project: {href}')
            elif not target.exists() or target.relative_to(root).as_posix() in retired:
                errors.append(f'{relative}: missing or retired link: {href}')
    return count, errors


if __name__ == '__main__':
    count, errors = check()
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)
    print(f'{count} maintained guides: local links valid, no ticket references.')
