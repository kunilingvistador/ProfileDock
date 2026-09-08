#!/usr/bin/env python3
"""Pure stdlib regression fixtures; never starts ProfileDock or Chrome."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


sys.dont_write_bytecode = True
SCRIPT = Path(__file__).with_name("summarize-focus-traces.py")
spec = importlib.util.spec_from_file_location("focus_summary", SCRIPT)
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)


def event(phase, milliseconds, process=900001, values=None):
    return {"phase": phase, "uptimeNs": int(milliseconds * 1_000_000),
            "process": process, "values": values or {}}


def chain(start=1000, duration=200, process=900002, cold=False):
    rows = [event("helper.start", start, process), event("helper.request", start + 50, process)]
    if cold:
        rows.append(event("controller.start", start + 60))
    rows.append(event("controller.received", start + 70))
    if cold:
        rows.append(event("controller.received", start + 80))
    rows += [event("focus.requested", start + 90),
             event("appleEvent.focusWindow", start + duration - 10,
                   values={"queueMs": 4, "compileMs": 0, "executeMs": duration - 110,
                           "totalMs": duration - 100, "succeeded": 1}),
             event("focus.accepted", start + duration),
             event("appleEvent.listWindows", start + duration + 50,
                   values={"queueMs": 1, "compileMs": 0, "executeMs": 39,
                           "totalMs": 40, "succeeded": 1})]
    return rows


class SummaryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="profiledock-summary-tests-")
        self.directory = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def report(self, rows, suffix=""):
        (self.directory / "events-fixture.jsonl").write_text(
            "\n".join(json.dumps(row) for row in rows) + "\n" + suffix, encoding="utf-8")
        events, counts = summary.read_events(self.directory)
        return summary.summarize(events, counts, "test-build")

    def test_warm_cold_statistics_components_and_privacy(self):
        rows = chain(duration=200) + chain(start=2000, duration=400, process=900003)
        rows += chain(start=3000, duration=600, process=900004, cold=True)
        # Unknown/private fields and phase strings must never reach the report.
        rows[0]["privatePath"] = "/Users/Secret Person/Private Window"
        rows.append(event("private-phase-secret", 3700))
        report = self.report(list(reversed(rows)))
        self.assertEqual(report["counts"], dict(helperStarts=3, included=3, excluded=0, warm=2, cold=1))
        self.assertEqual(report["aggregates"]["all"]["durations"]["helperToAccepted"],
                         dict(n=3, minMs=200, medianMs=400, p95Ms=600, maxMs=600))
        self.assertEqual(report["aggregates"]["warm"]["durations"]["helperToAccepted"]["medianMs"], 300)
        self.assertEqual(report["samples"][2]["durationsMs"]["controllerStartToFocusRequested"], 30)
        self.assertEqual(report["samples"][0]["durationsMs"]["helperResolver"], 50)
        self.assertEqual(report["samples"][0]["durationsMs"]["handoffToFirstControllerReceipt"], 20)
        self.assertEqual(report["samples"][0]["durationsMs"]["appleEventQueue"], 4)
        self.assertEqual(report["aggregates"]["all"]["postAcceptanceListWindowsObserved"]["count"], 3)
        self.assertEqual(report["aggregates"]["all"]["postAcceptanceListWindowsObserved"]["totalMs"], 120)
        encoded = json.dumps(report)
        for secret in ["900001", "900002", "900003", "900004", "Secret Person", "private-phase-secret", "uptimeNs"]:
            self.assertNotIn(secret, encoded)
        self.assertFalse(report["measuresVisibleWindow"])

    def test_nearest_rank_and_even_median_are_not_mean(self):
        self.assertEqual(summary.distribution([1, 2, 3, 100]),
                         dict(n=4, minMs=1, medianMs=2.5, p95Ms=100, maxMs=100))
        self.assertEqual(summary.distribution(list(range(1, 21)))["p95Ms"], 19)

    def test_malformed_record_invalidates_entire_input(self):
        report = self.report(chain(), '{"phase": broken\n')
        self.assertEqual(report["status"], "invalid_input")
        self.assertEqual(report["input"]["malformedLineCount"], 1)
        self.assertEqual(report["counts"]["included"], 0)

    def test_invalid_number_and_boolean_timestamp_fail_closed(self):
        for change in ({"uptimeNs": True}, {"uptimeNs": -1}, {"values": {"queueMs": float("nan")}}):
            with self.subTest(change=change):
                rows = chain(); rows[0].update(change)
                report = self.report(rows)
                self.assertEqual(report["status"], "invalid_input")
                self.assertEqual(report["input"]["invalidEventCount"], 1)

    def test_overlap_cannot_donate_previous_accepted_to_next_helper(self):
        report = self.report(chain(duration=300) + chain(start=1150, process=900003))
        self.assertEqual(report["counts"]["included"], 0)
        self.assertEqual(report["exclusionReasons"],
                         {"missing_or_multiple_accepted": 1, "overlapping_helper_requests": 1})

    def test_missing_accepted_is_excluded(self):
        report = self.report([row for row in chain() if row["phase"] != "focus.accepted"])
        self.assertEqual(report["counts"]["included"], 0)
        self.assertEqual(report["exclusionReasons"], {"missing_or_multiple_accepted": 1})

    def test_failed_and_superseded_are_excluded(self):
        for phase in ("focus.failed", "focus.superseded"):
            with self.subTest(phase=phase):
                rows = chain()
                for row in rows:
                    if row["phase"] == "focus.accepted": row["phase"] = phase
                report = self.report(rows)
                self.assertEqual(report["exclusionReasons"], {"failed_or_superseded": 1})

    def test_duplicate_focus_request_and_warm_delivery_are_excluded(self):
        for phase, expected in (("focus.requested", "ambiguous_request_count"),
                                ("controller.received", "ambiguous_controller_delivery")):
            with self.subTest(phase=phase):
                report = self.report(chain() + [event(phase, 1085)])
                self.assertEqual(report["exclusionReasons"], {expected: 1})

    def test_cross_controller_chain_is_excluded(self):
        rows = chain()
        for row in rows:
            if row["phase"] == "focus.accepted": row["process"] = 900099
        report = self.report(rows)
        self.assertEqual(report["exclusionReasons"], {"cross_process_chain": 1})

    def test_missing_component_is_not_an_invented_zero(self):
        rows = chain()
        for row in rows:
            if row["phase"] == "appleEvent.focusWindow": del row["values"]["queueMs"]
            if row["phase"] == "appleEvent.listWindows": del row["values"]["totalMs"]
        report = self.report(rows)
        self.assertEqual(report["counts"]["included"], 1)
        self.assertNotIn("appleEventQueue", report["aggregates"]["all"]["durations"])
        self.assertEqual(report["missingComponentCounts"],
                         {"appleEventQueue": 1, "postAcceptanceListWindowsTotal": 1})
        observed = report["aggregates"]["all"]["postAcceptanceListWindowsObserved"]
        self.assertEqual(observed["count"], 1)
        self.assertEqual(observed["perSampleTotal"]["n"], 0)
        self.assertIsNone(observed["totalMs"])
        self.assertIsNone(report["samples"][0]["postAcceptanceListWindowsObserved"]["totalMs"])

    def test_successful_cli_produces_private_file(self):
        self.report(chain())
        output = self.directory / "summary.json"
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.directory),
                                 "--label", "public-test-build", "--output", str(output)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(output.read_text())["counts"]["included"], 1)
        self.assertNotIn(str(output), result.stdout)

    def test_output_is_exclusive_and_error_does_not_echo_path(self):
        self.report(chain())
        output = self.directory / "private-existing-report.json"
        output.write_text("keep")
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.directory),
                                 "--output", str(output)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(output.read_text(), "keep")
        self.assertNotIn(str(output), result.stderr)

    def test_argument_error_does_not_echo_unknown_private_argument(self):
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.directory),
                                 "--unknown", "/Users/Private Person/Secret"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stderr), {"status": "invalid_arguments"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
