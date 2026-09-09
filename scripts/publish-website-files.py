#!/usr/bin/env python3
"""Prepare and validate the website's static files for GitHub Pages.

This copies local files only. It does not push, deploy, or submit URLs to a search engine.
"""
import argparse
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlparse


repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dest', type=Path, default=repo / 'docs', help='Local destination; defaults to the Pages docs directory')
args = parser.parse_args()
source = repo / 'website/dist/client'
dest = args.dest.resolve()
validator = repo / 'scripts/validate-website-seo.py'
if dest == source.resolve() or dest.is_relative_to(source.resolve()) or source.resolve().is_relative_to(dest):
    raise SystemExit('Destination must be separate from the build source directory and its parents.')
if not (source / 'index.html').is_file():
    raise SystemExit('Build website/ first with npm run build.')

# Fail before touching the old Pages files if a locale or its assets did not export.
subprocess.run([sys.executable, str(validator), '--root', str(source)], check=True)
spec = importlib.util.spec_from_file_location('website_seo', validator)
seo = importlib.util.module_from_spec(spec)
sys.dont_write_bytecode = True
spec.loader.exec_module(seo)
# Resolve every HTML source before replacing the previous site. Vinext can emit
# nested routes as path.html; GitHub Pages needs path/index.html for our URLs.
pages = {
    urlparse(url).path.removeprefix(seo.PREFIX): seo.local_target(source, url)
    for url in seo.PAGES.values()
}
public_names = {entry.name for entry in (repo / 'website/public').iterdir()}
if any(name.endswith('.md') for name in public_names):
    raise SystemExit('Public assets must not replace the Markdown project documentation in docs/.')
missing_public = sorted(name for name in public_names if not (source / name).exists())
if missing_public:
    raise SystemExit(f'Rebuild the website: these public assets are missing from the export: {missing_public}')
owned = {
    '_next', 'en', 'guides', 'en.html', 'guides.html', 'en.rsc', 'index.html', 'index.rsc', '404.html',
    'vinext-client-entry-manifest.json', *public_names,
}
dest.mkdir(parents=True, exist_ok=True)
for name in sorted(owned):
    target = dest / name
    if target.is_symlink():
        raise SystemExit(f'Refusing to replace a symbolic link: {target}')
    original = source / name
    if name == '_next' and not original.exists():
        original = source / 'ProfileDock/_next'
    if target.is_dir():
        shutil.rmtree(target)
    elif target.exists():
        target.unlink()
    if name in {'en', 'guides', 'en.html', 'guides.html', 'index.html'}:
        continue
    if original.is_dir():
        shutil.copytree(original, target)
    elif original.is_file():
        shutil.copy2(original, target)

for relative, original in pages.items():
    target = dest / relative / 'index.html'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, target)

(dest / '.nojekyll').write_text('', encoding='utf-8')
subprocess.run([sys.executable, str(validator), '--root', str(dest)], check=True)
print(f'Prepared and verified {len(pages)} pages and their assets in {dest}. No deployment performed.')
