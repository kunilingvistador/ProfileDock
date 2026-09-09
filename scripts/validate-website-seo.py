#!/usr/bin/env python3
"""Validate real static HTML and crawlable assets before publishing ProfileDock."""

from __future__ import annotations

import argparse
from collections import defaultdict
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import unquote, urljoin, urlparse
import xml.etree.ElementTree as ET


SITE = 'https://kunilingvistador.github.io/ProfileDock/'
PREFIX = '/ProfileDock/'
PAGE_GROUPS = {
    'home': {'ru': SITE, 'en': SITE + 'en/'},
    'guides': {'ru': SITE + 'guides/', 'en': SITE + 'en/guides/'},
    'setup': {
        'ru': SITE + 'guides/chrome-profile-shortcuts-mac-dock/',
        'en': SITE + 'en/guides/chrome-profile-shortcuts-mac-dock/',
    },
    'hotkeys': {
        'ru': SITE + 'guides/switch-chrome-profiles-keyboard-mac/',
        'en': SITE + 'en/guides/switch-chrome-profiles-keyboard-mac/',
    },
    'reconnect': {
        'ru': SITE + 'guides/chrome-shortcut-existing-window/',
        'en': SITE + 'en/guides/chrome-shortcut-existing-window/',
    },
}
PAGES = {f'{group}:{language}': url for group, pages in PAGE_GROUPS.items() for language, url in pages.items()}
REPO = Path(__file__).resolve().parents[1]


class Document(HTMLParser):
    def __init__(self, source: str):
        super().__init__(convert_charrefs=True)
        self.language = None
        self.in_head = False
        self.in_title = False
        self.hidden_depth = 0
        self.title_parts: list[str] = []
        self.title_count = 0
        self.h1_count = 0
        self.text: list[str] = []
        self.meta: dict[str, list[str]] = defaultdict(list)
        self.links: list[dict[str, str]] = []
        self.anchors: list[str] = []
        self.ids: set[str] = set()
        self.references: set[str] = set()
        self.jsonld: list[str] = []
        self.json_buffer: list[str] | None = None
        self.feed(source)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        data = {key: value or '' for key, value in attrs}
        if tag == 'html':
            self.language = data.get('lang')
        if data.get('id'):
            self.ids.add(data['id'])
        if tag == 'head':
            self.in_head = True
        if tag == 'title' and self.in_head:
            self.in_title = True
            self.title_count += 1
        if tag == 'h1':
            self.h1_count += 1
        if tag == 'meta' and self.in_head:
            self.meta[data.get('name', data.get('property', '')).lower()].append(data.get('content', ''))
        if tag == 'link' and self.in_head:
            self.links.append(data)
        if tag == 'a' and data.get('href'):
            self.anchors.append(data['href'])
        for attribute in ('src', 'href'):
            if data.get(attribute):
                self.references.add(data[attribute])
        if tag in {'script', 'style', 'template'}:
            self.hidden_depth += 1
        if tag == 'script' and data.get('type') == 'application/ld+json':
            self.json_buffer = []

    def handle_endtag(self, tag: str):
        if tag == 'head':
            self.in_head = False
        if tag == 'title':
            self.in_title = False
        if tag == 'script' and self.json_buffer is not None:
            self.jsonld.append(''.join(self.json_buffer))
            self.json_buffer = None
        if tag in {'script', 'style', 'template'}:
            self.hidden_depth = max(0, self.hidden_depth - 1)

    def handle_data(self, data: str):
        if self.in_title:
            self.title_parts.append(data)
        if self.json_buffer is not None:
            self.json_buffer.append(data)
        if not self.in_head and not self.hidden_depth:
            self.text.append(data)


def require(condition: bool, message: str):
    if not condition:
        raise ValueError(message)


