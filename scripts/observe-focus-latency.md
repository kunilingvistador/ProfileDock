# Passive observation of Chrome window focus

This diagnostic watches process and Window Server metadata while a person or a
separate UI tool opens an existing shortcut through Finder or Dock. It **never**
launches or activates an app, sends Apple events, calls an Accessibility action,
generates keyboard/mouse input, or changes Chrome. It does not enable tracing in
ProfileDock, read its trace files, or modify the controller registry.

## Build with Command Line Tools

From the repository root, with macOS 13+ and a logged-in desktop:

```sh
mkdir -p /tmp/profiledock-latency-build
xcrun swiftc -O -parse-as-library -swift-version 5 \
  -module-cache-path /tmp/profiledock-latency-build/modules \
  scripts/observe-focus-latency.swift \
  -o /tmp/profiledock-latency-build/observe-focus-latency
```

Full Xcode and XCTest are not required. `--help` reads no process/window metadata.
CI typechecks the observer; it does not perform a live desktop benchmark.

## Select a window and record transitions

First use the ordinary UI to bring the intended Chrome window forward. Then:

```sh
/tmp/profiledock-latency-build/observe-focus-latency --inventory
```

Inventory prints only `cgWindowID` and `ownerBundleID` for normal on-screen windows,
in front-to-back order. It has no titles, tab URLs, names, coordinates or PIDs.
After selecting the intended window in the UI, the first normal Chrome window
identifies the candidate; verify that selection before starting. A CoreGraphics ID
is not an AppleScript window ID. IDs can change when windows are recreated.

Use the ordinary UI to make a different app/window frontmost. Start observation,
wait for the `{"status":"observing"}` line, then click the already configured
shortcut through Finder/Dock. Replace the ID and choose a new output filename:

```sh
/tmp/profiledock-latency-build/observe-focus-latency \
  --target-window 12345 --seconds 15 \
  --output /tmp/profiledock-observation-01.json
```

The duration must be between 0.005 and 60 seconds. The parent output directory must
already exist and be writable. The output file must not exist: exclusive creation
prevents overwriting a prior report or following a replaced symlink. The report is
created with mode `0600`. The program samples approximately every 5 ms and records
the first observation plus subsequent true/false changes, rather than retaining
every poll. Unavailable Window Server data stops the run with an explicit failure;
it is never converted into a false transition. A delayed main run loop can make
the observed run slightly longer than the requested duration.

## What the timestamps mean

The observed condition requires both:

1. The original Chrome application is frontmost before and after the metadata read.
2. The target CGWindowID is the first normal on-screen window: layer 0, alpha > 0,
   width and height > 1 pixel, and the same owning process as the original target.

