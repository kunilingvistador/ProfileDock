# ProfileDock website

Run `npm ci` and `npm run build` with Node.js 22.13+. The static export is in `dist/client`; the deployed copy is in `../docs`. The site is hosted on GitHub Pages at https://kunilingvistador.github.io/ProfileDock/.

Russian and English have separate static URLs: `/ProfileDock/` and `/ProfileDock/en/`. The route groups provide the correct initial HTML language and share `components/Landing.tsx`. Metadata and factual application JSON-LD come from `lib/seo.ts`.

Run `npm run validate:seo` after building. It checks both actual HTML documents, self canonicals, reciprocal language links, structured data, sitemap and referenced local assets. `public/social-preview.png` is the social card image; replace it only with an accurate public preview.

To refresh the local Pages copy, run `python3 ../scripts/publish-website-files.py` after building. This normalizes Vinext’s prefixed static assets for GitHub Pages, includes the English route and public assets, and validates the copied tree again. For an isolated rehearsal, pass `--dest /path/to/temporary/pages`. The script only copies files; publishing still requires committing and deploying the result.

CI runs the same copy/validation in a temporary directory. See [the SEO notes](../docs/SEO.md) for scope, primary references and remaining live checks.
