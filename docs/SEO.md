# Website SEO

Technical review updated: **9 September 2026**. Scope: ProfileDock's GitHub Pages project site. This work does not establish search volume, rankings, indexing, or traffic gains.

## Guides and discovery update

The site now contains **eight canonical pages**: two home pages, two guide indexes, and two complete guides in Russian and English. One guide covers initial Dock-shortcut setup; the other covers the difference between a profile and a window, diagnostics, and reconnecting existing shortcuts. Both are linked from the landing page, navigation, guide indexes and each other.

Each translation pair has its own reciprocal hreflang and self-canonical URLs. Articles have factual Article and BreadcrumbList structured data, indexes use CollectionPage and BreadcrumbList, and the home pages retain SoftwareApplication. Dates reflect the publication content update; there are no fabricated authors, ratings or traffic claims. All guide bodies and links are included in the static HTML.

The copy script now normalizes nested Vinext flat HTML exports to directory/index.html URLs. Validation checks all eight pages, metadata, paired language links, sitemap membership, resources and internal fragment links. The previous Markdown project documentation is preserved during the generated-file copy.

The repository's homepage and nine relevant topics were added on 9 September. The README links to the guides and existing interactive demonstration and shows a screenshot using sample profiles. Voluntary public GitHub feedback forms ask for actionable steps and versions while requesting that private information be omitted. These changes introduce no website analytics or app telemetry.

Google Search Console ownership verification and sitemap submission remain pending. An accessible account did not have access to this project property; no ownership claim or unrelated account change was made. A sitemap file on the site is not proof it has been submitted or indexed.

## Changes and rationale

The former page switched between Russian and English using client state at one URL; its initial document and metadata remained Russian. The site now has separately rendered Russian `/ProfileDock/` and English `/ProfileDock/en/` documents, with their own initial `<html lang>`, titles, descriptions, and visible content. Ordinary links connect the languages. Separate URLs make both versions directly accessible without a language cookie or browser setting. [Google: multilingual sites](https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites)

Both pages use an absolute self canonical and reciprocal `ru`, `en`, and `x-default` alternate links. The Russian root is the fallback, preserving the existing public URL. The case-sensitive GitHub Pages project prefix is included everywhere. [Google: localized versions](https://developers.google.com/search/docs/specialty/international/localized-versions), [canonical URLs](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls)

Localized titles and descriptions describe the actual use case: recognizable Dock shortcuts for existing Chrome windows on macOS. Open Graph and Twitter metadata support sharing with an accurate public preview. Google can choose its own title and snippet; the metadata is a clear description, not control over the final search result. [Google: title links](https://developers.google.com/search/docs/appearance/title-link), [descriptions](https://developers.google.com/search/docs/appearance/snippet)

Each home page includes factual `SoftwareApplication` JSON-LD with a free offer, operating system, utility category, source and license links. There are **no invented ratings, reviews, downloads, or awards**. Google currently requires a genuine rating or review for its software-app rich result, so the present markup alone does not establish eligibility for that feature. Structured data also does not guarantee a rich result. [Google: software-app requirements](https://developers.google.com/search/docs/appearance/structured-data/software-app), [structured-data policies](https://developers.google.com/search/docs/appearance/structured-data/sd-policies)

The sitemap contains the eight absolute canonical page URLs. It does not assign artificial priorities or mark every build as a content update. A sitemap under `/ProfileDock/` is appropriate for these descendant URLs. [Google: sitemap guidance](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap)

## GitHub Pages and robots.txt

Google checks `https://kunilingvistador.github.io/robots.txt`, **not** `/ProfileDock/robots.txt`. This project repository does not control the host's root file, so no ineffective project-level robots.txt is presented as an SEO fix. Public pages contain no `noindex` directive. After publishing, verify the live root robots response and actual page headers. [Google: robots.txt location and scope](https://developers.google.com/crawling/docs/robots-txt/robots-txt-spec)

## Repeatable checks

From `website/`, run:

```sh
npm ci
npm run build
npm run validate:seo
python3 ../scripts/publish-website-files.py --dest /tmp/profiledock-pages-check
```

The validator reads the generated HTML rather than assuming the metadata API rendered correctly. It checks initial language and product content, one title/H1/description, self canonical, reciprocal hreflang, an actual language-switch anchor, social metadata and assets, factual JSON-LD, sitemap scope, local page/asset references and internal fragments. The copy script normalizes Vinext's assets and all eight routes, includes public files, preserves Markdown project documentation, and validates the copied tree again. CI performs the same check in its temporary directory. These checks do not prove Google has indexed a page or replace testing the live deployment.

All eight content routes explicitly require static rendering. With the pinned Vinext beta, enabling `trailingSlash` caused the `/en` prerender request to return a redirect and be skipped. The build therefore keeps Vinext's `en.html` output, and the Pages copy places that rendered document at `en/index.html` for the canonical `/en/` URL. This is a packaging adjustment; the document's content and metadata are rendered normally, without a client-only language substitution.

## Content direction and later measurement

Useful search-intent hypotheses include “Chrome profile switcher Mac”, “Chrome profile Dock shortcuts”, “switch existing Chrome window without new tab”, “ярлыки профилей Chrome Mac”, and “переключение профилей Chrome в Dock”. These are unmeasured wording hypotheses. The page should answer what a click does, how setup works, whether existing tabs remain open, how a closed target is reconnected, and which platform is supported. Avoid publishing thin pages for every variation of these phrases.

After the actual deployment, verify all eight URLs and the sitemap return the intended content, test the structured data, and use an owner-verified Search Console URL-prefix property to inspect indexing and submit the sitemap if desired. No Search Console submission is performed by the build script or this implementation. Track impressions, real queries, clicks, and click-through rate separately by language and device before deciding on further content. No baseline search dataset is available yet.
