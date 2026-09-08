#!/usr/bin/env python3
"""Build a local ProfileDock app and ZIP with Apple's Command Line Tools.

Ad-hoc signing is the default. --identity enables Developer ID signing and the
hardened runtime; notarization remains a separate, explicit release operation.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
BUNDLE_ID = "io.github.profiledock.app"
PRODUCTS = ("ProfileDock", "ProfileDockLauncher")


def run(*command: str | Path, capture: bool = False) -> str:
    args = [str(part) for part in command]
    if not capture:
        print("+ " + " ".join(args), flush=True)
    result = subprocess.run(args, cwd=REPO, check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scratch-path", type=Path,
                        help="SwiftPM cache outside the repository (default: system temp directory)")
    parser.add_argument("--universal", action="store_true",
                        help="Build arm64 and x86_64, then combine them with lipo")
    parser.add_argument("--identity", help="Installed Developer ID Application signing identity")
    parser.add_argument("--version", default="0.1.5", help="Numeric app version, default: 0.1.5")
    parser.add_argument("--build-number", default="1", help="Numeric build number, default: 1")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("--version must have three numeric components, for example 0.1.0")
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", args.build_number):
        parser.error("--build-number must contain one to three numeric components")
    if args.identity is not None and (not args.identity.strip() or args.identity.strip() == "-"):
        parser.error("omit --identity for ad-hoc signing, or supply a Developer ID Application identity")
    return args


def build_products(scratch: Path, architectures: list[str]) -> dict[str, list[Path]]:
    binaries: dict[str, list[Path]] = {name: [] for name in PRODUCTS}
    for architecture in architectures:
        common = ["xcrun", "swift", "build", "--package-path", str(REPO),
                  "--scratch-path", str(scratch / architecture),
                  "--configuration", "release", "--arch", architecture]
        for product in PRODUCTS:
            run(*common, "--product", product)
        binary_dir = Path(run(*common, "--show-bin-path", capture=True))
        for product in PRODUCTS:
            binary = binary_dir / product
            if not binary.is_file():
                raise RuntimeError(f"SwiftPM did not produce {binary}")
            binaries[product].append(binary)
    return binaries


def copy_binary(sources: list[Path], destination: Path) -> None:
    if len(sources) > 1:
        run("xcrun", "lipo", "-create", *sources, "-output", destination)
    else:
        shutil.copyfile(sources[0], destination)
    destination.chmod(0o755)


def validate_old_app(app: Path) -> None:
    if app.is_symlink():
        raise RuntimeError(f"Refusing to replace a symbolic link: {app}")
    if not app.exists():
        return
    try:
        with (app / "Contents/Info.plist").open("rb") as stream:
            bundle_id = plistlib.load(stream).get("CFBundleIdentifier")
    except (OSError, plistlib.InvalidFileException) as error:
        raise RuntimeError(f"Refusing to replace an unrecognized existing app: {app}") from error
    if bundle_id != BUNDLE_ID:
        raise RuntimeError(f"Refusing to replace another app: {app}")


def main() -> None:
    args = parse_args()
    if sys.platform != "darwin":
        raise RuntimeError("ProfileDock must be built on macOS with Apple's Command Line Tools")
    cache_key = hashlib.sha256(str(REPO).encode()).hexdigest()[:12]
    scratch = (args.scratch_path or Path(tempfile.gettempdir()) / "ProfileDock-build" / cache_key).resolve()
    scratch.mkdir(parents=True, exist_ok=True)
    architecture = platform.machine()
    if architecture not in {"arm64", "x86_64"}:
        raise RuntimeError(f"Unsupported build architecture: {architecture}")
    architectures = ["arm64", "x86_64"] if args.universal else [architecture]
    binaries = build_products(scratch, architectures)
    dist = REPO / "dist"
    dist.mkdir(exist_ok=True)
    final_app = dist / "ProfileDock.app"
    validate_old_app(final_app)
    arch_label = "universal" if args.universal else architecture
    signature_label = "signed" if args.identity else "local"
    archive = dist / f"ProfileDock-{args.version}-macos-{arch_label}-{signature_label}.zip"

    # Package outside synced folders: file providers may attach FinderInfo to
    # bundles in Documents after signing, even when no custom icon was set.
    with tempfile.TemporaryDirectory(prefix="profiledock-package-") as temporary:
        stage = Path(temporary)
        app = stage / "ProfileDock.app"
        contents = app / "Contents"
        resources = contents / "Resources"
        macos = contents / "MacOS"
        resources.mkdir(parents=True)
        macos.mkdir()
        copy_binary(binaries["ProfileDock"], macos / "ProfileDock")
        launcher = resources / "ProfileDockLauncher"
        copy_binary(binaries["ProfileDockLauncher"], launcher)
        iconset = stage / "AppIcon.iconset"
        run("xcrun", "swift", REPO / "scripts/make-app-icon.swift", iconset)
        run("/usr/bin/iconutil", "--convert", "icns", "--output", resources / "AppIcon.icns", iconset)
        metadata = {
            "CFBundleIdentifier": BUNDLE_ID,
            "CFBundleName": "ProfileDock",
            "CFBundleDisplayName": "ProfileDock",
            "CFBundleExecutable": "ProfileDock",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": args.version,
            "CFBundleVersion": args.build_number,
            "CFBundleIconFile": "AppIcon",
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "ru"],
            "LSMinimumSystemVersion": "13.0",
            "LSApplicationCategoryType": "public.app-category.productivity",
            "LSUIElement": True,
            "NSPrincipalClass": "NSApplication",
            "NSHighResolutionCapable": True,
            "NSAppleEventsUsageDescription": (
                "ProfileDock reads Chrome window titles to help you choose a window, "
                "then names and brings it forward. Browser data is not sent to the developers."
            ),
            "CFBundleURLTypes": [{
                "CFBundleURLName": BUNDLE_ID,
                "CFBundleTypeRole": "Viewer",
                "CFBundleURLSchemes": ["profiledock"],
            }],
        }
        with (contents / "Info.plist").open("wb") as stream:
            plistlib.dump(metadata, stream, sort_keys=True)
        purpose_strings = {
            "en": metadata["NSAppleEventsUsageDescription"],
            "ru": (
                "ProfileDock читает заголовки окон Chrome для выбора нужного окна, "
                "затем называет его и поднимает наверх. Данные браузера не отправляются разработчикам."
            ),
        }
        for language, description in purpose_strings.items():
            localized = resources / f"{language}.lproj"
            localized.mkdir()
            # UTF-16 includes a BOM, making the traditional .strings format
            # unambiguous to Foundation's localized Info.plist loader.
            escaped = description.replace("\\", "\\\\").replace('"', '\\"')
            (localized / "InfoPlist.strings").write_text(
                f'"NSAppleEventsUsageDescription" = "{escaped}";\n', encoding="utf-16"
            )
        identity = args.identity or "-"
        sign_options = ["--options", "runtime", "--timestamp"] if args.identity else []
        run("/usr/bin/codesign", "--force", "--sign", identity, *sign_options, launcher)
        entitlement_options: list[str | Path] = []
        if args.identity:
            entitlements = stage / "ProfileDock.entitlements"
            with entitlements.open("wb") as stream:
                plistlib.dump({"com.apple.security.automation.apple-events": True}, stream)
            entitlement_options = ["--entitlements", entitlements]
        # Finder/file providers can attach legacy icon metadata to a freshly
        # generated bundle. It is forbidden code-signing detritus. Remove only
        # this attribute from our new app; do not strip quarantine/provenance.
        subprocess.run(["/usr/bin/xattr", "-d", "com.apple.FinderInfo", str(app)],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run("/usr/bin/codesign", "--force", "--sign", identity, *sign_options,
            *entitlement_options, app)
        run("/usr/bin/codesign", "--verify", "--strict", "--verbose=2", launcher)
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", app)
        if archive.exists():
            archive.unlink()
        run("/usr/bin/ditto", "-c", "-k", "--keepParent", "--sequesterRsrc", app, archive)
        if final_app.exists():
            shutil.rmtree(final_app)
        shutil.move(str(app), str(final_app))
        subprocess.run(["/usr/bin/xattr", "-d", "com.apple.FinderInfo", str(final_app)],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", final_app)

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (dist / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    print(f"\nApp: {final_app}\nArchive: {archive}\nSHA-256: {digest}")
    if args.identity:
        print("Signed but NOT notarized. Follow docs/RELEASE.md before public distribution.")
    else:
        print("Local development build: ad-hoc signed, NOT notarized; no Developer ID identity.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        raise SystemExit(1)
