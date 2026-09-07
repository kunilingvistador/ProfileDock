# ProfileDock

**Your Chrome windows, one Dock shortcut each.**

A small, open-source macOS utility for people who keep several Chrome profiles open. Give each working window a recognizable name and icon, then bring it forward with one click.

**Status: local beta.** The packaging script produces an ad-hoc-signed development build by default. It is not notarized, and a frictionless public download is not available yet. See the [validation record](docs/VALIDATION.md) for completed checks and remaining gaps, and the [release checklist](docs/RELEASE.md) for public distribution.

## What it does

- Connects a shortcut to an existing Chrome window.
- Offers local Chrome profile names to make setup easier.
- Uses a distinct Dock helper for each shortcut, with its own label and icon.
- Restores a minimized target and brings that window forward.
- Reports missing or ambiguous bindings instead of opening a blank window.
- Keeps Chrome control in one app, so each shortcut does not need its own Automation permission.

The switching command does not open windows or tabs, change the selected tab, or resize/reposition windows. Native focus behavior still needs broader testing across macOS configurations; see [known limits](#known-limits).

## How the connection works

Chrome exposes a window's **given name**, but its AppleScript interface does not expose which profile owns that window. ProfileDock therefore asks you to associate a profile/shortcut with a particular open window once. It stores a unique name on that window and uses the exact name when switching.

Chrome saves named windows when it restores a session. If you close the bound window, start without restoring it, or change its name, reconnect the shortcut. A newly created window in the same profile does not automatically become the old window.

This is intentionally a window switcher with profile labels. It does not clone Chrome, create isolated browser installations, or promise automatic discovery of every window belonging to an account. See the [competitor comparison](docs/COMPETITORS.md) and [architecture](docs/ARCHITECTURE.md).

## Try it locally

Running a built app requires **macOS 13 or later and Google Chrome**. Open the Chrome windows you want to use before connecting them. End users do not need Python, Swift, or Xcode.

Building from source additionally requires **Python 3 and Apple's Command Line Tools with Swift 5.9 or later**. The app build does not require the full Xcode IDE.

```sh
python3 scripts/build.py
open dist/ProfileDock.app
```

For ongoing use, move the built app to a stable location such as Applications before creating shortcuts. Allow ProfileDock to control Google Chrome when macOS asks, then select an existing window for each shortcut. Keep the generated helper apps in place after adding them to the Dock. ProfileDock runs as a menu-bar utility; use its menu to reopen the manager.

The build prints the app, ZIP, and SHA-256 checksum locations. Build artifacts go to `dist/`, which is excluded from Git. SwiftPM packaging caches go to a system temporary directory unless `--scratch-path` is supplied.

```sh
python3 scripts/build.py --universal
python3 scripts/build.py --scratch-path /tmp/ProfileDock-build
```

The first command builds both Apple Silicon and Intel binaries. Without `--universal`, the app targets the build machine's architecture. CI produces development artifacts only and does not publish releases.

## Privacy and permissions

ProfileDock reads local profile names and optional avatar metadata, plus Chrome window names/titles for the window picker. It does not need page bodies, cookies, passwords, or browsing history to switch windows. Settings and custom icons stay on your Mac. Fetching an icon from a website, when requested, contacts that website.

The macOS **Automation → Google Chrome** permission lets the controller read and name windows and focus the selected window. The basic switcher does not require Accessibility, Screen Recording, a browser extension, or an account with ProfileDock.

No personal profiles, account names, photographs, or browser data belong in this repository. Please redact those details from screenshots and bug reports.

## Known limits

- Only Google Chrome on macOS is in scope for this beta.
- Each shortcut binds to an existing, named normal window. Incognito windows are excluded from persistent bindings.
- Changing or losing that window's name requires reconnecting it. Duplicate names never choose an arbitrary match.
- Profiles with several windows need an explicit choice of which window a shortcut represents.
- Spaces, fullscreen windows, Stage Manager, multiple monitors, and app-wide Hide need additional integration testing before support can be promised.
- Local ad-hoc builds may require macOS approval, and permissions can change after rebuilding. This is not a signed, notarized public release.

## Development

The project uses Swift Package Manager, AppKit/SwiftUI, and Apple events. It has no browser extension or bundled Chromium runtime. The controller is `ProfileDock`; the generic Dock helper is `ProfileDockLauncher`.

Run `swift test` for core model and parsing checks with a full Xcode installation selected: the XCTest framework is not included in the standalone Command Line Tools environment used for this project's initial build. The GitHub macOS runner has Xcode for these tests. Real window activation must also be checked on macOS: unit tests cannot verify Dock behavior or preservation of other windows. See the [architecture and integration checklist](docs/ARCHITECTURE.md).

The original app icon is drawn with AppKit by `scripts/make-app-icon.swift`. The source and that artwork are covered by the [MIT license](LICENSE). Chrome and other product names belong to their respective owners; this is an independent project.

## По-русски

ProfileDock делает отдельные значки в Dock для уже открытых окон Chrome. Один раз связываете значок с нужным окном, задаёте название и картинку — дальше переключаетесь одним нажатием.

Это локальная бета. Привязка использует уникальное название окна: после закрытия окна или изменения его названия понадобится связать его заново. Новые пустые окна при переключении не создаются. Для удобного публичного скачивания ещё нужны подпись Developer ID, нотариализация Apple и проверка на разных Mac.
