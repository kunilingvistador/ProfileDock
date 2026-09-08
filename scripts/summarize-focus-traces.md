# Reproduce internal focus timings

```sh
python3 scripts/test-summarize-focus-traces.py
python3 scripts/summarize-focus-traces.py /absolute/saved-traces \
  --label baseline-0.1.3-build7 --output /absolute/new-summary.json
```

Python 3.9+ and its standard library are sufficient. No application launches,
Apple events, UI access or network access occur. Input is a non-recursive
directory of `events*.jsonl` files saved from the opt-in performance trace.
Use a completed, immutable trace snapshot from one boot and one build. Do not
mix machines, reboots or builds: their monotonic clocks are not comparable.
The optional label must be a public build label, never a profile or user name.
The script never overwrites an output; new files have mode `0600`.

## What the number measures

`helperToAccepted` starts at the helper's first instrumented instruction and
ends at `focus.accepted`. This is an internal response measurement. It excludes
the physical click, Finder/Dock dispatch and loading before the first helper
instruction; acceptance does not demonstrate window visibility or first paint.
Invalid passive Window Server reports are not inputs to this analysis.

Warm and cold samples are separate. A cold sample contains `controller.start`
between its helper request and first controller receipt. Two controller receipts
are allowed for a cold start, because delivery before model initialization is
queued and then replayed. This is cold controller startup, not cold Chrome,
disk cache, login, or macOS startup. Warm classification requires no controller
start in the sample; verify the initial controller state in the test protocol.

Every metric reports its own `n`, minimum, median, nearest-rank p95 and maximum.
With ten samples, nearest-rank p95 equals the maximum; it is not a reliable
population tail estimate. Components are measured on the same chain but their
separate medians do not necessarily add to the total median.

| Output component | Boundary |
| --- | --- |
| `helperResolver` | First helper instruction → helper request. Includes helper setup and resolving the controller; not an isolated resolver benchmark. |
| `handoffToFirstControllerReceipt` | Helper request → first controller receipt. Includes startup before receipt for cold starts. |
| `firstReceiptToFocusRequested` | First controller receipt → focus request; includes queued cold delivery. |
| `focusToAccepted` | Focus request → activation accepted. |
| `controllerStartToFocusRequested` | First controller instruction → focus request, cold samples only. |
| `appleEventQueue`, `appleEventCompile`, `appleEventExecution`, `appleEventTotal` | Numeric values recorded by the controller's focus Apple event. These overlap `focusToAccepted`; do not add them again to the end-to-end total. |

`postAcceptanceListWindowsObserved` counts list operations completed after
acceptance and before the next helper starts (or the end of the saved trace).
Their durations are observed background work, not part of `helperToAccepted`.
The trace has no correlation IDs, so these operations cannot be causally
attributed to a particular click. A long idle gap can contain unrelated refreshes.
Missing component instrumentation is counted and omitted from that component's
distribution, rather than fabricated as a zero-duration measurement.

## Conservative pairing and exclusions

A sample must contain exactly one helper request, focus request and acceptance
before the next helper starts. Event order must be strict, helper identities
must match, and controller events must originate from one controller process.
Failed or superseded requests, multiple controller starts, warm duplicate
deliveries, ambiguous Apple events and overlapping helper requests are excluded.
No late acceptance can rescue the preceding interval. An unresolved helper
also makes a later overlapping launch unsafe to attribute; use separate trace
snapshots for failure/recovery protocols. Excluded counts and reasons are part
of the output and must accompany any comparison.

Malformed JSON, invalid numeric records, unreadable files or symlink inputs
invalidate the entire input (exit code 1). A missing record could conceal a
failure, duplicate or overlap, so partial recovery would risk a false result.
File/argument/output failures return exit code 2 without printing private paths.
An empty input is invalid. Recognized events are sorted by monotonic timestamp;
unknown phases are counted without reproducing their strings.

Only fixed metadata, an optional caller-supplied public build label, numeric
durations, counts, warm/cold categories and exclusion categories reach JSON.
Raw PIDs, window IDs, absolute timestamps, names, paths, titles, URLs and unknown
event fields are never copied. Raw tracing files remain local and should not
be committed or published. Aggregated observations still apply only to the
tested Mac and workload; they do not establish performance on every Mac.
