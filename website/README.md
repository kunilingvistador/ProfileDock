# ProfileDock website

Run `npm ci` and `npm run build` with Node.js 22.13+. The static export is in `dist/client`; the deployed copy is in `../docs`. The site is hosted on GitHub Pages at https://kunilingvistador.github.io/ProfileDock/.

Russian and English have separate static URLs: `/ProfileDock/` and `/ProfileDock/en/`. The route groups provide the correct initial HTML language and share `components/Landing.tsx`. Metadata and factual application JSON-LD come from `lib/seo.ts`.

Run `npm run validate:seo` after building. It checks both actual HTML documents, self canonicals, reciprocal language links, structured data, sitemap and referenced local assets. `public/social-preview.png` is the social card image; replace it only with an accurate public preview.

To refresh the local Pages copy, run `python3 ../scripts/publish-website-files.py` after building. This normalizes Vinext’s prefixed static assets for GitHub Pages, includes the English route and public assets, and validates the copied tree again. For an isolated rehearsal, pass `--dest /path/to/temporary/pages`. The script only copies files; publishing still requires committing and deploying the result.

CI runs the same copy/validation in a temporary directory. See [the SEO notes](../docs/SEO.md) for scope, primary references and remaining live checks.

The Pages publisher also generates `sitemap-pages.xml` as a byte-for-byte alias of `sitemap.xml` for one controlled Search Console fetch diagnostic. Edit only `public/sitemap.xml`; do not add a separately maintained alias under `public/`. The original address, canonical URLs and modification dates stay in place. The validator checks an alias when present, while the initial Vinext export need not contain it. An alternative address is a diagnostic, not a confirmed fix or a promise of crawling, indexing or traffic; record Google's actual processing result following its [sitemap troubleshooting guidance](https://support.google.com/webmasters/answer/7451001?hl=en).

## Release content checks

Keep instructions aligned with the released manager: add uses + in the native toolbar; names, pictures, window connections and Dock export live in each card’s ⋯ menu. Manager keys (⌘F, arrow keys, Return) are distinct from optional global hotkeys. Home and overview images use sample data, never a person’s account names or real window titles. Current overview captures and earlier editor captures are identified separately in the guides.

After a release change, rebuild and re-run SEO and analytics validation before copying the Pages tree. Keep the existing RU/EN URL pairs, self canonicals and `G-VTDFFJ1TWQ` measurement runtime. `lastmod` and Article dates track meaningful content edits, not every build; update only the relevant sitemap entries. Downloads are link clicks, not installations, and the native app has no analytics.

This follows Google’s guidance on [helpful content](https://developers.google.com/search/docs/fundamentals/creating-helpful-content), [accurate sitemap dates](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap) and [crawl requests](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl). A successful export and a valid sitemap do not prove Google has crawled or indexed the update. Check actual Search Console results after deployment; repeated requests do not speed up crawling.