def local_target(root: Path, absolute_url: str) -> Path | None:
    parsed = urlparse(absolute_url)
    if parsed.scheme not in {'http', 'https'} or parsed.netloc != urlparse(SITE).netloc:
        return None
    require(parsed.path.startswith(PREFIX), f'Local reference escapes project subpath: {absolute_url}')
    relative = unquote(parsed.path.removeprefix(PREFIX))
    # Vinext emits prefixed assets before the Pages copy normalizes the tree.
    candidates = [root / relative, root / 'ProfileDock' / relative]
    # Normalize flat Vinext route exports to directory URLs in the Pages copy.
    if relative.endswith('/') and relative:
        candidates.append(root / (relative.rstrip('/') + '.html'))
    for candidate in candidates:
        candidate = candidate.resolve()
        require(candidate.is_relative_to(root.resolve()), f'Unsafe local path: {absolute_url}')
        if candidate.is_dir():
            candidate = candidate / 'index.html'
        if candidate.is_file():
            return candidate
    raise ValueError(f'Missing local page/asset for {absolute_url}')


def single_meta(document: Document, key: str, page: str) -> str:
    values = document.meta.get(key, [])
    require(len(values) == 1 and bool(values[0].strip()), f'{page}: expected one nonempty {key}')
    return values[0]


