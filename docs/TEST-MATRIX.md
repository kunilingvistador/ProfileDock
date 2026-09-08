# Testing ProfileDock with one development Mac

The automated matrix checks native core execution and packaging on two macOS versions and two processor architectures. Live desktop behavior needs a separate record. A successful build or XCTest run does not prove that a Chrome window appeared in the correct Space, that a permission dialog was understandable, or that a Dock click felt immediate.

## Automated coverage

Configured on **8 September 2026** in [the build workflow](../.github/workflows/build.yml):

| Runner | Native XCTest execution | App package checked |
| --- | --- | --- |
| `macos-15` | macOS 15, Apple Silicon | arm64 |
| `macos-15-intel` | macOS 15, Intel | x86_64 |
| `macos-26` | macOS 26, Apple Silicon | universal arm64 + x86_64 |
| `macos-26-intel` | macOS 26, Intel | x86_64 |

These are standard public-repository runner labels; GitHub currently provides their compute free for public repositories. Avoid substituting `-large` or `-xlarge` runners when keeping the project free. Explicit OS labels avoid an unnoticed `macos-latest` migration. Installed Xcode and patch versions can still change, so each run records them. [GitHub runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

Every macOS job:

1. Confirms the actual OS major version and native processor architecture, and records macOS, Xcode, Swift, and the selected developer directory in its summary and artifact.
2. Runs `swift test --scratch-path "$RUNNER_TEMP/ProfileDock-tests"` using the hosted Xcode installation.
3. Builds the app and helper in release mode with `scripts/build.py`. The macOS 26 arm64 job also cross-compiles the Intel slice and creates a universal package.
4. Checks the app and helper architectures, code-signature integrity, ZIP CRC, and SHA-256. It extracts the archive with `ditto` and repeats the binary/signature checks.
5. Uploads separately named, ad-hoc signed development artifacts for 14 days. These are unnotarized test builds, not an automatic public release.

The static website builds once on `ubuntu-24.04`, outside the macOS matrix. Independent matrix jobs continue if one fails. A newer run for the same branch cancels an obsolete run.

**Status:** this document describes configured coverage. It is not evidence that the expanded matrix has passed; record a completed run URL in [VALIDATION.md](VALIDATION.md) after running it. Existing historical validation remains tied to its original candidate and runner.

## Coverage that requires a desktop session

Use a temporary Chrome window with generic content and a temporary shortcut for destructive scenarios. Before and after tests involving working windows, record their IDs, tab IDs, selected tabs, bounds, and minimized state. Do not close personal tabs, reset Chrome, or revoke production permissions merely to make a fixture convenient.

| Scenario | Expected result and evidence |
| --- | --- |
| First connection and shortcut creation | The user can recognize the selected window and understand what the shortcut will do. Capture the selection, confirmation, and completion states. |
| Warm helper click | The bound existing window comes forward; no extra window or tab appears and the manager does not cover it. Record helper-to-focus elapsed time separately from tool overhead. |
| Cold controller click | Start with ProfileDock closed and Chrome still running. The helper starts the controller in the background and focuses the correct existing window. |
| Repeat and rapid clicks | Repeated clicks create no windows or tabs. Alternating shortcuts ends at the last requested target; record any intermediate flicker or blocked input. |
| Minimized target / hidden Chrome | The selected target becomes visible. Check that unrelated Chrome windows are not raised with it. Restore the original state. |
| Closed, renamed, or ambiguous target | Explain the specific problem and offer a usable recovery path; no silent selection of another profile or automatic empty replacement window. |
| Window preview and rebinding | Preview is reversible and does not rename or bind a window. Saving binds only the confirmed choice; cancellation preserves the previous shortcut. |
| Helper rename or icon update | An already pinned Dock item still opens its correct target and shows the updated label/icon. File-reference checks alone do not prove live Dock behavior. |
| Fullscreen, Spaces, Stage Manager | Record the arrangement and relevant macOS settings. Check the target becomes usable and that other windows retain their positions. Do not generalize one arrangement to all settings. |
| Multiple displays | Repeat focus and recovery with the target on each display; record display arrangement and whether Spaces are separate per display. |
| Permissions and clean installation | On a spare account or test Mac, test first permission request, denied/revoked permission, recovery, and the downloaded archive's Gatekeeper behavior. Never automate consent. |
| Keyboard and accessibility | Complete creation and recovery using only the keyboard; check focus order, visible focus, button names, and a VoiceOver pass. Screenshots alone cannot establish accessibility. |

The supported minimum is currently macOS 13, but the routine hosted matrix covers **15 and 26**. macOS 13/14 desktop behavior remains unverified until tested. Native Intel XCTest execution is stronger than cross-compilation, but it still does not exercise the complete Intel app/Chrome UI flow.

## Measuring speed without measuring the automation tool

Report two distinct timings where instrumentation permits:

- **Controller response:** from receipt of the focus request to completion of the Chrome command and activation request. This helps diagnose code changes, but is not proof that a frame is visible.
- **Visible switch:** from the helper/click request to independently observing the target window become frontmost. State the observer and its sampling interval. A slow screenshot or remote-control round trip must not be included as app latency.

Measure warm and cold controller launches separately; also separate ordinary and minimized targets. Preserve raw monotonic timestamps locally. Record candidate version, OS, architecture, Chrome version, number of windows/tabs, sample count, and failures. Use only timings and anonymous test IDs in public results, not browsing history or account names.

For a repeatable benchmark, collect at least 20 warm trials and five cold-controller trials. Report the warm median and worst observed result; report cold trials individually at this small sample size. Larger samples can support percentile comparisons. Proposed UX targets should be labeled as targets until measured on the stated setup. A focus call returning successfully is not sufficient: check the target and absence of extra windows/tabs too.

## Extending coverage without buying another Mac

Use the hosted matrix for native Intel/Apple Silicon core checks now. For full desktop flows, invite a small set of volunteers to test the exact same downloadable candidate on their Macs, prioritizing one Intel machine and one older supported macOS version. Supply the scenario table and ask for the build number, OS, processor family, Chrome version, observed result, and an optional screenshot with private information removed.

A separate local macOS user account is useful for a clean ProfileDock configuration and first-run flow on the existing machine; it does not add OS or hardware coverage. A compatible local macOS virtual machine can add another OS environment, but still does not substitute for different physical displays, Intel hardware, or all window-management behavior. These are additional test environments, not evidence until a scenario has actually passed there.

Each validation entry should include: **candidate → environment → steps → observed result → timing/screenshot/log → remaining uncertainty**. Link that record from the issue or change that it validates.
