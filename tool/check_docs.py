"""Check maintained documentation for broken local links and ticket references."""
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
ROOT_DOCS = ('README.md', 'CONTRIBUTING.md', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md', 'PRIVACY.md')
TICKET = re.compile(r'github\.com/[^\s/)]+/[^\s/)]+/issues(?:\b|/)|'
                    r'\bissues?\s*#?\s*\d+|\bissue[_-]\d+|\bissue\d+', re.I)
LINK = re.compile(r'!?\[[^\]]*\]\(([^)]+)\)')


def is_relocated_legacy_doc(root, relative):
    """Identify root-level duplicates when a maintained audience guide exists.

    ZIP updates cannot delete existing files, and the relocation manifest may
    not yet be committed in a checkout. Only root-level docs with an actual
    audience-specific replacement are treated as legacy; broken links in the
    canonical documents must still fail CI.
    """
    parts = Path(relative).parts
    if len(parts) != 2 or parts[0] != 'docs':
        return False
    if parts[1] in {'README.md', 'user_guide.md', 'developer_guide.md'}:
        return False
    return any((root / 'docs' / area / parts[1]).is_file() for area in
               ('user', 'developer', 'archive/2026-11'))


def check(root=ROOT):
    root = Path(root).resolve()
    manifest = root / 'docs/obsolete_files.json'
    retired = set()
    if manifest.is_file():
        retired = {item['path'] for item in json.loads(manifest.read_text(encoding='utf-8'))['files']}
    files = [root / name for name in ROOT_DOCS]
    files += list((root / 'docs').rglob('*.md'))
    files += [root / 'assets/licenses/README.md']
    errors = []
    count = 0
    for file in files:
        relative = file.relative_to(root).as_posix()
        if relative in retired or is_relocated_legacy_doc(root, relative):
            continue  # ZIP overlays can retain moved root-level documentation.
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
            else:
                target_rel = target.relative_to(root).as_posix()
                if (not target.exists() or target_rel in retired
                        or is_relocated_legacy_doc(root, target_rel)):
                    errors.append(f'{relative}: missing or retired link: {href}')
    return count, errors


if __name__ == '__main__':
    count, errors = check()
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)
    print(f'{count} maintained guides: local links valid, no ticket references.')