CoreGraphics documents [front-to-back ordering](https://developer.apple.com/documentation/coregraphics/cgwindowlistoption/optiononscreenonly).
This is a window-order proxy. It does not establish that an animation has finished,
the page has painted, input is accepted, or pixels reached the physical display.
The two process checks reduce inconsistent readings, but the API calls are not one
atomic snapshot. Record `maximumPollGapMs` and `maximumSnapshotDurationMs`; a 5 ms
requested interval is not a real-time guarantee or a claim of 5 ms accuracy.

The JSON schema contains `startedUptimeNs`, `finishedUptimeNs`, `initialObservation`
(`uptimeNs`, `targetIsFront`), `transitions` with the same fields, counters, status,
and observed scheduling gaps. Timestamps use `DispatchTime.uptimeNanoseconds`, the
same monotonic clock as the opt-in ProfileDock traces. Preserve these as integers
when parsing; do not round-trip nanosecond timestamps through a floating-point
spreadsheet or JavaScript Number on long-uptime systems.

For an isolated sample, a separate analysis can join a trace event
`phase == "helper.start"` to the next `targetIsFront == true` transition:

```text
latency_ms = (first_target_true_uptime_ns - helper_start_uptime_ns) / 1_000_000
```

Only count this when observation began before the helper event, the last observed
state before the event was false, there was no failed observation, and no other
request/user activation competed between the two timestamps. An initially true
target is not a zero-millisecond success. Without request correlation, concurrent
helper traces cannot be paired unambiguously; mark these samples ambiguous.

Name this result **first helper instruction → front-window proxy**. It excludes
the physical click, Finder/Dock dispatch, Launch Services scheduling and process
startup before `helper.start`. Never label it click-to-window or first-paint latency.
Keep it separate from the older active harness's **launch request → front-window
proxy**, which includes more startup work. They have different starting points.

`helper.request`, `controller.received`, `focus.requested`, `focus.accepted`, and
Apple-event durations can explain where time went, but cannot replace the observed
transition. An [NSWorkspace completion](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:))
reports app launch status. A successful activation request does not measure painted
pixels. Overlapping internal work can be correlated with distinct interval IDs in
[OSSignposter](https://developer.apple.com/documentation/os/ossignposter), when available.

## Bounded comparison protocol

Use the same release configuration, controller install path, helper, Chrome version,
target and desktop arrangement for baseline and candidate. Record app/archive hash,
OS, architecture, power state and whether tracing was enabled outside the shared
timing report. Do not compare historical active-harness numbers directly to this
passive observer. Start with a short baseline/candidate/baseline order to reveal drift.

| Scenario | Small initial sample | What to check |
| --- | --- | --- |
| Warm controller, ordinary open target | 10 per build | Same final window, no new windows/tabs, every latency plus median/range; manager stays out of the way. |
| Cold controller, Chrome remains running | 3 per build | Quit only the controller through its normal UI before each sample; report individual values, not a meaningful p95. |
| Minimized target | 3 per build | Minimize only the disposable target through UI before each sample; report restore latency separately. |
| Chrome unavailable | One deliberate check outside a working session | Report time to explicit failure/recovery, not a window latency; the observer cannot preflight an absent target. A fake executor can cover the no-launch rule in CI. |
| Rapid clicks | Three short A→B→C bursts, then repeated C | Last requested target wins, no late return to A/B, no error stealing focus. Needs per-request correlation; aggregate unmatched trace events are not latency samples. |

Keep each recording at 15–30 seconds, below the 60-second ceiling. Stop at the first
wrong target, unexpected window/tab change, or permission dialog; preserve the
failed sample and classify the cause. Do not keep relaunching into an uncertain state.
Only expand a repeatable improvement to 30–40 warm samples across several shortcuts.
With 10 samples nearest-rank p95 is simply the maximum; show count/failures/raw values
and avoid overinterpreting it. Changes comparable to observed polling gaps are inconclusive.

## Privacy and limits

The main report contains no window IDs, PIDs, app paths, profile/window names, page
titles, URLs, screenshots or keystrokes. IDs/PIDs are held transiently in memory to
match the selected window and are not serialized. Error output uses fixed codes,
not localized messages that could contain paths. The explicit inventory mode is
the only output that includes CGWindowIDs and app bundle identifiers; do not publish
that inventory or the raw per-process trace files with a public benchmark.

The observer extracts only numeric window identity, layer/alpha and dimensions from
the API response, plus process identity for the selected Chrome app. Apple describes
which [window metadata is filtered by screen-recording permissions](https://developer.apple.com/videos/play/wwdc2019/701/).
The observer does not request, grant or revoke any permission. It writes only its
requested report and does not upload anything. It does not alter quarantine,
provenance, signing attributes, Dock configuration or browser profile files.

Fullscreen, Spaces, Stage Manager, multiple displays, app-wide Hide and layer-0
overlays require separate interpretation. Frontmost metadata is not a substitute
for inspecting the actual UI. Measurements on one Mac are observations on that
configuration, not a speed guarantee for Intel/other OS versions or cold login.
