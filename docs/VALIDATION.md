# Validation record

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

## GitHub CI and final local update

[GitHub Actions run 34162687618](https://github.com/kunilingvistador/ProfileDock/actions/runs/34162687618) passed all 37 XCTest tests and built the packaged app on a separate macOS runner. The final universal build 3 was also launched locally. Updating four existing helper apps preserved all four filesystem identities; Finder retained valid file URLs and opening an updated helper focused its correct window with the original four windows and 102 tabs unchanged.
