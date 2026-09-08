# Updating ProfileDock and keeping your shortcuts

The [0.1.3 beta compatibility update](https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.3-beta) lets existing shortcuts use the current ProfileDock controller without being recreated. Local compatibility checks, live migration checks, and the full CI run passed. Results and a known signature-verification limitation are recorded below.

## Replace or move the app

1. Download the desired release and quit ProfileDock.
2. Replace `ProfileDock.app`, preferably in a stable location such as Applications.
3. Open that copy of ProfileDock once.

The manager records its current location and refreshes compatible helpers it owns. If you later move the app, open it once from the new location. The last explicitly opened controller is preferred; the helper does not search the whole disk or select a copy by guessing from its version number.

Updates are manual downloads. This feature updates local shortcut helpers; it does not download or install a new ProfileDock app.

## What stays compatible

| Item | Behavior in 0.1.3 |
| --- | --- |
| Shortcut identity | Existing UUIDs stay the same. The v1 route remains `profiledock://focus/<UUID>`. |
| Saved settings | `shortcuts.json` keeps state format version `1`; existing records do not need a format migration. |
| Window binding | Maintenance does not change the saved binding or send Chrome commands to rename a window. |
| Modern Dock helpers | Continue to send their UUID to the controller, where window-switching fixes are shared. |
| Existing helper files | Updates retain the app's path and root directory filesystem identity, preserving the references used by Dock. |
| Name and image | Maintenance preserves them. Deliberate name or image edits in ProfileDock also update migrated helpers at their original locations. |

Opening or showing the ProfileDock manager triggers maintenance of owned helpers in its managed `Launchers` directory, applications referenced by Dock, and previously recorded helper locations. An ordinary background Dock focus request does not run helper maintenance or rewrite the preferred controller location. Demo mode does neither.

These updates do not recover a Chrome window that has been closed or renamed. Use **Choose another window…** to reconnect such a shortcut; its existing UUID and Dock route remain available.

## Convert older AppleScript shortcuts

Compatible older shortcuts must already correspond to an imported ProfileDock record. ProfileDock offers **Update shortcuts** in the old-shortcut banner and the menu. Conversion runs only when you choose that action or confirm **Import and update** in the folder import dialog.

Import checks the original app files even when their shortcuts are already in ProfileDock. It does not create another record merely to update an already imported shortcut. Only recognized compatible applets with an unambiguous saved window binding can be converted; arbitrary AppleScript apps are not a supported import format.

Conversion replaces the applet's launch behavior with the shared ProfileDock helper while preserving:

- The original app path, root directory identity, and bundle identifier.
- The shortcut's existing UUID and exact saved window binding.
- Its name, images, and position in Dock.

The migration does not change Chrome window names. Subsequent switching and fixes go through the controller instead of the old applet's embedded automation. This is a compatibility change, not a guarantee that every Chrome automation error has been resolved.

## Backups and local files

Settings, custom images, helper locations, and the preferred controller location are kept under:

```text
~/Library/Application Support/ProfileDock/
```

Before converting a legacy applet, ProfileDock saves its original contents and path:

```text
Legacy Backups/<random>/Contents/
Legacy Backups/<random>/original-path.txt
Legacy Backups/<random>/original-root-attributes.plist
```

Each conversion gets a separate backup directory. Open **Open data folder** from the ProfileDock menu to find it. These backups contain the original applet files; they are separate from `shortcuts.json` and the custom images stored in `Icons`.

Maintenance errors appear in a separate nonblocking message with details and an **Update shortcuts** retry action. They do not become a Chrome switching error. The release remains an ad-hoc-signed, unnotarized beta, so macOS approval and Automation permission may still be needed after replacing the app.

## Checked for 0.1.3 (build 6)

On 8 September 2026, four existing applets already pinned in Dock were migrated on a live Mac. The saved configuration remained byte-for-byte identical. Their UUIDs, bundle IDs, app-root inodes, and all icon hashes were preserved; Dock item GUIDs and order were unchanged. Each applet received a complete, byte-matching backup of its original `Contents` directory.

Each of the four original `.app` files was then double-clicked in Finder using UI automation. All four brought the correct existing Chrome window forward. This was a Finder launch check of the original files, not a physical click on each Dock icon.

Repeating **Update shortcuts** through the interface reported **Compatible shortcuts are up to date**. The configuration still contained four records, with no duplicates.

The temporary-filesystem compatibility suite passed **8 cases and 134 assertions**. [CI run 34223725465](https://github.com/kunilingvistador/ProfileDock/actions/runs/34223725465) passed all **five jobs** for source `5b91351`: four native macOS jobs and the website build. Standard XCTest passed **52 tests on each of four runners**: macOS 15 and 26, on arm64 and x86_64. CI package verification and archive checks also passed. These package checks apply to CI-built artifacts, separately from the live migrated applets described below. See [release status and package checksum](RELEASE.md#013-compatibility-candidate).

**Known limitation in iCloud Documents:** after successful installation-time signature verification, the app-root FinderInfo flag `0x2000` reappeared on the migrated applets. Later `codesign --strict` checks failed, although all four apps still launched correctly. The cause remains under investigation. These live results do not establish that the four migrated bundles retain a passing strict signature check indefinitely.