def validate(root: Path):
    analytics = local_target(root, SITE + 'analytics.js')
    require(analytics is not None, 'Missing first-party analytics runtime')
    require("const id = 'G-VTDFFJ1TWQ';" in analytics.read_text(encoding='utf-8'), 'Missing actual ProfileDock measurement ID')
    rendered: dict[str, Document] = {}
    reference_count = 0
    for key, page in PAGES.items():
        group, language = key.split(':')
        pair = PAGE_GROUPS[group]
        target = local_target(root, page)
        require(target is not None, f'No HTML for {page}')
        document = Document(target.read_text(encoding='utf-8'))
        require(single_meta(document, 'google-site-verification', page) == 'myorIcY7TEsKKiQC5rc_fySB15tRPSfyGuDogpgtzfI', f'{page}: missing Search Console verification token')
        require(PREFIX + 'analytics.js' in document.references, f'{page}: missing analytics runtime')
        require(not any(urlparse(ref).netloc.endswith(('googletagmanager.com', 'google-analytics.com')) for ref in document.references), f'{page}: Google resources must load through the preference-aware runtime')
        rendered[key] = document
        require(document.language == language, f'{page}: initial HTML lang must be {language}')
        require(document.title_count == 1 and bool(''.join(document.title_parts).strip()), f'{page}: expected one title')
        require(document.h1_count == 1, f'{page}: expected one visible document h1')
        text = re.sub(r'\s+', ' ', ' '.join(document.text)).strip()
        require(len(text) > 300 and 'Chrome' in text and 'Dock' in text, f'{page}: missing prerendered product content')
        description = single_meta(document, 'description', page)
        require('noindex' not in single_meta(document, 'robots', page).lower(), f'{page}: indexable page marked noindex')
        canonicals = [link.get('href') for link in document.links if link.get('rel') == 'canonical']
        require(canonicals == [page], f'{page}: expected one self canonical, got {canonicals}')
        alternates = [link for link in document.links if link.get('rel') == 'alternate' and link.get('hreflang')]
        expected = {'ru': pair['ru'], 'en': pair['en'], 'x-default': pair['ru']}
        require(len(alternates) == 3 and {link['hreflang']: link.get('href') for link in alternates} == expected,
                f'{page}: incomplete or inconsistent reciprocal hreflang')
        other = pair['en' if language == 'ru' else 'ru']
        require(other in {urljoin(page, href) for href in document.anchors}, f'{page}: no crawlable language-switch link')
        require(single_meta(document, 'og:url', page) == page, f'{page}: og:url differs from canonical')
        require(single_meta(document, 'og:title', page) == ''.join(document.title_parts), f'{page}: social title differs')
        require(single_meta(document, 'og:description', page) == description, f'{page}: social description differs')
        require(single_meta(document, 'twitter:card', page) == 'summary_large_image', f'{page}: missing social card')
        for image_key in ('og:image', 'twitter:image'):
            image = single_meta(document, image_key, page)
            require(image.startswith(SITE), f'{page}: social image URL must be absolute')
            local_target(root, image)
        require(len(document.jsonld) == 1, f'{page}: expected one JSON-LD script')
        schema = json.loads(document.jsonld[0])
        require(schema.get('@context') == 'https://schema.org', f'{page}: incorrect schema context')
        if group == 'home':
            require(schema.get('@type') == 'SoftwareApplication' and schema.get('name') == 'ProfileDock', f'{page}: incorrect app data')
            require(schema.get('url') == page and schema.get('inLanguage') == language, f'{page}: incorrect localized app data')
            require(schema.get('offers', {}).get('price') == 0 and schema.get('isAccessibleForFree') is True, f'{page}: expected honest free offer')
            require(not {'aggregateRating', 'review'}.intersection(schema), f'{page}: ratings require real published evidence first')
        else:
            graph = schema.get('@graph', [])
            expected_type = 'CollectionPage' if group == 'guides' else 'Article'
            entries = [item for item in graph if item.get('@type') == expected_type]
            require(len(entries) == 1, f'{page}: expected one {expected_type}')
            entry = entries[0]
            require(entry.get('url') == page and entry.get('inLanguage') == language, f'{page}: incorrect localized guide data')
            if group != 'guides':
                require(entry.get('headline') and entry.get('datePublished'), f'{page}: missing article metadata')
                require(len(text) > 1800, f'{page}: article body missing from static HTML')
            breadcrumbs = [item for item in graph if item.get('@type') == 'BreadcrumbList']
            require(len(breadcrumbs) == 1, f'{page}: expected one breadcrumb list')
            crumbs = breadcrumbs[0].get('itemListElement', [])
            require(len(crumbs) >= 2, f'{page}: incomplete breadcrumbs')
            for index, crumb in enumerate(crumbs, 1):
                require(crumb.get('position') == index and crumb.get('name'), f'{page}: invalid breadcrumb position/name')
                require(str(crumb.get('item', '')).startswith(SITE), f'{page}: breadcrumb needs an absolute project URL')
                require(local_target(root, crumb['item']) is not None, f'{page}: missing breadcrumb destination')
            require(crumbs[-1].get('item') == page, f'{page}: breadcrumb does not end at this page')
        for reference in document.references:
            absolute = urljoin(page, reference)
            if local_target(root, absolute) is not None:
                reference_count += 1
        print(f'PASS {key}: static content, metadata, paired language link, structured data and local assets')

    titles = [''.join(document.title_parts).strip() for document in rendered.values()]
    descriptions = [document.meta['description'][0].strip() for document in rendered.values()]
    require(len(set(titles)) == len(titles), 'Canonical pages must have distinct titles')
    require(len(set(descriptions)) == len(descriptions), 'Canonical pages must have distinct descriptions')
    # Discover pages from actual HTML links, not merely their sitemap membership.
    by_url = {PAGES[key]: document for key, document in rendered.items()}
    visited, pending = set(), [SITE]
    while pending:
        url = pending.pop()
        if url in visited:
            continue
        visited.add(url)
        for href in by_url[url].anchors:
            absolute = urljoin(url, href).split('#')[0].split('?')[0]
            if absolute in by_url and absolute not in visited:
                pending.append(absolute)
    require(visited == set(PAGES.values()), f'Orphan canonical pages: {set(PAGES.values()) - visited}')

    for group in PAGE_GROUPS:
        require(rendered[f'{group}:ru'].text != rendered[f'{group}:en'].text, f'{group}: language routes rendered identical content')
    for key, document in rendered.items():
        page = PAGES[key]
        for href in document.anchors:
            absolute = urljoin(page, href)
            target = local_target(root, absolute)
            fragment = unquote(urlparse(absolute).fragment)
            if target and fragment:
                destination = Document(target.read_text(encoding='utf-8'))
                require(fragment in destination.ids, f'{page}: broken fragment link {absolute}')
    sitemap = local_target(root, SITE + 'sitemap.xml')
    require(sitemap is not None, 'Missing sitemap')
    tree = ET.fromstring(sitemap.read_text(encoding='utf-8'))
    locations = [node.text for node in tree.findall('{http://www.sitemaps.org/schemas/sitemap/0.9}url/{http://www.sitemaps.org/schemas/sitemap/0.9}loc')]
    require(len(locations) == len(PAGES) and set(locations) == set(PAGES.values()), 'Sitemap must contain exactly the canonical pages')
    print(f'PASS sitemap: {len(PAGES)} canonical URLs; {reference_count} local HTML references and internal fragments verified')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=REPO / 'website/dist/client', help='Built export or copied docs directory')
    arguments = parser.parse_args()
    try:
        validate(arguments.root.resolve())
    except (OSError, ValueError, ET.ParseError) as error:
        raise SystemExit(f'Website SEO validation failed: {error}')
