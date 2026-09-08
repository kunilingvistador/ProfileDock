# Updating ProfileDock and keeping your shortcuts

The 0.1.3 compatibility candidate lets existing shortcuts use the current ProfileDock controller without being recreated. Validation of this candidate is still in progress; earlier results in [VALIDATION.md](VALIDATION.md) apply only to their recorded versions and source revisions.

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
```

Each conversion gets a separate backup directory. Open **Open data folder** from the ProfileDock menu to find it. These backups contain the original applet files; they are separate from `shortcuts.json` and the custom images stored in `Icons`.

Maintenance errors appear in a separate nonblocking message with details and an **Update shortcuts** retry action. They do not become a Chrome switching error. The release remains an ad-hoc-signed, unnotarized beta, so macOS approval and Automation permission may still be needed after replacing the app.
