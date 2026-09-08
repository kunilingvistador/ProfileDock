#!/usr/bin/env python3
"""Prepare and validate the website's static files for GitHub Pages.

This copies local files only. It does not push, deploy, or submit URLs to a search engine.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys


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
public_names = {entry.name for entry in (repo / 'website/public').iterdir()}
if any(name.endswith('.md') for name in public_names):
    raise SystemExit('Public assets must not replace the Markdown project documentation in docs/.')
missing_public = sorted(name for name in public_names if not (source / name).exists())
if missing_public:
    raise SystemExit(f'Rebuild the website: these public assets are missing from the export: {missing_public}')
owned = {
    '_next', 'en', 'en.rsc', 'index.html', 'index.rsc', '404.html',
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
    if name == 'en' and not original.exists() and (source / 'en.html').is_file():
        target.mkdir()
        shutil.copy2(source / 'en.html', target / 'index.html')
    elif original.is_dir():
        shutil.copytree(original, target)
    elif original.is_file():
        shutil.copy2(original, target)

(dest / '.nojekyll').write_text('', encoding='utf-8')
subprocess.run([sys.executable, str(validator), '--root', str(dest)], check=True)
print(f'Prepared and verified both language pages and assets in {dest}. No deployment performed.')
