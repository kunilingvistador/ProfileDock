#!/usr/bin/env python3
"""Build an isolated local UI preview. Does not install, launch or release anything.

The distinct bundle ID forces AppModel's demo mode. No Chrome Automation,
global hotkeys, real settings, controller registry or profiledock URL scheme.
"""

from pathlib import Path
import os
import plistlib
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
IDENTIFIER = "io.github.profiledock.preview"


def main():
    scratch = Path(tempfile.gettempdir()) / "ProfileDock-ui-preview-build"
    module_cache = scratch / "module-cache"
    module_cache.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(module_cache))
    common = ["xcrun", "swift", "build", "--package-path", str(REPO), "--scratch-path", str(scratch)]
    command = [*common, "--product", "ProfileDock",
               "-Xswiftc", "-module-cache-path", "-Xswiftc", str(module_cache)]
    subprocess.run(command, check=True, env=environment)
    binary_dir = Path(subprocess.check_output(
        [*common, "--show-bin-path"], text=True, env=environment).strip())
    # This destination is separate from the normal build and installed app.
    app = REPO / "dist/preview/ProfileDock Preview.app"
    if app.is_symlink():
        raise RuntimeError("Preview destination must not be a symbolic link")
    if app.exists():
        with (app / "Contents/Info.plist").open("rb") as f:
            if plistlib.load(f).get("CFBundleIdentifier") != IDENTIFIER:
                raise RuntimeError("Refusing to replace a non-preview app")
        shutil.rmtree(app)
    contents = app / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    (contents / "Resources").mkdir()
    shutil.copy2(binary_dir / "ProfileDock", contents / "MacOS/ProfileDock")
    metadata = {
        "CFBundleIdentifier": IDENTIFIER,
        "CFBundleName": "ProfileDock Preview",
        "CFBundleDisplayName": "ProfileDock Preview",
        "CFBundleExecutable": "ProfileDock",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "0.1.7",
        "CFBundleVersion": "18",
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": True,
        "NSHighResolutionCapable": True,
        "NSPrincipalClass": "NSApplication",
        "CFBundleDevelopmentRegion": "en",
        "CFBundleLocalizations": ["en", "ru"],
    }
    icon = REPO / "dist/ProfileDock.app/Contents/Resources/AppIcon.icns"
    if icon.is_file():
        shutil.copy2(icon, contents / "Resources/AppIcon.icns")
        metadata["CFBundleIconFile"] = "AppIcon"
    with (contents / "Info.plist").open("wb") as f:
        plistlib.dump(metadata, f)
    # The synced Documents file provider may attach FinderInfo to a freshly
    # created bundle. Like build.py, clear only this forbidden signing metadata
    # from our generated preview; preserve provenance and quarantine attributes.
    def clear_finder_info():
        subprocess.run(["/usr/bin/xattr", "-d", "com.apple.FinderInfo", str(app)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    clear_finder_info()
    subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(app)], check=True)
    # File Provider can reattach FinderInfo between clearing and verification.
    # Retry only that metadata race; every other signing failure remains fatal.
    for attempt in range(3):
        clear_finder_info()
        verification = subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(app)],
                                      capture_output=True, text=True)
        if verification.returncode == 0:
            break
        if "resource fork, Finder information" not in verification.stderr or attempt == 2:
            raise RuntimeError(verification.stderr.strip())
    print(f"Local preview ready: {app}")
    print("Preview uses sample data. No public release or installed app was changed.")


if __name__ == "__main__":
    main()
