#!/usr/bin/env python3
"""Summarize local ProfileDock traces without publishing their identities.

Only Python's standard library is used. See summarize-focus-traces.md for the
measurement boundary, conservative pairing rules and privacy limitations.
"""

from __future__ import annotations

import argparse
from collections import Counter
import json
import math
import os
from pathlib import Path
import re
import statistics
import sys


TERMINALS = {"focus.accepted", "focus.failed", "focus.superseded"}
VALUE_KEYS = {"queueMs", "compileMs", "executeMs", "totalMs", "succeeded"}
KNOWN_PHASES = {
    "helper.start", "helper.request", "controller.start", "controller.received",
    "controller.didFinishLaunching", "controller.modelReady", "controller.setupReady",
    "controller.uiReady", "focus.requested", *TERMINALS,
    "appleEvent.focusWindow", "appleEvent.listWindows", "appleEvent.previewWindow",
    "appleEvent.bindWindow",
}


def valid_integer(value: object, maximum: int) -> bool:
    return type(value) is int and 0 < value <= maximum


def parse_event(raw: object) -> dict:
    if not isinstance(raw, dict):
        raise ValueError("invalid_event")
    phase, stamp, process = (raw.get(key) for key in ("phase", "uptimeNs", "process"))
    if (not isinstance(phase, str) or not phase or len(phase) > 128
            or not valid_integer(stamp, 2**64 - 1)
            or not valid_integer(process, 2**31 - 1)):
        raise ValueError("invalid_event")
    values = raw.get("values", {})
    if not isinstance(values, dict):
        raise ValueError("invalid_event")
    clean_values = {}
    for key in VALUE_KEYS & values.keys():
        value = values[key]
        if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
            raise ValueError("invalid_event")
        if key == "succeeded" and value not in (0, 1):
            raise ValueError("invalid_event")
        clean_values[key] = value
    # Drop every other field at the parsing boundary. Identities below exist
    # only in memory to prevent cross-process pairing; they never reach output.
    return {"phase": phase, "time": stamp, "process": process, "values": clean_values}


def read_events(directory: Path) -> tuple[list[dict], dict]:
    counts = dict(fileCount=0, lineCount=0, eventCount=0, ignoredPhaseCount=0,
                  malformedLineCount=0, invalidEventCount=0, fileReadErrorCount=0)
    events = []
    for path in sorted(directory.glob("events*.jsonl")):
        counts["fileCount"] += 1
        if path.is_symlink() or not path.is_file():
            counts["fileReadErrorCount"] += 1
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            counts["fileReadErrorCount"] += 1
            continue
        for line in lines:
            counts["lineCount"] += 1
            try:
                raw = json.loads(line)
            except (ValueError, RecursionError):
                counts["malformedLineCount"] += 1
                continue
            try:
                event = parse_event(raw)
            except (ValueError, OverflowError):
                counts["invalidEventCount"] += 1
                continue
            counts["eventCount"] += 1
            if event["phase"] not in KNOWN_PHASES:
                counts["ignoredPhaseCount"] += 1
                continue
            events.append(event)
    # Timestamp ties retain file order; pairing rejects non-strict boundaries.
    return sorted(events, key=lambda event: event["time"]), counts


def distribution(values: list[float]) -> dict:
    if not values:
        return {"n": 0, "minMs": None, "medianMs": None, "p95Ms": None, "maxMs": None}
    ordered = sorted(values)
    return {"n": len(ordered), "minMs": round(ordered[0], 6),
            "medianMs": round(statistics.median(ordered), 6),
            "p95Ms": round(ordered[math.ceil(0.95 * len(ordered)) - 1], 6),
            "maxMs": round(ordered[-1], 6)}


