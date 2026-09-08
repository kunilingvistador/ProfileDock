# Public performance summaries

These JSON files contain sanitized internal timings from one Mac, measured on
2026-09-08. Each build has 21 warm-controller and three cold-controller samples,
with zero excluded chains. Chrome remained running for the cold-controller
samples. The saved summaries were independently regenerated from the local
trace snapshots and matched exactly before publication.

| Summary | Build |
| --- | --- |
| [baseline-0.1.3-build7.json](baseline-0.1.3-build7.json) | Instrumented 0.1.3, build 7 |
| [candidate-0.1.4-build9.json](candidate-0.1.4-build9.json) | Instrumented 0.1.4 candidate, build 9 |

The primary metric is **first helper instruction → focus accepted**, not a
physical click, a visible window or a painted frame. The reports intentionally
exclude the invalid passive Window Server observations. See
[the performance report](../PERFORMANCE.md) for the test context and
[the analyzer methodology](../../scripts/summarize-focus-traces.md) for exact
boundaries, components, conservative pairing rules and exclusions.

The two builds were measured sequentially on the same Mac and installation
path, with instrumentation enabled in both. This is an observed before/after
comparison, not a randomized or counterbalanced experiment. It cannot isolate
all effects of caches, system load or run order, and does not predict performance
on all Macs. There are only three cold samples per build; nearest-rank p95 for
that group equals its maximum.

| Median internal duration | Baseline | Candidate | Observed reduction |
| --- | ---: | ---: | ---: |
| Warm helper → accepted | 206.054708 ms | 140.669500 ms | 31.732% |
| Cold helper → accepted | 987.134292 ms | 399.427167 ms | 59.537% |
| Warm focus Apple event execution | 107.369083 ms | 46.741583 ms | 56.466% |

In the candidate trace, none of the three cold launches records
`controller.uiReady` before or at `focus.accepted`. Two manager windows are
created much later, about 48.30 and 35.60 seconds after acceptance. The two
subsequent `listWindows` operations start after those later UI events; they
are not part of the measured cold focus interval. This checks the instrumented
UI construction boundary, not whether pixels became visible.

## Reproduce a summary locally

Run from the repository root using a saved, completed trace directory from one
boot and one build. Replace the example input/output paths with your own local
paths; choose a new output file because existing files are never overwritten.

```sh
python3 scripts/test-summarize-focus-traces.py
python3 scripts/summarize-focus-traces.py /path/to/baseline-traces \
  --label baseline-0.1.3-build7 --output /path/to/new-baseline-summary.json
python3 scripts/summarize-focus-traces.py /path/to/candidate-traces \
  --label candidate-0.1.4-build9 --output /path/to/new-candidate-summary.json
```

The raw trace files remain private and are not included in the repository.
Public summaries contain only fixed metadata, public build labels, counts,
numeric durations and warm/cold categories. They contain no process/window IDs,
absolute timestamps, paths, profile names, titles or URLs. The public files
allow readers to verify the published descriptive arithmetic; reproducing the
event pairing requires a local raw trace snapshot.

To recalculate the reductions from the public summaries alone:

```sh
python3 - <<'PY'
import json
from pathlib import Path
p = Path('docs/performance')
before = json.loads((p / 'baseline-0.1.3-build7.json').read_text())
after = json.loads((p / 'candidate-0.1.4-build9.json').read_text())
for mode, metric in [('warm', 'helperToAccepted'), ('cold', 'helperToAccepted'),
                     ('warm', 'appleEventExecution')]:
    a = before['aggregates'][mode]['durations'][metric]['medianMs']
    b = after['aggregates'][mode]['durations'][metric]['medianMs']
    print(mode, metric, f'{a:.6f} → {b:.6f} ms; reduction {(a-b)/a*100:.3f}%')
PY
```
