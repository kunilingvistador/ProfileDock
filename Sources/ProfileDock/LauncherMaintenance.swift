import AppKit
import Foundation
import ProfileDockCore

struct LauncherMaintenanceReport {
    var updated = 0
    var migrated = 0
    var legacyCount = 0
    var failures: [String] = []
}

/// Maintenance reads only known launcher folders and Dock references. It never
/// writes Dock preferences, launches applets or sends Chrome automation commands.
@MainActor enum LauncherMaintenance {
    static func updateAppearance(of shortcut: Shortcut, image: NSImage, store: ShortcutStore, controllerURL: URL) throws {
        let managed = (try? FileManager.default.contentsOfDirectory(at: store.launchersDirectory, includingPropertiesForKeys: nil)) ?? []
        let tracked = (try? Data(contentsOf: store.directory.appendingPathComponent("launcher-locations.json")))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        var seen = Set<String>()
        for app in managed + dockApplications() + tracked.map({ URL(fileURLWithPath: $0) }) {
            guard seen.insert(app.standardizedFileURL.path).inserted, LauncherExporter.isManaged(app, shortcutID: shortcut.id) else { continue }
            try LauncherExporter.upgrade(at: app, shortcut: shortcut, controllerURL: controllerURL,
                backupDirectory: store.directory.appendingPathComponent("Legacy Backups"), appearanceImage: image)
        }
    }

    static func synchronize(shortcuts: [Shortcut], store: ShortcutStore, controllerURL: URL,
                            upgradeLegacy: Bool = false, additionalURLs: [URL] = []) -> LauncherMaintenanceReport {
        var report = LauncherMaintenanceReport()
        let files = FileManager.default
        let managed = (try? files.contentsOfDirectory(at: store.launchersDirectory,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        let trackedFile = store.directory.appendingPathComponent("launcher-locations.json")
        let tracked = (try? Data(contentsOf: trackedFile)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let locations = managed + dockApplications() + additionalURLs + tracked.map { URL(fileURLWithPath: $0) }
        var seen = Set<String>()
        var retained = Set(tracked)
        for app in locations where app.isFileURL && app.pathExtension == "app" {
            let app = app.standardizedFileURL
            guard seen.insert(app.path).inserted, LauncherExporter.safeBundle(app),
                  let info = LauncherExporter.metadata(at: app) else { continue }
            if let rawID = info["ProfileDockShortcutID"] as? String,
               let id = UUID(uuidString: rawID), let shortcut = shortcuts.first(where: { $0.id == id }),
               LauncherExporter.isManaged(app, shortcutID: id) {
                do {
                    if try LauncherExporter.upgrade(at: app, shortcut: shortcut, controllerURL: controllerURL,
                                                    backupDirectory: store.directory.appendingPathComponent("Legacy Backups")) {
                        report.updated += 1
                    }
                    retained.insert(app.path)
                } catch { report.failures.append("\(app.deletingPathExtension().lastPathComponent): \(error.localizedDescription)") }
                continue
            }
            guard let identifier = info["CFBundleIdentifier"] as? String,
                  LauncherExporter.isLegacyIdentifier(identifier),
                  info["CFBundleExecutable"] as? String == "applet", info["ProfileDockShortcutID"] == nil,
                  let script = NSAppleScript(contentsOf: app.appendingPathComponent("Contents/Resources/Scripts/main.scpt"), error: nil),
                  let source = script.source, let target = LegacyShortcutImport.supportedTarget(in: source) else { continue }
            // An imported stable ID must already exist. Never create or rebind a
            // shortcut merely because a similarly named app appears in the Dock.
            let matches = shortcuts.filter { $0.windowName == target }
            guard matches.count == 1, let shortcut = matches.first else { continue }
            report.legacyCount += 1
            if upgradeLegacy {
                do {
                    if try LauncherExporter.upgrade(at: app, shortcut: shortcut, controllerURL: controllerURL,
                        backupDirectory: store.directory.appendingPathComponent("Legacy Backups"), legacyTarget: target) {
                        report.migrated += 1
                        report.legacyCount -= 1
                        retained.insert(app.path)
                    }
                } catch { report.failures.append("\(app.deletingPathExtension().lastPathComponent): \(error.localizedDescription)") }
            }
        }
        // Remember successful exports outside the managed folder/Dock as well.
        // No identity is inferred from this list: ownership is rechecked every run.
        let paths = retained.sorted()
        if paths != tracked.sorted() {
            do {
                try files.createDirectory(at: store.directory, withIntermediateDirectories: true)
                try JSONEncoder().encode(paths).write(to: trackedFile, options: .atomic)
            } catch { report.failures.append(L("Could not remember shortcut locations: ", "Не удалось сохранить расположение ярлыков: ") + error.localizedDescription) }
        }
        return report
    }

    private static func dockApplications() -> [URL] {
        let location = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        guard let data = try? Data(contentsOf: location),
              let preferences = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
              let entries = preferences["persistent-apps"] as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let tile = entry["tile-data"] as? [String: Any],
                  let file = tile["file-data"] as? [String: Any], let path = file["_CFURLString"] as? String,
                  let url = URL(string: path), url.isFileURL else { return nil }
            return url
        }
    }
}
