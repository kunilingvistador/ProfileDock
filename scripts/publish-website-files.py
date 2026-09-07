#!/usr/bin/env python3
"""Copy the website's built static export into GitHub Pages' docs folder."""
from pathlib import Path
import re
import shutil

repo = Path(__file__).resolve().parents[1]
source = repo / 'website/dist/client'
dest = repo / 'docs'
if not (source / 'index.html').is_file():
    raise SystemExit('Build website/ first with npm run build.')
# Only replace generated website artifacts; retain the project documentation.
owned = ['_next', 'index.html', 'index.rsc', '404.html', 'icon.svg', 'vinext-client-entry-manifest.json']
for name in owned:
    target = dest / name
    if target.is_dir(): shutil.rmtree(target)
    elif target.exists(): target.unlink()
    original = source / name
    if name == '_next' and not original.exists():
        original = source / 'ProfileDock/_next'
    if original.is_dir(): shutil.copytree(original, target)
    elif original.is_file(): shutil.copy2(original, target)
(dest / '.nojekyll').write_text('')
html = (dest / 'index.html').read_text()
refs = re.findall(r'(?:src|href)="(/ProfileDock/[^"?#]+)"', html)
missing = [ref for ref in refs if not (dest / ref.removeprefix('/ProfileDock/')).is_file()]
if missing: raise SystemExit(f'Missing published assets: {missing}')
print(f'Copied static site; verified {len(refs)} local asset references.')
