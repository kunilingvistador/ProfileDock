# Design and website validation

Date: **8 September 2026**. The local native candidate reports **0.1.2 (5)**. This record covers the interface implementation, local verification and published beta/website. It does not replace the separately scoped window-activation regression record in [VALIDATION.md](VALIDATION.md).

## Native interface implementation

Source review confirms these changes:

- A single main column replaces the sidebar, keeping connection status, help and shortcut actions together.
- Each card exposes **Customize** and **Create Dock shortcut** directly. **Switch** is the prominent action for a ready window; a missing or ambiguous binding offers **Choose window**.
- Search has a clear action and an explanatory empty state. Adding a shortcut clears the previous search. Switching uses an explicit button rather than a card double-click gesture.
- Shortcut names, status labels and avatars are larger. Controls have specific accessibility names, and the name field has a visible label with more usable width.
- Help describes the existing window-preview step. Semantic macOS colors support system appearances without asserting that every appearance has passed visual review.
- `--demo-dark` and `--demo-compact` provide repeatable sample-window states when used with `--demo`; they do not change system appearance or manipulate Chrome.

The current public app image was visually checked: it contains only the generic **Studio**, **Personal** and **Research** shortcuts and the interface-preview notice. It demonstrates the light sample state, not a successful live browser switch. The branded social image uses that same generic interface capture.

## Website and SEO checks completed

The final source removes the unsupported claim that users can choose shortcut colors. The demo instruction now uses `#6b6179`; its calculated contrast against the three declared background gradient stops is **5.01–5.28:1**. This is a targeted contrast calculation, not a complete accessibility certification.

The following local checks passed after these corrections:

| Check | Result |
| --- | --- |
| Production build | Three prerendered routes including the not-found output; zero skipped routes. RU and EN product pages are static. |
| TypeScript | `tsc --noEmit` passed during this design iteration. |
| Built HTML | Initial `lang`, localized title/description, one H1, substantial visible product text, and a real language-switch anchor checked for both languages. |
| Search metadata | Self canonicals, reciprocal RU/EN/x-default alternates, social metadata, factual application JSON-LD, and a two-URL sitemap passed. |
| GitHub Pages copy | Source export and copied `docs` tree both passed the validator; 34 local HTML references checked in each tree. Both preview images are included. |
| Source hygiene | Python/YAML syntax and `git diff --check` passed. Generated Next type declarations and TypeScript build state are ignored. |

The export handles the pinned Vinext trailing-slash redirect issue by copying rendered `en.html` to `en/index.html`. Both pages require static rendering, so a skipped locale cannot silently produce a successful release check. The CI website job now exercises this same export and validation. [CI 34214729730](https://github.com/kunilingvistador/ProfileDock/actions/runs/34214729730) passed all five jobs for exact source `d2649d3a588f1aab238be6736e3869bcfecf0af7`: each macOS 15/26 × Apple Silicon/Intel runner passed 37 XCTest methods and package-integrity checks; the website job passed static export and SEO validation.

See [SEO.md](SEO.md) for primary Google documentation, robots.txt scope, the absence of genuine ratings for software-app rich results, and the distinction between valid metadata and actual indexing. Search Console submissions and indexing outcomes are not claimed here.

## Artifact sizes and privacy review

These totals compare the previously copied site with this local candidate. Gzip values are estimates calculated per file, not observed network transfers or page-load timings.

| Artifact | Previous | Candidate |
| --- | ---: | ---: |
| JavaScript, all shipped chunks | 434,348 B | 410,099 B |
| JavaScript, estimated gzip | 133,235 B | 125,099 B |
| CSS | 180,338 B | 17,090 B |
| CSS, estimated gzip | 28,002 B | 4,488 B |

Candidate RU/EN HTML is **40,967 / 36,661 B**. The app preview JPEG is **72,943 B** and the social PNG is **53,772 B**. The social image is metadata for sharing; its size should not be counted as an automatic browser image request without observing such a request.

Static inspection found no automatically loaded third-party resources in either initial HTML document or the generated CSS. External navigation links lead to the project's GitHub repository, releases, issues and license. Landing-page source adds no analytics, cookies, browser storage, or fetch calls. A targeted text scan of public files found no local user paths or known personal profile/account data; both public images were also inspected visually. This is a scoped source/artifact review, not proof about all runtime network activity.

## Runtime checks completed on the local Mac

Observed on macOS 26.5.2 / Apple Silicon, local candidate **0.1.2 (5)**:

- Native English light preview at 940 × 692 and Russian dark preview at the minimum 860 × 600 passed visual review. Shortcut controls and status labels fit; edit and help sheets remain readable.
- Renaming a sample shortcut and saving with Enter updated the card. Escape cancelled editing. Empty-search guidance and its clear action appeared; opening Add cleared the old query. The sample Add sheet correctly disabled creation when no unlinked windows were available. Help closed with Enter.
- The normal app was reopened after preview-only testing. Four existing shortcuts were retained and reported their windows ready. This is a configuration/connection check, not a rerun of the earlier live window-preservation benchmark.
- The built static site was exercised in the Codex in-app browser at desktop size, 390px and 320px widths. Both languages fit without horizontal overflow. A real link navigated to the English URL with English initial document language/title/content, and back to Russian.
- Demo buttons changed the active window and `aria-pressed` state by click and Enter. FAQ opened with click and Enter. Anchor navigation worked. The checked browser console contained no warning/error entries.
- The native app screenshot loaded correctly on mobile and desktop. An initial full-page capture caught a partially painted lazy image; a subsequent viewport inspection confirmed the complete image. Only the later fully painted captures are accepted visual evidence.

The final local universal archive is `ProfileDock-0.1.2-macos-universal-local.zip`, SHA-256 `85b956a1dc0c0b6bbb225a0a3f95a96986563690ba774d65918aaf4571273d26`. It is ad-hoc signed and not notarized.

Still outside this pass: VoiceOver end-to-end, live Chrome GUI behavior on Intel/macOS 13–14, fullscreen/Spaces/Stage Manager, exhaustive runtime network tracing, measured website paint/input latency, and an actual reduced-motion OS/browser emulation. Reduced-motion CSS and focus styles were inspected in source. Do not treat artifact-size reductions as measured load-time improvements.

## Publication verification

[Version 0.1.2 beta](https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.2-beta) is published as an explicit prerelease. Its uploaded archive digest and checksum file match the verified local files. The release targets merge commit `2ede45db09f34d6d2e9ab19badb03d33b801cdb1`; its source tree matches the CI-tested source commit above.

GitHub Pages reported a successful build of that merge commit. HTTPS checks on the Russian page, English page, sitemap, social PNG and app JPEG returned **200** with bytes identical to the verified export. The live browser displayed the new Russian title, headline and English navigation link. The origin-level `/robots.txt` returned **404**, so no root robots file was observed; no ineffective project-subpath robots file was added. These checks establish published content, not Google indexing or ranking.
