"""Validate canonical Markdown documentation and links after a ZIP overlay.

Retired paths listed by a versioned checksum cleanup manifest are excluded while
installed overlays wait for the user to run the safe cleanup utility. Current
documentation cannot link to retired files and exact duplicated guides fail CI.
"""
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
ROOT_DOCS = ('README.md', 'CONTRIBUTING.md', 'CHANGELOG.md',
             'THIRD_PARTY_NOTICES.md', 'PRIVACY.md')
TICKET = re.compile(r'github\.com/[^\s/)]+/[^\s/)]+/issues(?:\b|/)|'
                    r'\bissues?\s*#?\s*\d+|\bissue[_-]\d+|\bissue\d+', re.I)
LINK = re.compile(r'!?\[[^\]]*\]\(([^)]+)\)')


def check(root=ROOT):
    root = Path(root).resolve()
    manifest = root / 'docs/obsolete_files.json'
    retired = set()
    errors = []
    if manifest.is_file():
        data = json.loads(manifest.read_text(encoding='utf-8'))
        if data.get('version') != 1 or not isinstance(data.get('files'), list):
            errors.append('docs/obsolete_files.json: invalid cleanup format')
        else:
            retired = {entry['path'] for entry in data['files']}
    files = [root / name for name in ROOT_DOCS]
    files += sorted((root / 'docs').rglob('*.md'))
    files += [root / 'assets/licenses/README.md']
    files += [root / 'web/assets/scenery/ATTRIBUTION.md']
    count = 0
    seen_hashes = {}
    for file in files:
        relative = file.relative_to(root).as_posix()
        if relative in retired:
            continue  # An old checkout may still contain an unremoved Markdown file.
        if not file.is_file():
            errors.append(f'Missing guide: {relative}')
            continue
        content = file.read_bytes()
        source = content.decode('utf-8')
        count += 1
        if relative.startswith('docs/'):
            digest = hashlib.sha256(content).hexdigest()
            if digest in seen_hashes:
                errors.append(f'{relative}: duplicate guide content in {seen_hashes[digest]}')
            else:
                seen_hashes[digest] = relative
        for number, line in enumerate(source.splitlines(), 1):
            if TICKET.search(line):
                errors.append(f'{relative}:{number}: remove ticket reference')
        for match in LINK.finditer(source):
            href = match.group(1).strip().strip('<>')
            url = urlsplit(href)
            if url.scheme or url.netloc or not url.path:
                continue
            target = (file.parent / unquote(url.path)).resolve()
            if not target.is_relative_to(root):
                errors.append(f'{relative}: link leaves project: {href}')
            else:
                target_rel = target.relative_to(root).as_posix()
                if not target.exists() or target_rel in retired:
                    errors.append(f'{relative}: missing or retired link: {href}')
    return count, errors


if __name__ == '__main__':
    count, errors = check()
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)
    print(f'{count} maintained guides: local links valid, no ticket references or duplicated Markdown.')
