import AppKit
import CoreServices
import Foundation
import ProfileDockCore

@MainActor
enum LauncherExporter {
    static func export(shortcut: Shortcut, image: NSImage, directory: URL, controllerURL: URL) throws -> URL {
        let files = FileManager.default
        let launcherSource = controllerURL.appendingPathComponent("Contents/Resources/ProfileDockLauncher")
        guard files.isExecutableFile(atPath: launcherSource.path) else { throw ExportError.missingHelper }
        try files.createDirectory(at: directory, withIntermediateDirectories: true)

        let expectedID = "io.github.profiledock.launcher.\(shortcut.id.uuidString.lowercased())"
        let existing = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])
            .filter { $0.pathExtension == "app" && isOwned($0, shortcutID: shortcut.id, bundleID: expectedID) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        // Updates retain both this path and the app directory's filesystem identity.
        let destination = existing.first ?? directory.appendingPathComponent(SafeFilename.make(shortcut.name, id: shortcut.id), isDirectory: true)
        if files.fileExists(atPath: destination.path), !isOwned(destination, shortcutID: shortcut.id, bundleID: expectedID) {
            throw ExportError.foreignDestination
        }

        let stagingRoot = directory.appendingPathComponent(".profiledock-export-\(UUID().uuidString)", isDirectory: true)
        let stagedApp = stagingRoot.appendingPathComponent(destination.lastPathComponent, isDirectory: true)
        let contents = stagedApp.appendingPathComponent("Contents", isDirectory: true)
        let executables = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        try files.createDirectory(at: executables, withIntermediateDirectories: true)
        var preserveStaging = false
        defer { if !preserveStaging { try? files.removeItem(at: stagingRoot) } }
        try files.createDirectory(at: resources, withIntermediateDirectories: true)
        let executable = executables.appendingPathComponent("ProfileDockLauncher")
        try files.copyItem(at: launcherSource, to: executable)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let iconName = "ProfileIcon-\(UUID().uuidString.prefix(8))"
        try IconService.icns(image).write(to: resources.appendingPathComponent("\(iconName).icns"), options: .atomic)
        // Finder only uses a localized app name when the unlocalized name matches
        // the physical bundle stem. Keep the stable path for Dock bookmarks and
        // put the user's actual display name in each InfoPlist.strings instead.
        let bundleStem = destination.deletingPathExtension().lastPathComponent
        let localizedNames = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleDisplayName": shortcut.name, "CFBundleName": shortcut.name],
            format: .binary, options: 0)
        for language in ["en", "ru"] {
            let localization = resources.appendingPathComponent("\(language).lproj", isDirectory: true)
            try files.createDirectory(at: localization, withIntermediateDirectories: true)
            try localizedNames.write(to: localization.appendingPathComponent("InfoPlist.strings"), options: .atomic)
        }
        let metadata: [String: Any] = [
            "CFBundleIdentifier": expectedID,
            "CFBundleName": bundleStem,
            "CFBundleDisplayName": bundleStem,
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "ru"],
            "CFBundleExecutable": "ProfileDockLauncher",
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0",
            "CFBundleIconFile": iconName,
            "LSMinimumSystemVersion": "13.0",
            "LSHasLocalizedDisplayName": true,
            "LSUIElement": true,
            "NSHighResolutionCapable": true,
            "ProfileDockShortcutID": shortcut.id.uuidString,
            "ProfileDockControllerPath": controllerURL.path,
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"), options: .atomic)
        try Data("APPL????".utf8).write(to: contents.appendingPathComponent("PkgInfo"))
        try codesign(["--force", "--sign", "-", "--timestamp=none", stagedApp.path])
        try codesign(["--verify", "--strict", stagedApp.path])

        if files.fileExists(atPath: destination.path) {
            guard isOwned(destination, shortcutID: shortcut.id, bundleID: expectedID) else { throw ExportError.foreignDestination }
            // Finder and Dock bookmark the app directory by filesystem identity,
            // not just its path. Replacing that directory breaks existing file
            // references, so install only the preverified Contents directory.
            let installedContents = destination.appendingPathComponent("Contents", isDirectory: true)
            let previousContents = stagingRoot.appendingPathComponent("previous-Contents", isDirectory: true)
            try files.moveItem(at: installedContents, to: previousContents)
            do {
                try files.moveItem(at: contents, to: installedContents)
            } catch {
                // Restore the working shortcut if installing the prepared replacement fails.
                do { try files.moveItem(at: previousContents, to: installedContents) }
                catch {
                    preserveStaging = true
                    throw ExportError.restoreFailed(previousContents.path)
                }
                throw error
            }
        } else {
            try files.moveItem(at: stagedApp, to: destination)
        }
        // Refresh this app's registration so Finder can see a renamed localized
        // label immediately. This neither launches the helper nor restarts Dock.
        _ = LSRegisterURL(destination as CFURL, true)
        return destination
    }

    private static func isOwned(_ app: URL, shortcutID: UUID, bundleID: String) -> Bool {
        guard let values = try? app.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true,
              let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let rawID = plist["ProfileDockShortcutID"] as? String,
              UUID(uuidString: rawID) == shortcutID,
              plist["CFBundleIdentifier"] as? String == bundleID else { return false }
        return true
    }

    private static func codesign(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let diagnostic = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExportError.signingFailed(String(decoding: diagnostic.suffix(2000), as: UTF8.self))
        }
    }
}

private enum ExportError: LocalizedError {
    case missingHelper, foreignDestination, signingFailed(String), restoreFailed(String)
    var errorDescription: String? {
        switch self {
        case .missingHelper:
            return L("The shortcut helper is missing. Run the packaged ProfileDock app to create Dock shortcuts.", "Не найден компонент ярлыков. Для создания ярлыков запустите собранное приложение ProfileDock.")
        case .foreignDestination:
            return L("A different app already uses this filename. It has been left unchanged.", "По этому пути уже находится другое приложение. Оно сохранено без изменений.")
        case .signingFailed(let detail):
            return L("macOS could not prepare the shortcut: \(detail)", "macOS не удалось подготовить ярлык: \(detail)")
        case .restoreFailed(let path):
            return L("The shortcut could not be updated. Its previous Contents folder was preserved at \(path).", "Не удалось обновить ярлык. Его предыдущая папка Contents сохранена здесь: \(path).")
        }
    }
}
