#!/usr/bin/env python3
"""Run native AppModel regression checks with Command Line Tools (no XCTest).

Compiles production sources with an isolated fake service; never launches the app,
controls Chrome, registers hotkeys, or reads/writes real app preferences.
"""
from pathlib import Path
import os
import platform
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="profiledock-app-smoke-") as temporary:
    scratch = Path(temporary)
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(scratch / "ModuleCache")
    common = ["xcrun", "swiftc", "-swift-version", "5", "-target", platform.machine() + "-apple-macosx13.0",
              "-module-cache-path", str(scratch / "ModuleCache")]
    subprocess.run(common + ["-parse-as-library", "-emit-library", "-emit-module",
        "-module-name", "ProfileDockCore", "-emit-module-path", str(scratch / "ProfileDockCore.swiftmodule"),
        *map(str, sorted((ROOT / "Sources/ProfileDockCore").glob("*.swift"))),
        "-o", str(scratch / "libProfileDockCore.dylib")], check=True, env=environment)
    sources = sorted(path for path in (ROOT / "Sources/ProfileDock").glob("*.swift") if path.name != "main.swift")
    executable = scratch / "WindowRefreshSmoke"
    subprocess.run(common + ["-parse-as-library", "-I", str(scratch), "-L", str(scratch),
        "-lProfileDockCore", "-Xlinker", "-rpath", "-Xlinker", str(scratch),
        *map(str, sources), str(Path(__file__).with_name("WindowRefreshSmoke.swift")),
        "-o", str(executable)], check=True, env=environment)
    subprocess.run([str(executable)], check=True, env=environment)