def aggregate(samples: list[dict]) -> dict:
    keys = sorted({key for sample in samples for key in sample["durationsMs"]})
    observed = [sample["postAcceptanceListWindowsObserved"] for sample in samples]
    observed_totals = [item["totalMs"] for item in observed if item["totalMs"] is not None]
    return {"n": len(samples),
            "durations": {key: distribution([sample["durationsMs"][key]
                for sample in samples if key in sample["durationsMs"]]) for key in keys},
            "postAcceptanceListWindowsObserved": {
                "count": sum(item["count"] for item in observed),
                "totalMs": round(sum(observed_totals), 6) if len(observed_totals) == len(observed) else None,
                "samplesWithKnownTotal": len(observed_totals),
                "perSampleTotal": distribution(observed_totals)}}


def summarize(events: list[dict], counts: dict, label: str | None = None) -> dict:
    starts = [event for event in events if event["phase"] == "helper.start"]
    report = {"schemaVersion": 1, "status": "completed",
              "method": "helper_first_code_to_focus_accepted",
              "clock": "DispatchTime.uptimeNanoseconds", "measuresVisibleWindow": False,
              "percentileMethod": "nearest_rank", "input": counts,
              "counts": {"helperStarts": len(starts), "included": 0, "excluded": 0,
                         "warm": 0, "cold": 0}, "exclusionReasons": {},
              "missingComponentCounts": {}, "aggregates": {}, "samples": []}
    if label is not None:
        report["label"] = label
    reasons: Counter = Counter()
    missing: Counter = Counter()
    if (counts["malformedLineCount"] or counts["invalidEventCount"]
            or counts["fileReadErrorCount"] or not counts["fileCount"] or not starts):
        # An unreadable record could hide a failure or another request. Without
        # request IDs there is no safe way to limit its effect to one interval.
        report["status"] = "invalid_input"
        reasons["untrusted_or_empty_input"] = max(len(starts), 1)
    else:
        # A helper with no terminal result remains outstanding. A later helper
        # cannot rescue the preceding sample by donating its accepted event.
        outstanding = 0
        overlaps = set()
        for event in events:
            if event["phase"] == "helper.start":
                if outstanding:
                    overlaps.add(id(event))
                outstanding += 1
            elif event["phase"] in TERMINALS:
                outstanding = max(0, outstanding - 1)
        for index, start in enumerate(starts):
            limit = starts[index + 1]["time"] if index + 1 < len(starts) else 2**64
            interval = [event for event in events if start["time"] <= event["time"] < limit]
            by_phase = {phase: [event for event in interval if event["phase"] == phase]
                        for phase in KNOWN_PHASES}
            def reject(reason: str) -> None:
                reasons[reason] += 1
            if id(start) in overlaps:
                reject("overlapping_helper_requests"); continue
            if by_phase["focus.failed"] or by_phase["focus.superseded"]:
                reject("failed_or_superseded"); continue
            if len(by_phase["focus.accepted"]) != 1:
                reject("missing_or_multiple_accepted"); continue
            if len(by_phase["focus.requested"]) != 1 or len(by_phase["helper.request"]) != 1:
                reject("ambiguous_request_count"); continue
            cold = bool(by_phase["controller.start"])
            received = by_phase["controller.received"]
            if len(received) not in ((1, 2) if cold else (1,)):
                reject("ambiguous_controller_delivery"); continue
            if len(by_phase["controller.start"]) > 1:
                reject("multiple_controller_starts"); continue
            request = by_phase["helper.request"][0]
            focus = by_phase["focus.requested"][0]
            accepted = by_phase["focus.accepted"][0]
            controller_events = received + [focus, accepted] + by_phase["controller.start"]
            if (request["process"] != start["process"]
                    or len({event["process"] for event in controller_events}) != 1):
                reject("cross_process_chain"); continue
            ordered = [start, request, *received, focus, accepted]
            if any(left["time"] >= right["time"] for left, right in zip(ordered, ordered[1:])):
                reject("invalid_event_order"); continue
            if cold and not (request["time"] < by_phase["controller.start"][0]["time"] < received[0]["time"]):
                reject("invalid_controller_start_order"); continue
            focus_events = by_phase["appleEvent.focusWindow"]
            if (len(focus_events) > 1 or by_phase["appleEvent.previewWindow"]
                    or by_phase["appleEvent.bindWindow"]):
                reject("ambiguous_apple_events"); continue
            if focus_events and (focus_events[0]["process"] != focus["process"]
                    or not focus["time"] < focus_events[0]["time"] < accepted["time"]
                    or focus_events[0]["values"].get("succeeded") != 1):
                reject("invalid_focus_apple_event"); continue
            def ms(first: dict, last: dict) -> float:
                return (last["time"] - first["time"]) / 1_000_000
            durations = {"helperToAccepted": ms(start, accepted),
                         "helperResolver": ms(start, request),
                         "handoffToFirstControllerReceipt": ms(request, received[0]),
                         "firstReceiptToFocusRequested": ms(received[0], focus),
                         "focusToAccepted": ms(focus, accepted)}
            if cold:
                controller_start = by_phase["controller.start"][0]
                durations["controllerStartToFocusRequested"] = ms(controller_start, focus)
                durations["helperToControllerStart"] = ms(start, controller_start)
            if focus_events:
                for source, target in (("queueMs", "appleEventQueue"), ("compileMs", "appleEventCompile"),
                                       ("executeMs", "appleEventExecution"), ("totalMs", "appleEventTotal")):
                    if source in focus_events[0]["values"]:
                        durations[target] = focus_events[0]["values"][source]
                    else:
                        missing[target] += 1
            else:
                missing["focusAppleEvent"] += 1
            post = [event for event in by_phase["appleEvent.listWindows"]
                    if event["time"] > accepted["time"] and event["process"] == accepted["process"]]
            post_total = sum(event["values"].get("totalMs", 0) for event in post)
            if any("totalMs" not in event["values"] for event in post):
                missing["postAcceptanceListWindowsTotal"] += 1
                post_total = None
            report["samples"].append({"mode": "cold" if cold else "warm",
                "durationsMs": {key: round(value, 6) for key, value in durations.items()},
                "postAcceptanceListWindowsObserved": {"count": len(post),
                    "totalMs": round(post_total, 6) if post_total is not None else None}})
    samples = report["samples"]
    report["counts"].update(included=len(samples), excluded=len(starts) - len(samples),
                             warm=sum(sample["mode"] == "warm" for sample in samples),
                             cold=sum(sample["mode"] == "cold" for sample in samples))
    report["exclusionReasons"] = dict(sorted(reasons.items()))
    report["missingComponentCounts"] = dict(sorted(missing.items()))
    report["aggregates"] = {mode: aggregate(samples if mode == "all" else
        [sample for sample in samples if sample["mode"] == mode]) for mode in ("all", "warm", "cold")}
    return report


