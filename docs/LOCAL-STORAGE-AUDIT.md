# Local storage and launcher chain review

Reviewed 2026-09-08 for **release candidate 0.1.5, build 11**, exact source
[`addbc13`](https://github.com/kunilingvistador/ProfileDock/commit/addbc132f018310a713642cac32c3e58e08e9c9b),
**not yet published**. This review covers profile discovery, shortcut storage, controller selection,
legacy import and maintenance, generated launchers, local diagnostics and the
native build/signing path. This is a source review with isolated filesystem
fixtures, not a penetration test or a guarantee against another malicious
process already running as the same macOS user. No real profile contents were
used as test inputs.

## Data used by the native app

| Source or destination | Data |
| --- | --- |
| Chrome `Local State` | The file is loaded into memory; discovery uses profile directory names, display names and optional account labels from `profile.info_cache`. Only `Default` and `Profile <digits>` directories are accepted. |
| Chrome profile avatar | An optional local profile image can be copied into the selected shortcut's image. |
| Chrome window automation | Existing regular-window IDs, user-assigned names, displayed titles and minimized state for selection; current code checks incognito mode before collecting identifying window metadata. |
| `shortcuts.json` | Shortcut UUID, display name, persistent window name, optional profile directory/image filename and creation date. Account labels are not a separate persisted shortcut field. |
| `Icons` and exported apps | A custom image and its derived Dock icon; exported bundle labels contain the chosen display name. |
| `controller-location.json` and `launcher-locations.json` | Local installation/launcher paths; these can contain the macOS account's directory name. |
| `Legacy Backups` | Complete original applet `Contents`, original root signing attributes and original app path. Scripts and images can contain old profile/window names. |
| User defaults | Local preferences, including the cached Chrome Automation-permission state; this does not grant permission itself. |

The reviewed discovery/switching path does not read Chrome's cookies, password
database, browsing-history database or page bodies. It does not upload its local
configuration. Website-icon fetching is a separate, explicit network operation;
this document does not replace that service's privacy review.

Removing an entry from ProfileDock currently removes its configuration entry.
Previously exported apps, image files and migration backups can remain on disk.
Treat this as removal from the manager, not secure deletion of all related data.

## Storage hardening implemented in the release candidate

`PrivateStorage` protects the known app-owned data root and immediate owned
subdirectories with POSIX mode `0700`. JSON/image replacements use mode `0600`,
an exclusive temporary file and an atomic rename within the checked directory.
It rejects a symlink or a non-directory at the data root/subdirectory, and
symlinks/nonregular destinations for read, write and removal. Files/directories
must belong to the current user. File reads have a size bound and use nonblocking
open before checking regular-file type, so a FIFO cannot block the reader.

Leaf operations use directory descriptors and `openat`/`fstatat`/`renameat`.
The helper does not recursively walk or chmod parent user folders. Only outer
backup containers are protected; copied original `Contents` retains its bytes,
modes and extended attributes. Existing app/Contents symlinks remain rejected
by launcher ownership checks.

These are POSIX permission and path protections. They do not encrypt files,
remove user-configured ACLs, or create an isolation boundary from same-user
software. Generated launchers deliberately remain executable, and a user who
copies an app/icon to a shared location controls that new copy's exposure.

Meaningful regression fixtures cover permissive `umask 022`, atomic replacement
while a reader holds the old file, root/Icons/JSON/PNG links, directory/FIFO
leaves, traversal names, read limits, private registry modes, redirected registry
roots, and preservation of the original backup contents. See
`Tests/ProfileDockCoreTests/PrivateStorageTests.swift` and the existing launcher
filesystem harness.

## Candidate validation status

[CI 34235067293](https://github.com/kunilingvistador/ProfileDock/actions/runs/34235067293)
passed all five jobs for the source above. Each native macOS 15/26 × arm64/x86_64
job passed **77 XCTest tests, 13 Python tests, and 8 compatibility cases / 134
assertions**, with zero failures, plus its package checks. A separate fresh
extraction of the final local build-11 ZIP passed
checksum, CRC, both universal-binary architecture checks and deep strict
signature verification. See [VALIDATION.md](VALIDATION.md) for the archive hash
and the complete validation scope. This was not a download of a published 0.1.5
release.

Read-only before/after checks of the existing installation found the four
shortcut paths, root inodes, bundle IDs and ICNS hashes unchanged. The saved
shortcut JSON hash and Dock GUID order also matched. The actual data root and
Icons directory were mode `0700`; the controller-location file was mode `0600`.
These checks do not imply recursively changing existing files, eliminating
FinderInfo behavior in synced folders, or protection against another process
running as the same user. The local privacy sheet was exercised; this update
does not introduce a new focus-performance measurement.

## Remaining boundaries and follow-up tests

### Installed helper integrity during a no-op update

`LauncherExporter.upgrade` currently identifies an unchanged helper from the
source fingerprint saved in bundle metadata, the helper version/controller path
and the installed executable's presence. The fingerprint is an update marker;
it is not a fresh integrity check of the installed executable. Corruption of
that executable with unchanged metadata can therefore remain undetected until
a later real update or macOS launch/signature validation.

Do not replace this with an unconditional whole-bundle strict-signature gate:
the existing migrated-app limitation allows FinderInfo to reappear in synced
folders and trigger false failures. That behavior is recorded in
[the compatibility notes](SHORTCUT-COMPATIBILITY.md). A follow-up should validate
the executable's meaningful signed/code content without treating recurring root
Finder metadata as changed helper code. Add a fixture that damages the installed
helper while retaining metadata, then verifies repair; also retain the unchanged
valid-helper no-op case and a root-FinderInfo case to prevent perpetual rewrites.

### Controller selection is structural compatibility, not publisher identity

The registry and resolver check bundle structure, identifier, executable name,
URL scheme, regular-file type and executable presence. A matching plist is not
proof that the program is from ProfileDock's publisher. Current local/ad-hoc
distribution does not establish a stable Developer ID identity. This is a local
trust limitation, not evidence of remote execution or a TCC bypass.

For a future authenticated distribution policy, validate a suitable signing
requirement and all executable architectures; then test a correctly shaped
bundle from a different signer, a damaged binary, an app move and a legitimate
update. Signature validity and policy trust are separate decisions, and ad-hoc
designated requirements are tied to a specific code version. See Apple's
[code requirement guidance](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
and [static validation API](https://developer.apple.com/documentation/security/secstaticcodecheckvalidity(_:_:_:)).

### Legacy template recognition is deliberately limited

Import reads/decompiles a script and extracts a literal target; it does not call
an imported applet's execution handlers. The conversion recognizer nevertheless
uses required substrings plus a small command denylist, rather than an exact
template grammar. A custom handler or extra notification can pass recognition
and then disappear from the installed forwarding helper after migration. The
complete original applet is backed up first.

A follow-up should reject additional handlers/statements outside the supported
template. Add nonexecuting source fixtures with an extra `on idle` handler and
an extra notification, preserving existing supported variants, quoting and
Unicode tests. This is a compatibility/overbroad-conversion issue; do not describe
the import path as executing arbitrary legacy scripts.

## Commands, diagnostics and build boundary

Names are passed to fixed AppleScript handlers as typed arguments, not spliced
into script source. Focus URLs accept only the expected route and UUID shape.
Generated filenames constrain path separators and length. Runtime signing uses
the absolute `/usr/bin/codesign` executable with an argument array; there is no
shell interpolation in that path. The native Swift package has no third-party
package dependencies. The Python build script also passes command arguments as
arrays, and signing identities/versions are explicit build inputs.

The default build remains ad-hoc signed and unnotarized. Developer ID signing,
Hardened Runtime and notarization are separate distribution work, described in
[RELEASE.md](RELEASE.md). Integrity verification is not publisher authentication.

Performance tracing is opt-in, requires an owned `0700` directory and initially
creates `0600` files exclusively without following a leaf symlink. Current call
sites record fixed phase names and numeric durations/process IDs/monotonic
timestamps. Raw traces remain local; the summary tool removes identities and
absolute timestamps before publication. Trace files are reopened by path for
each append, so they are not protected against another same-user process
actively replacing the file after creation. Holding a validated descriptor for
the tracing lifetime would be a separate low-priority hardening step.
