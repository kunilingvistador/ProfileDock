# Keyboard shortcuts

Available in **0.1.6 beta**. Each saved window can have one optional global hotkey. Clicking a Dock helper and pressing the hotkey use the same existing-window connection.

## Assign, change or remove

1. Click **Set hotkey** on a shortcut card (Russian: **Назначить сочетание**).
2. Click the recording field and press a supported key with at least two modifiers, including Command or Control. Example: Option–Command–1. No combinations are assigned automatically.
3. Save. To remove a combination, choose **Remove hotkey**, then save. Cancel or Escape during recording leaves the previous saved assignment intact.

The physical key remains fixed across keyboard layouts; the displayed character follows the current layout. Supported keys include letters, digits, ordinary punctuation, Space and arrows. Media keys, modifier-only combinations, Fn, Escape and Tab are not assignable. Tab navigates the editor, and Escape exits recording.

Closing the manager window keeps hotkeys active. **Quit ProfileDock** stops them until the app is launched again. This version does not automatically start at login. **More options → Keyboard shortcuts enabled** pauses all saved assignments; **Retry hotkey registration** retries unavailable combinations. The app releases its registrations while the hotkey editor is open, including when the Mac wakes with that editor still open.

## Conflicts and recovery

Duplicate assignments within ProfileDock are rejected. The app checks exposed macOS symbolic shortcuts, its own main-menu commands, and failures of exclusive OS registration. It cannot discover every command or interception mechanism of every other app. A failed registration is shown beside that shortcut; it does not silently take another ProfileDock shortcut's assignment. Try a different combination and test from your usual apps.

If the target Chrome window is closed or ambiguous, the existing window-reconnection workflow applies. A missing target does not create a blank browser window. A held key triggers once per press; rapid requests share the existing focus queue.

## Persistence and privacy

Assignments are keyed by the saved shortcut's UUID, not its display name, icon, Dock filename or transient Chrome window ID. Rename and reconnect therefore preserve them. Existing Dock helpers do not need to be recreated to use hotkeys.

`hotkeys.json` is stored separately under ProfileDock's private local data folder. Older releases ignore this file, preserving it when saving their original shortcut settings. An unreadable or unsupported hotkey file disables hotkey editing without replacing the original file or preventing ordinary Dock shortcuts from loading.

The implementation registers selected combinations through RegisterEventHotKey. It does not read a global stream of typed text, install a CGEvent tap, or send hotkey assignments to a server. Chrome switching continues to require the existing Automation permission. The recording field handles input only inside the focused editor.

## Validation scope

Core tests exercise storage compatibility, unsafe input, duplicates, failed registration and failed saves, suspension, disabled assignments, partial startup conflicts, repeat suppression, stale events and removed UUIDs. Live desktop and package results for the release are recorded in [VALIDATION.md](VALIDATION.md). Hosted builds cannot establish behavior on every keyboard, Spaces/fullscreen setup, Secure Input session or physical Mac. No specific click-to-visible latency improvement is claimed without measurement.
