# Validation record

## Release candidate: 0.1.5 (11), not yet published

Validated **8 September 2026**, exact application and website source [`addbc13`](https://github.com/kunilingvistador/ProfileDock/commit/addbc132f018310a713642cac32c3e58e08e9c9b). This is an **unpublished release candidate**, not a downloaded public release. It remains ad-hoc signed and unnotarized.

The final local universal ZIP has SHA-256 `0c553844ccc5eb4f9b22e1fe7fdf0d5781663d53426ce900d21303527fab27f4`. An independent extraction into a fresh temporary directory confirmed **0.1.5, build 11**, ZIP CRC integrity, **arm64 and x86_64 in both the controller and launcher**, and **deep strict signature verification**. These checks establish the integrity of this local candidate; they do not establish Developer ID trust, notarization, or clean-Mac Gatekeeper behavior.

[CI 34235067293](https://github.com/kunilingvistador/ProfileDock/actions/runs/34235067293) passed all **5 jobs** for this exact source: native macOS 15/26 × arm64/x86_64 and the static website job. Each of the four Mac jobs passed **77 XCTest tests, 13 Python analyzer tests, and 8 compatibility cases / 134 assertions**, with zero failures, plus architecture, signature, checksum, CRC and extracted-package checks. CI package results apply to the CI-built artifacts; the local build-11 archive was checked separately above. The privacy changes and remaining limits are documented in [PRIVACY-AND-SECURITY.md](PRIVACY-AND-SECURITY.md) and [LOCAL-STORAGE-AUDIT.md](LOCAL-STORAGE-AUDIT.md).

Local checks on the existing Mac covered the candidate's privacy sheet and the final website build's Russian-to-English navigation to the privacy section; the browser log check returned no errors during that interaction. Static build, TypeScript `--noEmit`, and SEO checks passed for the two language pages, sitemap and **44 local asset references**. The website dependency audit returned **0 known findings with `--omit=dev`** and **5 high dependency-graph entries in the remaining Cloudflare development-tool chain**; the privacy report separates these from the static Pages runtime and the native Swift app.

Before/after checks found all **four existing shortcuts' paths, root inodes, bundle IDs and ICNS hashes unchanged**, together with the saved `shortcuts.json` hash and Dock GUID order. The actual data root and `Icons` directory had mode **0700**, and `controller-location.json` had mode **0600**. These are observed checks of this installation, not a claim that existing files were recursively chmodded or that every possible old shortcut has been exercised.

No new focus-performance benchmark was run for 0.1.5. Earlier timing results below retain their original builds and measurement boundaries. Hosted-runner tests do not establish physical Intel Chrome/Dock behavior; live incognito cases, arbitrary remote image servers, DNS rebinding, fresh Automation prompts, clean-Mac installation and the wider Spaces/fullscreen/multi-display matrix remain separate checks. Existing migrated shortcuts can still acquire the previously documented FinderInfo metadata; the local candidate archive's signature result does not resolve that live-bundle limitation. Publication and a fresh download of the eventual release assets are still pending.

## Published beta: 0.1.4 (9)

Validated **8 September 2026**, exact tested source [`639fb3d`](https://github.com/kunilingvistador/ProfileDock/commit/639fb3d166180139cc2adeeddada1a6b5f5d9a42). Published as [v0.1.4-beta](https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.4-beta), targeting merged commit [`d6447b1`](https://github.com/kunilingvistador/ProfileDock/commit/d6447b1d89580310d5b5b726bb9cc76110ec5a7d). The universal ZIP SHA-256 is `402bc9ecc635218044cf62638b99ec33cd01093488b97bb49586de5e7f83c9b1`. This remains an ad-hoc-signed, unnotarized beta.

The [performance report](PERFORMANCE.md) compares instrumented 0.1.3 (7) and 0.1.4 (9) on one Mac: **21 warm and 3 cold-controller samples per build, zero excluded**. Median **helper-first-instruction → activation accepted** duration changed from **206 to 141 ms** warm and **987 to 399 ms** cold. This is not a physical Dock-click, visible-window, first-frame, or keyboard-readiness measurement. Three invalid external observer reports were not used. Historical window-order measurements below have different boundaries and remain separate.

[CI 34228216382](https://github.com/kunilingvistador/ProfileDock/actions/runs/34228216382) passed all **5 jobs** for this exact source. Each native macOS 15/26 × arm64/x86_64 job passed **55 XCTest tests, 13 Python analyzer tests, and 8 compatibility cases / 134 assertions**, plus packaging checks; the fifth job built the website. Local candidate checks confirmed that the manager opens after a background cold launch and shows four ready shortcuts. In all three measured cold chains it was not constructed before activation acceptance. The performance report distinguishes current live checks, static/unit coverage, and scenarios still awaiting live verification.

The final local build-9 ZIP was extracted into a fresh temporary directory and passed **deep strict signature verification**. Both packaged binaries contained **arm64 and x86_64**, and the archive contained no private icons or user settings. All four existing live shortcut paths, root inodes, bundle IDs, and icon bytes remained unchanged, as did the original `shortcuts.json` hash and Dock GUID order. Opening an existing shortcut's settings and cancelling succeeded. This does not supersede the historical FinderInfo limitation on migrated applets: archive integrity and live applet signatures are separate checks.

After publication, the ZIP and `SHA256SUMS` were downloaded from GitHub into a fresh temporary directory. The hash matched the checksum file and the value above. The extracted app reported **0.1.4, build 9**, passed **deep strict signature verification**, and contained **arm64 and x86_64** in both binaries. This download check does not establish clean-Mac Gatekeeper or first-permission behavior.

One later manager-button switch produced a screenshot of the expected existing Chrome window. The accessibility snapshot from the same call identified a different window; the cause is unknown. This is one visual spot-check, not a validated visible-latency or keyboard-focus result. No personal names, page contents, or screenshots are published. After testing, the tracing flag was removed and the controller restarted; read-only checks confirmed one current controller and no trace file for its new process.

## Compatibility beta: 0.1.3 (6)

The in-place legacy-shortcut migration, preserved file/data identities, complete backups, live launcher checks, and exact-source CI are recorded in [SHORTCUT-COMPATIBILITY.md](SHORTCUT-COMPATIBILITY.md). That record also documents the observed iCloud FinderInfo/signature limitation.

## Historical beta: 0.1.2 (5)

The interface, website, SEO, package and exact-source CI checks for this release are recorded in [DESIGN-VALIDATION.md](DESIGN-VALIDATION.md). The earlier window-activation measurements below retain their original candidate and scope.

## Historical candidate: 0.1.1 (4)

Validated **8 September 2026**, source commit `9155f134705cdb4d69d0f04c4143e7edf0e65462`. Live desktop: **macOS 26.5.2, arm64, Chrome 152.0.7977.76**. The exact local universal archive has SHA-256 `041e658d634ed0a98b179ba452de1ac7942b5f30389f4d8efcdc8414f1a21758`.

- Selected one of two identically titled temporary windows, previewed it, returned with Enter, and created/exported a shortcut with its name and selection retained.
- Preview and relink exclude windows owned by other shortcuts. The picker and save action use the same eligibility list.
- Closed the linked temporary window, invoked its real helper, and used **Choose window** in the error directly to enter recovery.
- Previewed another temporary window and relinked the shortcut. The same existing helper then focused the new window; it was not re-exported.
- Removed both temporary windows and the temporary shortcut. The exported test helper was moved out of the live Launchers folder.
- All 104 original working tabs survived the full session. Two additional tabs and a changed active tab appeared in a working window during concurrent browser activity; the long session is therefore not claimed as an unchanged baseline.
- A final short check recorded state immediately before and after one launch of each of four working helpers: **four windows and 106 tabs matched exactly**, including window/tab IDs, selected tabs, names, minimized state, and bounds; z-order is intentionally excluded.

### Launcher timing on this Mac

The standalone harness starts a real helper using `NSWorkspace.openApplication`. It stops the monotonic timer when Chrome is frontmost and the target is the first visible normal window in the window-server order. This is **not a first-painted-frame or physical Dock mouse-click measurement**. Baseline setup and computer-use tool latency are excluded.

| Scenario | Samples | Result |
| --- | ---: | --- |
| Warm controller, four working shortcuts | 40 | 40 successful; median **329 ms**, nearest-rank p95 **381 ms**, range **270–393 ms** |
| Cold controller; Chrome already running | 1 | **765 ms**, success |
| Restore minimized temporary target | 1 | **543 ms**, success |
| Existing helper after relink | 1 | **280 ms**, success |

Cold/minimized timings are single observations, not typical or percentile estimates. Earlier development trials varied with machine state; these numbers cannot establish the isolated effect of script caching or promise performance on other Macs. The controller caches compiled AppleScript on its serial queue and retains at most 100 identifier-free diagnostic timing samples in memory.

### Final automated and package checks

[GitHub CI 34209812166](https://github.com/kunilingvistador/ProfileDock/actions/runs/34209812166) passed **5/5 jobs** for the source commit above:

| Native runner | Actual macOS | XCTest | Other checks |
| --- | --- | --- | --- |
| Apple Silicon, macOS 15 | 15.7.9 | 37 passed | Harness typecheck, native package integrity |
| Intel, macOS 15 | 15.7.9 | 37 passed | Harness typecheck, native package integrity |
| Apple Silicon, macOS 26 | 26.6.2 | 37 passed | Harness typecheck, universal package integrity |
| Intel, macOS 26 | 26.6.1 | 37 passed | Harness typecheck, native package integrity |

The fifth job built the static website. The previous Apple-event/MainActor compiler warning is absent from the final Mac logs. The local final ZIP separately passed SHA-256, CRC, universal-architecture checks for both binaries, and strict signature verification after extraction into a fresh directory.

**Limits:** native tests on hosted Intel runners do not verify the live Chrome/Dock UI on a physical Intel Mac. Spaces, fullscreen, Stage Manager, multi-display arrangements, revoked permissions, clean-machine Gatekeeper onboarding, and rapid competing helper launches still need focused desktop tests. This local package is ad-hoc signed and **not notarized**. Existing personal legacy Dock applets were not replaced by this iteration; measured helpers are the apps exported by ProfileDock.

## Historical candidate: 0.1.0 (3)

Validation date: **8 September 2026**. Candidate: **0.1.0 (3)**, local beta. Live checks ran on **macOS 26, Apple Silicon (arm64), with Google Chrome** during development of this candidate. Package checks below apply to the final build 3 archive. This record describes observed behavior on that setup; the unverified cases below remain release work.

## Live window checks

The baseline contained four working Chrome windows with **102 tabs**. The final snapshot of those working windows matched the baseline for window IDs, tab IDs, selected tabs, and window bounds. A separate temporary test window and its shortcut were removed after testing.

| Check | Observed result |
| --- | --- |
| Import existing shortcuts | Four existing shortcuts and their custom icons were imported. |
| Switch to an existing window | The selected working window was brought forward. No extra browser window was created. |
| Warm Dock helper | A generated helper delivered its request to an already running controller and selected the bound window. |
| Cold controller launch | The helper started the controller in the background and selected the bound window. |
| Minimized target | The target was restored and focused. |
| Create a binding | A separate temporary Chrome window was connected to a new shortcut. |
| Website icon | An explicitly requested favicon was fetched and applied during the temporary-shortcut test. |
| Closed target | Clicking the shortcut after its target closed produced a meaningful missing-window error; it did not create a replacement window. |
| Cleanup | The temporary browser window and temporary shortcut were removed. The four working windows retained their baseline tabs, selections, and geometry. |

These checks used window and tab identifiers plus window state. This public record includes no account names, personal paths, website addresses, or browser contents.

## Core behavior checks

**37 core test methods and 247 assertions passed through a local Command Line Tools-compatible harness.** The checks cover model and parsing behavior such as binding resolution, route validation, filenames, configuration storage, profile discovery, and favicon discovery.

This was not an XCTest runner execution. The standalone Command Line Tools installation on the test machine lacked the XCTest module, so a normal `swift test` run could not complete there. The repository includes a GitHub Actions workflow using a macOS runner with full Xcode for the standard test command. The subsequent GitHub CI run used the standard XCTest runner and passed all 37 tests; see the linked result below.

## Generated shortcut update fixture

A real temporary exporter fixture checked updates to a generated shortcut's name and icon. Both updates preserved the app root's inode and file resource identifier. Existing Foundation file-reference URLs and bookmarks continued to resolve to that same app. The updated display names were correct, and the installed helper signatures remained valid.

This fixture exercised actual generated app bundles and filesystem references. A live Finder/Dock reference check after an update is tracked separately below.

## Build and package checks

- Production builds succeeded for **arm64 and x86_64**.
- Both the controller and Dock helper were combined into universal binaries, and their architecture lists were checked.
- The app reports version **0.1.0**, build **3**, a macOS 13 minimum, and English/Russian localizations.
- English and Russian Automation permission strings were included and parsed successfully. Their appearance in a newly presented system permission dialog was not re-tested after packaging.
- Strict code-signature verification passed for the app and helper.
- The final ZIP passed its CRC check, and its SHA-256 matched `SHA256SUMS`.
- The ZIP was extracted into a fresh temporary directory, and strict verification passed on the extracted app.
- The original generated app icon was visually inspected.

The package is **ad-hoc signed and unnotarized**. Signature integrity checks do not establish Developer ID trust or notarization. Intel binaries compiled successfully; **the app was not run on an Intel Mac**.

## Still to verify

- Clicking an existing Dock pin after rename/icon updates; file identity, bookmarks, and the live Finder path have already been checked.
- Runtime behavior on an Intel Mac and on older supported macOS versions.
- Multiple Spaces, fullscreen windows, multiple monitors, and Stage Manager.
- App-wide Hide and its interaction with focus handoff.
- Revoked Automation permission and recovery through System Settings.
- A clean-machine installation of the final downloaded package, including Gatekeeper and first-run permissions.
- Developer ID signing, notarization, and an upgrade with existing shortcuts.

Use the [architecture checklist](ARCHITECTURE.md#integration-checks-before-release) for broader regression coverage and the [release guide](RELEASE.md) for the public distribution steps.

## Expanded CI configuration

On **8 September 2026**, the workflow was expanded to native XCTest jobs on macOS 15 and 26, each on Apple Silicon and Intel. The macOS 26 Apple Silicon job also packages a universal app. Each job verifies its actual environment, packaged architectures, signature integrity, checksum, and archive extraction. The website builds once in a separate Linux job.

The expanded matrix subsequently **passed for candidate 0.1.1**; see the current candidate record above. The historical run below covers the earlier workflow only. This change does not resolve the live Intel UI, older macOS, Spaces, displays, permissions, or notarization checks above. See [TEST-MATRIX.md](TEST-MATRIX.md) for the runnable CI coverage, live scenarios, and timing protocol.

## GitHub CI and final local update

[GitHub Actions run 34162687618](https://github.com/kunilingvistador/ProfileDock/actions/runs/34162687618) passed all 37 XCTest tests and built the packaged app on a separate macOS runner. The final universal build 3 was also launched locally. Updating four existing helper apps preserved all four filesystem identities; Finder retained valid file URLs and opening an updated helper focused its correct window with the original four windows and 102 tabs unchanged.
