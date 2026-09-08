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

Compatibility validation is still in progress. Do not carry forward the results recorded for older versions as proof for this candidate. Before publication, record the tested source revision, package, environments, and results in the [validation record](VALIDATION.md), including:

- Existing shortcut UUIDs, bindings, names, images, and version-1 settings survive an app replacement.
- Helper updates preserve the original app path, root filesystem identity and existing bookmarks; an already pinned Dock icon is checked separately on a live desktop.
- Explicit legacy conversion preserves the original bundle ID and creates a complete `Legacy Backups/<random>/Contents` backup plus `original-path.txt`. Repeated import or conversion does not duplicate the shortcut.
- Opening a moved/replaced controller updates its recorded location and existing helpers; subsequent warm and cold Dock requests reach that controller.
- Maintenance failures stay separate from Chrome focus errors, and ordinary background focus requests do not perform helper maintenance.
- Name and image edits continue to update migrated helpers at their existing locations.

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
