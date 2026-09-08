# Build and release

The current published download is an **ad-hoc-signed, unnotarized beta**. The normal Developer ID distribution process below remains future release work. GitHub Actions builds development artifacts; it does not create a GitHub Release or publish a site.

## Local build

Requires macOS 13+, Apple Command Line Tools with Swift 5.9+, and Python 3. The full Xcode IDE is not needed for this SwiftPM build. Check your selected toolchain with `xcrun swift --version`.

```sh
python3 scripts/build.py
```

Outputs:

- `dist/ProfileDock.app`
- `dist/ProfileDock-0.1.3-macos-<architecture>-local.zip`
- `dist/SHA256SUMS`

The default targets the current machine, signs ad-hoc, and does not contact the Apple notary service. Use `--universal` to combine arm64 and x86_64 builds. `--scratch-path` controls the SwiftPM cache; the default is outside the repository in the system temporary directory. The script only replaces an existing `dist/ProfileDock.app` if its bundle identifier belongs to this project.

Run `swift test` with a full Xcode installation selected before releasing. XCTest is unavailable in the standalone Command Line Tools environment used for the initial local build, even though that toolchain can compile the app. CI uses a macOS runner with full Xcode. End users of the packaged app need only macOS 13+ and Chrome, not these developer tools.

No signing certificate, personal browser data, account name, custom photo, or user configuration belongs in the source tree or archive. Packaging includes the compiled executables, generated original icon, and app metadata only.

## 0.1.3 compatibility candidate

This candidate keeps the existing UUID focus route and version-1 state format. It adds controller-location tracking, refreshes existing owned helpers when the manager is opened, and offers explicit conversion of compatible older applets. It does not add an automatic app downloader or change Chrome window names. See [shortcut compatibility and backups](SHORTCUT-COMPATIBILITY.md).

Results recorded on **8 September 2026** for **0.1.3, build 6**:

| Check | Result |
| --- | --- |
| Temporary-filesystem compatibility suite | 8 cases, 134 assertions passed. |
| Standard XCTest | 52 tests passed on each of four macOS 15/26 arm64/x86_64 runners. |
| Four live legacy Dock applets | Configuration bytes, UUIDs, bundle IDs, root inodes, and all icon hashes preserved; Dock GUIDs and order unchanged. Each original `Contents` backup matched completely. |
| Launching the four original app files | Finder double-clicks through UI automation each brought the correct existing Chrome window forward. |
| Repeating Update shortcuts | The interface reported that compatible shortcuts were up to date; four records remained, with no duplicates. |
| Full CI for `5b91351` | All five jobs passed: four native macOS jobs, including package verification and archive checks, plus the website build. |
| Local release ZIP | Extracted into a fresh temporary directory; deep strict signature verification passed, both binaries contained arm64 and x86_64, and version 0.1.3/build 6 contained no user settings. |

**Known limitation:** in iCloud Documents, the app-root FinderInfo flag `0x2000` reappeared after successful installation-time signature verification. Later `codesign --strict` checks failed on those migrated applets, although all four launched correctly. The cause remains under investigation; do not describe these four bundles as permanently passing strict signature verification. See the [compatibility record](SHORTCUT-COMPATIBILITY.md#checked-for-013-build-6) for scope.

[CI run 34223725465](https://github.com/kunilingvistador/ProfileDock/actions/runs/34223725465) completed successfully for source `5b91351`. Its package results apply to the CI-built artifacts, separately from the live migrated applets and their FinderInfo limitation above. Release publication is pending.

The current build-6 ZIP has SHA-256:

```text
75905a29fe0c9363e10c3e58b413af092ad81568a0865f53bd9875dcbc27b5fd
```

Keep manual update instructions in the release: download the new app, quit ProfileDock, replace the app, and open the new copy once. Opening it once is also required after moving it. The app does not download future versions automatically.

Run the filesystem compatibility checks on macOS with Command Line Tools:

```sh
python3 scripts/test-launcher-compatibility.py
```

That harness uses temporary fixtures. It does not replace live Dock, Chrome, permission, or downloaded-package checks. Version 0.1.3 remains an ad-hoc-signed, unnotarized beta unless it separately completes the Developer ID process below.

## Prepare a public release

Complete the [integration checks](ARCHITECTURE.md#integration-checks-before-release), including a clean Mac with fresh Automation permissions. Verify both supported CPU architectures if distributing a universal app. Confirm the README's supported/untested environments match the evidence.

Apple requires a Developer ID Application identity, valid executable signatures, Hardened Runtime, secure timestamps, and notarization for the normal Developer ID distribution path. Ad-hoc signing is not a substitute for that identity. [Apple notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution?changes=_1_8_5).

Install the appropriate signing identity using your own Apple developer account. Never commit it or its password. This project does not provision certificates or automatically upload builds.

```sh
python3 scripts/build.py --universal --version 0.1.3 --build-number 1 \
  --identity 'Developer ID Application: Your Name (TEAMID)'
```

With `--identity`, the script signs the helper, enables Hardened Runtime, adds the controller's Apple events entitlement, includes timestamps, and verifies the resulting signatures. It still does **not** notarize. The initial ZIP ends in `-signed.zip`.

## Notarize explicitly

Set up a `notarytool` keychain profile following Apple's documentation, using your own credentials. The example below assumes you named it `ProfileDock-notary`. Review the submission result and its log; continue only if Apple reports acceptance.

```sh
xcrun notarytool submit dist/ProfileDock-0.1.3-macos-universal-signed.zip \
  --keychain-profile ProfileDock-notary --wait
xcrun stapler staple dist/ProfileDock.app
xcrun stapler validate dist/ProfileDock.app
codesign --verify --deep --strict --verbose=2 dist/ProfileDock.app
spctl --assess --type execute --verbose=2 dist/ProfileDock.app
```

Repackage the app after stapling, so the download includes the ticket. Use a fresh final archive name and compute its checksum:

```sh
ditto -c -k --keepParent --sequesterRsrc \
  dist/ProfileDock.app dist/ProfileDock-0.1.3-macos-universal.zip
cd dist
shasum -a 256 ProfileDock-0.1.3-macos-universal.zip > SHA256SUMS
```

Test the actual final ZIP downloaded through a browser on a clean Mac, including first launch, Automation consent, shortcut creation, and switching. Locally copying an app does not exercise the same Gatekeeper path as an internet download. Do not instruct users to disable Gatekeeper or remove quarantine as the normal installation procedure.

## Publish and maintain

When validation is complete, publish the final ZIP and `SHA256SUMS` with a versioned GitHub Release. Describe the exact tested versions and known limits. A simple website can link to that release, the source, setup instructions, and issue tracker. Hosting has no bearing on whether macOS trusts the downloaded binary.

Keep the controller bundle identifier and Developer ID consistent across releases. Never customize a user's icon or configuration inside the signed controller bundle. Test upgrades with existing shortcuts and Automation settings. Begin with manual release downloads; automatic updates require a separately validated signing and delivery mechanism.

GitHub workflow artifacts remain clearly named **development-unnotarized**. They are useful for review, not a replacement for the public-release process above.
