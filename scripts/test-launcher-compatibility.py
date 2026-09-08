#!/usr/bin/env python3
"""Run real launcher filesystem regressions with macOS Command Line Tools.

No XCTest, browser, UI session, existing user shortcuts, or network is needed.
The two tiny Mach-O fixture helpers are copied and signed, never executed.
Run from any directory: python3 scripts/test-launcher-compatibility.py
"""

from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]


def run(*command: str | Path, source: str | None = None) -> None:
    subprocess.run([str(part) for part in command], input=source, text=True,
                   cwd=REPO, check=True)


def main() -> None:
    if sys.platform != "darwin":
        raise RuntimeError("These filesystem and AppKit checks require macOS.")
    # Keep code-signing fixtures outside cloud-synced Documents directories.
    temporary = Path(tempfile.mkdtemp(prefix="profiledock-compatibility-"))
    succeeded = False
    try:
        print("Compiling the production exporter and native fixture helpers...", flush=True)
        module = temporary / "modules"
        module.mkdir()
        cache = temporary / "module-cache"
        core = sorted((REPO / "Sources/ProfileDockCore").glob("*.swift"))
        run("xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
            "-module-cache-path", cache, "-emit-library", "-emit-module",
            "-module-name", "ProfileDockCore", *core,
            "-emit-module-path", module / "ProfileDockCore.swiftmodule",
            "-o", module / "libProfileDockCore.dylib")

        helpers = []
        for version, result in ((1, 17), (2, 29)):
            helper = temporary / f"helper-v{version}"
            run("xcrun", "clang", "-x", "c", "-", "-o", helper,
                source=f"int main(void) {{ return {result}; }}\n")
            helpers.append(helper)
        if helpers[0].read_bytes() == helpers[1].read_bytes():
            raise RuntimeError("The two update fixtures must contain different executable bytes.")

        binary = temporary / "test-launcher-compatibility"
        production = REPO / "Sources/ProfileDock"
        run("xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
            "-module-cache-path", cache, "-I", module, "-L", module,
            "-lProfileDockCore", "-Xlinker", "-rpath", "-Xlinker", module,
            production / "LauncherExporter.swift", production / "IconService.swift",
            production / "Localization.swift", REPO / "scripts/test-launcher-compatibility.swift",
            "-o", binary)
        run(binary, temporary / "fixtures", *helpers)
        succeeded = True
    finally:
        if succeeded:
            shutil.rmtree(temporary)
        else:
            print(f"Failed-check fixtures retained at: {temporary}", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Launcher compatibility checks failed: {error}", file=sys.stderr)
        raise SystemExit(1)
