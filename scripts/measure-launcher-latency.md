# Exported launcher → selected window latency

For new Finder/Dock-driven measurements, prefer the [passive observer](observe-focus-latency.md),
which never opens or activates an app. This older active diagnostic still opens
the helper itself and reopens the manager before every warm sample. Opening the
manager can schedule launcher maintenance, so its baseline is not an idle signal.

This standalone diagnostic requires macOS 13+, an interactive logged-in desktop,
and the Xcode Command Line Tools. It uses AppKit/CoreGraphics and the production
controller resolver; XCTest and full Xcode are unnecessary. It neither reads browser tabs nor sends Chrome AppleEvents.
Do not run it while another person or automation is operating the desktop.

Compile from the repository root, using a scratch directory outside the source:

```sh
mkdir -p /tmp/profiledock-latency-build
xcrun swiftc -O -parse-as-library -swift-version 5 \
  -module-cache-path /tmp/profiledock-latency-build/modules \
  Sources/ProfileDockCore/ControllerLocation.swift \
  scripts/measure-launcher-latency.swift \
  -o /tmp/profiledock-latency-build/measure-launcher-latency
```

Choose an existing working exported ProfileDock `.app` helper and its bound Chrome
window's current **CoreGraphics window ID**. A CoreGraphics ID is not the AppleScript
window ID. Supply the controller build the helper actually opens. No real paths or
IDs are included here or saved by the diagnostic.

```sh
/tmp/profiledock-latency-build/measure-launcher-latency \
  --controller '/absolute/path/ProfileDock.app' \
  --launcher '/absolute/path/exported-shortcut.app' \
  --target-window 12345 \
  --iterations 10 \
  --poll-ms 10 \
  --timeout-ms 5000 \
  --ready-ms 150 > /tmp/profiledock-latency.json
```

Replace all three example values. The executable accepts modern helpers and
migrated legacy helpers that retain their original bundle identifier and matching
`ProfileDockLegacyBundleIdentifier` marker. Unconverted AppleScript applets are rejected.
It validates the controller selected by the same registry/running/Launch Services/
standard-location/fallback resolver as the production helper, and that the target
ID belongs to a normal Google Chrome window. A stale Launch Services record alone
does not override a valid user-selected registry location. The target ID may change
when a window is recreated. The preflight only reads the registry; it never updates it.

## What is measured

In the default warm mode, before **every** sample the tool opens/reopens the supplied ProfileDock controller
through `NSWorkspace.openApplication`. Its manager must be the frontmost application
and own the first visible normal window for at least `--ready-ms`. It also waits for
the previous helper to exit. This preparation is reported as `baselineReadyMs` and
is excluded from `latencyMs`.

The monotonic clock starts immediately before
`NSWorkspace.openApplication(at: launcherURL, configuration: ...)` requests the real
exported helper application, using the same Launch Services application-opening
mechanism as opening an app from Finder/Dock. It does **not** send the controller's
focus URL directly, invoke its executable directly, or substitute an AppleScript.
It includes Launch Services dispatch, helper startup, controller handoff, and the
application's existing focus implementation. It excludes physical mouse movement,
input-device latency, and Finder/Dock processing before the launch request.

Every approximately 10 ms the tool checks both conditions:

1. Chrome is the frontmost application, with the original target window's owner PID.
2. The selected CGWindowID is first in the Window Server's front-to-back list of
   on-screen windows whose layer is 0, alpha is positive, and dimensions exceed 1 px.

`latencyMs` ends at the first observed match. The launcher completion callback is
also required for a successful sample, but is reported separately as
`launchCallbackMs`: the callback alone does not prove that Chrome focused a window.
`elapsedMs` includes any wait for that callback. `maximumPollGapMs` exposes scheduling
stalls; a nominal 10 ms timer is not a real-time guarantee. Polling and API calls add
measurement overhead, so tiny differences within a poll interval are not meaningful.

The JSON contains statuses, counts and timings only. It excludes profile/window
names, URLs, window IDs, PIDs, app paths and error descriptions. Exit status is 0
for a completed successful series, 1 for a runtime/baseline failure, and 2 for invalid
arguments or a failed preflight. Runtime failures stop the series after the first
failure; already collected samples remain in the JSON. No apps are killed.

## Scope and limitations

- **Two explicit modes.** Default preparation starts ProfileDock if necessary before
  the clock and reports `mode: warm_controller`. `--cold-controller` measures one
  request with the controller initially stopped and reports `mode: cold_controller`.
  Neither mode implies a clean login, first-run permissions, Gatekeeper, an uncached
  disk, or a cold Chrome process. Executable/disk caches may stay warm.
- **Window ordering, not pixels.** Window Server ordering plus frontmost-app state is
  an observable focus proxy. It does not measure compositing, display scanout,
  animation completion, page paint, input acceptance, or perceived visual latency.
  Use a screen recording/high-speed camera or a dedicated render/instrumentation
  method for those questions; do not describe this result as click-to-photon latency.
- In warm mode, ProfileDock's manager must be visible in the current workspace. A hidden/closed
  manager that does not respond to reopen fails the baseline instead of warming up
  by activating Chrome. Preparation changes the foreground window but does not
  minimize, move, resize, rename, create, or close Chrome windows.
- The tool does not grant, revoke or test Automation/Accessibility/Screen Recording
  permissions. Have the helper and controller working before a measurement series.
  It reads numerical CoreGraphics metadata and never uses window names. Permission
  dialogs or unrelated foreground activity can cause a failure.
- Fullscreen, Spaces, Stage Manager and multi-monitor behavior affect which windows
  are on-screen and their ordering. They are distinct test configurations; a timeout
  there is not by itself a latency regression. Record the configuration separately.
- macOS can show non-document surfaces at layer 0. The filter is deliberately simple
  and conservative; a competing layer-0 window prevents a match. This is preferable
  to reporting success merely because some Chrome window became frontmost.
- No warmup samples are discarded automatically. Compare the same controller build,
  helper, Chrome window and desktop state; inspect individual samples as well as
  median/p95. With 10 samples, nearest-rank p95 equals the maximum and is exploratory.
- The tool cannot prove that internal asynchronous controller work has drained.
  Baseline readiness means a finished application launch plus a stable frontmost
  manager window; it is not an internal application-idle signal.

## One cold-controller sample

The caller must first quit **only ProfileDock** through its ordinary interface. Keep
Chrome and the target window open. Add `--cold-controller` to the command above
and omit `--iterations` (its cold default is 1) or set it to 1 explicitly. Other
iteration counts are rejected. Repeat the manual preparation for another cold run.

The harness verifies that the controller and selected helper are not running. If
Chrome is frontmost, it activates an **already-running Finder** using
`NSRunningApplication.activate(options: [])`. It does not launch Finder, open a
Finder window, or activate Chrome. If Finder is not running or activation fails,
the run stops with a status code. If another application is already frontmost, it
keeps that application as the baseline.

The same non-Chrome application must remain frontmost for `--ready-ms` (150 ms by
default). Throughout preparation, and again immediately before requesting the
helper, the harness checks that the controller is still absent. If the controller
starts independently, the run is refused rather than counted as cold. It **skips
controller baseline activation entirely**; only the helper request starts the
controller. JSON `baselineReadyMs` reports the preparation duration, separately
from and excluded from `latencyMs`. The tool never quits, kills, or directly starts
the controller in this mode. Timing starts at the helper's Launch Services request.
