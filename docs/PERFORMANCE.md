# Focus performance: 0.1.4 candidate

Measured on **8 September 2026**. On one Apple Silicon Mac, the median time from the **helper's first instrumented instruction to acceptance of the activation request** fell from **206 to 141 ms** with the controller running, and from **987 to 399 ms** with the controller stopped. These are internal response timings, not physical Dock click-to-visible, painted-frame, or keyboard-readiness measurements.

The candidate is **0.1.4 (9)**, source [`639fb3d`](https://github.com/kunilingvistador/ProfileDock/commit/639fb3d166180139cc2adeeddada1a6b5f5d9a42). Validation is complete for the scope below; release publication is pending. The local universal ZIP SHA-256 is `402bc9ecc635218044cf62638b99ec33cd01093488b97bb49586de5e7f83c9b1`. The build remains ad-hoc signed and unnotarized.

## Results and evidence

The baseline is instrumented **0.1.3 (7)**. Both builds were measured sequentially on the same Mac, at the same installation path, with tracing enabled: **macOS 26.5.2, arm64, Chrome 152.0.7977.76**. Each has **21 warm and 3 cold-controller samples, with zero excluded chains**. Chrome remained running throughout cold-controller samples; this does not measure a cold browser, fresh login, reboot, or empty disk cache.

| Internal helper → activation accepted | Baseline | Candidate | Observed change |
| --- | ---: | ---: | ---: |
| Warm median, 21 samples/build | 206 ms | 141 ms | −31.7% |
| Warm nearest-rank p95 | 241 ms | 177 ms | −64 ms |
| Warm range | 173–324 ms | 114–184 ms | |
| Cold median, 3 samples/build | 987 ms | 399 ms | −59.5% |
| Cold range | 962–1003 ms | 378–415 ms | |

Cold observations in acquisition order were **987, 962, 1003 ms** and **378, 399, 415 ms**. With only three samples, these are descriptive observations, not a reliable estimate of a population tail. Percent changes use unrounded medians. The experiment was not randomized or counterbalanced; caches, load, and run order may contribute. It establishes neither an isolated effect for each code change nor performance on other Macs.

The public [baseline JSON](performance/baseline-0.1.3-build7.json) and [candidate JSON](performance/candidate-0.1.4-build9.json) contain the sample durations and aggregates. Both summaries were independently regenerated from completed local trace snapshots and matched exactly. The [reproduction instructions](performance/README.md) and [analyzer methodology](../scripts/summarize-focus-traces.md) specify pairing, exclusions, component boundaries, and arithmetic. Raw traces remain private.

## What the endpoint means

`helper.start` records a monotonic timestamp at the helper's first instrumented instruction. `focus.accepted` follows successful completion of the focus AppleScript and a successful return from `NSRunningApplication.activate(options: [])`. Loading before the first helper instruction, Finder/Dock dispatch, and the physical click are outside this interval. No observation of pixels or keyboard input is required for that event.

App activation and selecting a browser window are separate operations. Chromium's [window AppleScript implementation](https://raw.githubusercontent.com/chromium/chromium/main/chrome/browser/ui/cocoa/applescript/window_applescript.mm) implements the window index through the native window's ordered index. Apple documents context-dependent activation requests in the [AppKit release notes](https://developer.apple.com/documentation/macos-release-notes/appkit-release-notes-for-macos-14). Our acceptance event therefore does not establish which window receives the next keystroke, completion of a Space transition, or when a frame becomes visible.

Three attempted external passive Window Server observations were **invalid** and contribute no latency numbers or visible-focus success claims. The cause was not established; an observer/target mismatch or computer-use interaction must not be presented as a confirmed explanation. The older window-order timings in [VALIDATION.md](VALIDATION.md) have different start and end boundaries and cannot be combined with this comparison.

## Work removed from the switching path

- **Cold startup:** the manager window and SwiftUI hierarchy are created when the manager is shown or recovery requires it. Startup no longer queues a full Chrome window refresh ahead of focus. In all three candidate cold chains, no `controller.uiReady` event occurred before or at acceptance. Two manager windows were created much later, about 48 and 36 seconds afterwards; their subsequent refreshes are outside the measured interval.
- **Warm focus:** a combined read selects normal windows by exact given name, then the script checks the match count and operates on the stable window ID. Missing and duplicate matches still fail. Median focus Apple-event execution fell from **107 to 47 ms**. Chromium's [mode implementation](https://raw.githubusercontent.com/chromium/chromium/main/chrome/browser/ui/cocoa/applescript/window_applescript.mm) rejects changing a window's mode after creation, allowing the redundant later mode read to be removed.
- **After acceptance:** baseline traces observed a window-list operation after **21/21** warm requests, with median duration **384 ms**; candidate traces observed **0/21**. This removes background work, but those durations are **not included in**, and must not be added to, the first-response improvement. The manager still refreshes when shown.
- **Other deferred work:** menu contents and cached icons are prepared when needed; profile metadata is loaded for the manager; controller discovery stops after a valid preferred candidate. Structural controller checks remain. No continuous polling service was added.

These changes were measured together. Component medians overlap or describe different intervals; they are not additive. Tracing also performs local file I/O in both builds, so these are instrumented results.

## Functional coverage and remaining live checks

The [exact-source CI run](https://github.com/kunilingvistador/ProfileDock/actions/runs/34228216382) passed all **5 jobs**. Each of four native configurations—macOS 15 and 26 on arm64 and x86_64—passed **55 XCTest tests**, **13 Python analyzer tests**, and **8 compatibility cases / 134 assertions**, plus package checks. The fifth job built the website. Hosted tests do not exercise a user's live Chrome/Dock desktop.

The final local **0.1.4 (9)** ZIP was extracted into a fresh temporary directory and passed **deep strict code-signature verification**. Both controller and helper contained **arm64 and x86_64** binaries. The archive contained no private icons or user settings. These archive checks are separate from the [FinderInfo limitation of live migrated applets](SHORTCUT-COMPATIBILITY.md#checked-for-013-build-6).

After the candidate checks, all four existing shortcut app paths, root inodes, bundle IDs, and icon bytes matched their baseline. The original `shortcuts.json` hash and Dock GUID order were unchanged. The manager displayed four ready shortcuts; opening an existing shortcut's settings and cancelling also succeeded. No personal shortcut names or paths are included in this record.

One later visual spot-check of the manager's switch button showed the expected existing Chrome window in the screenshot. The accessibility snapshot from that same computer-use call identified a different window; the reason for this mismatch was not established. This single screenshot supports only that visual observation. It does not validate the external observer, supply a latency, or establish keyboard focus. Personal window names, page contents, and screenshots are not published.

| Scenario | Evidence for this candidate |
| --- | --- |
| Existing bound window, warm controller; Chrome already running | 21 accepted timed requests and local launcher checks. No validated external visible-window latency. |
| Cold controller; Chrome still running | 3 accepted timed requests; no manager construction before acceptance. This is not cold-login or first-permission testing. |
| Manager opened after a background cold launch | Live check succeeded; manager displayed four ready shortcuts. |
| Existing shortcut settings | Live open-and-cancel check succeeded; final settings-file hash remained unchanged. |
| Manager switch button, one visual spot-check | Screenshot showed the expected existing window; same-call accessibility data disagreed. No timing or keyboard-focus conclusion. |
| Chrome inactive versus already active | Code handles both through the same target selection and activation path; the timing corpus is not stratified by Chrome foreground state. Separate visible/keyboard checks remain. |
| Minimized target | Restore command retained and statically reviewed; earlier live evidence is in the historical validation record. No new candidate minimized latency claim. |
| Chrome closed; missing or closed target | Error and manager-recovery paths retained and statically reviewed; missing-binding model tests pass. Candidate live failure/relink regression remains to be repeated. |
| Duplicate names; private windows | Model tests and script review retain ambiguous-match rejection and private-window exclusion. Candidate live browser edge-case checks remain. |
| Repeated/competing requests | Generation-gate unit tests pass. A live three-request sequence was accepted without errors, but did not saturate the queue or exercise supersession. An already executing Apple event cannot be cancelled; stale native activation is gated. |
| Spaces, fullscreen, Stage Manager, multiple displays, app-wide Hide | Additional live tests remain; no support or speed claim follows from these timings. |
| Fresh login, revoked/new Automation permission, clean-machine Gatekeeper | Not exercised by the cold-controller series. Separate onboarding/recovery checks remain. |

## Opt-in local diagnostics

Performance tracing is **disabled by default**. A developer enables it before starting the processes by creating `/private/tmp/ProfileDock-Performance-<uid>/enabled` inside a directory owned by that user with permissions **0700**. New per-process trace files use **0600**. Records contain fixed phase labels, numeric timings, monotonic timestamps, and process IDs; no shortcut names, window titles, page URLs, or browser contents are logged.

Enablement is cached on the first trace call in each process. To turn it off, remove the `enabled` flag **and restart ProfileDock**; allow any already running short-lived helpers to exit before measuring again. Removing the flag alone does not stop a process that already opened its trace. Public summaries omit process IDs and absolute timestamps as well. See the [analyzer instructions](../scripts/summarize-focus-traces.md) before collecting or sharing diagnostics.

After this measurement session, the `enabled` flag was removed and ProfileDock restarted. A read-only process check confirmed one controller running from the new build, no enablement flag, and no trace event file for the new process. This confirms tracing was inactive in that restarted controller.
