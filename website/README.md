# ProfileDock website

Run `npm ci` and `npm run build` with Node.js 22.13+. The static export is in `dist/client`; the deployed copy is in `../docs`. The site is hosted on GitHub Pages at https://kunilingvistador.github.io/ProfileDock/.

To refresh the deployed copy, run `python3 ../scripts/publish-website-files.py` after building. This normalizes Vinext’s prefixed static assets for GitHub Pages. Commit the resulting docs changes.