class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> None:
        # argparse's default error can echo an invalid private path or label.
        print('{"status":"invalid_arguments"}', file=sys.stderr)
        raise SystemExit(2)


def main() -> int:
    parser = PrivateArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Directory containing events*.jsonl; no recursive reads")
    parser.add_argument("--output", type=Path, help="New JSON file; omitted means stdout; never overwritten")
    parser.add_argument("--label", help="Optional public build label, e.g. baseline-0.1.3-build7")
    args = parser.parse_args()
    if (not args.input.is_dir() or (args.label is not None
            and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", args.label))):
        print('{"status":"invalid_arguments"}', file=sys.stderr)
        return 2
    try:
        events, counts = read_events(args.input)
    except OSError:
        print('{"status":"input_unavailable"}', file=sys.stderr)
        return 2
    report = summarize(events, counts, args.label)
    data = json.dumps(report, indent=2, sort_keys=True, allow_nan=False) + "\n"
    if args.output is None:
        sys.stdout.write(data)
    else:
        try:
            descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "w", encoding="utf-8") as output:
                output.write(data)
        except OSError:
            print('{"status":"output_unavailable_or_exists"}', file=sys.stderr)
            return 2
        print(json.dumps({"status": report["status"], "counts": report["counts"]}, sort_keys=True))
    return 0 if report["status"] == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
