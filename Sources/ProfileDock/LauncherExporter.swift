import AppKit
import CoreServices
import CryptoKit
import Darwin
import Foundation
import ProfileDockCore

@MainActor
enum LauncherExporter {
    static let helperVersion = 2
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
            "ProfileDockLauncherVersion": helperVersion,
            "ProfileDockHelperDigest": digest(try Data(contentsOf: launcherSource)),
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
        guard safeBundle(app),
              let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let rawID = plist["ProfileDockShortcutID"] as? String,
              UUID(uuidString: rawID) == shortcutID,
              plist["CFBundleIdentifier"] as? String == bundleID else { return false }
        return true
    }

    /// Refresh only the forwarding code. Keep the Dock's file reference, identity,
    /// localized name and all icon bytes. Legacy conversion retains its bundle ID.
    @discardableResult
    static func upgrade(at app: URL, shortcut: Shortcut, controllerURL: URL,
                        backupDirectory: URL, legacyTarget: String? = nil, appearanceImage: NSImage? = nil) throws -> Bool {
        let files = FileManager.default
        guard safeBundle(app), var metadata = metadata(at: app),
              let identifier = metadata["CFBundleIdentifier"] as? String else { throw ExportError.foreignDestination }
        let legacy = legacyTarget != nil
        let rootAttributes = signingAttributes(at: app)
        if legacy {
            guard legacyTarget == shortcut.windowName,
                  isLegacyIdentifier(identifier), metadata["CFBundleExecutable"] as? String == "applet",
                  metadata["ProfileDockShortcutID"] == nil else { throw ExportError.foreignDestination }
        } else {
            guard isManaged(app, shortcutID: shortcut.id) else { throw ExportError.foreignDestination }
        }
        let helper = controllerURL.appendingPathComponent("Contents/Resources/ProfileDockLauncher")
        guard files.isExecutableFile(atPath: helper.path) else { throw ExportError.missingHelper }
        let helperData = try Data(contentsOf: helper)
        let sourceDigest = digest(helperData)
        let installedContents = app.appendingPathComponent("Contents", isDirectory: true)
        let installedHelper = installedContents.appendingPathComponent("MacOS/ProfileDockLauncher")
        if !legacy, appearanceImage == nil, metadata["ProfileDockLauncherVersion"] as? Int == helperVersion,
           metadata["ProfileDockControllerPath"] as? String == controllerURL.path,
           metadata["ProfileDockHelperDigest"] as? String == sourceDigest,
           files.isExecutableFile(atPath: installedHelper.path) { return false }

        // Synced Documents folders can attach Finder metadata while a bundle is
        // being prepared. Sign outside them, as the main app packager does.
        let stage = files.temporaryDirectory.appendingPathComponent("ProfileDock-update-\(UUID().uuidString)", isDirectory: true)
        let preparedApp = stage.appendingPathComponent(app.lastPathComponent, isDirectory: true)
        let contents = preparedApp.appendingPathComponent("Contents", isDirectory: true)
        var preserveStage = false
        defer { if !preserveStage { try? files.removeItem(at: stage) } }
        try files.createDirectory(at: preparedApp, withIntermediateDirectories: true)
        try files.copyItem(at: installedContents, to: contents)
        let executable = contents.appendingPathComponent("MacOS/ProfileDockLauncher")
        if files.fileExists(atPath: executable.path) { try files.removeItem(at: executable) }
        try helperData.write(to: executable)
        try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        if legacy {
            // No legacy automation remains on the launch path. The backup keeps
            // the complete original script and executable for restoration.
            try files.removeItem(at: contents.appendingPathComponent("MacOS/applet"))
            let scripts = contents.appendingPathComponent("Resources/Scripts")
            if files.fileExists(atPath: scripts.path) { try files.removeItem(at: scripts) }
            metadata["ProfileDockLegacyBundleIdentifier"] = identifier
            if let finderInfo = rootAttributes["com.apple.FinderInfo"], finderInfo.count >= 10,
               finderInfo[8] & 0x04 != 0 {
                // Convert a Finder custom icon to a normal bundle icon before
                // removing the signing-incompatible root metadata.
                let iconName = "ProfileDockImportedIcon"
                let image = NSWorkspace.shared.icon(forFile: app.path)
                try IconService.icns(image).write(to: contents.appendingPathComponent("Resources/\(iconName).icns"))
                metadata["CFBundleIconFile"] = iconName
            }
        }
        metadata["CFBundleExecutable"] = "ProfileDockLauncher"
        metadata["ProfileDockShortcutID"] = shortcut.id.uuidString
        metadata["ProfileDockControllerPath"] = controllerURL.path
        metadata["ProfileDockLauncherVersion"] = helperVersion
        // Bundle signing changes Mach-O signature bytes. Compare the bundled
        // source fingerprint, not the signed installed executable, on later runs.
        metadata["ProfileDockHelperDigest"] = sourceDigest
        metadata["LSUIElement"] = true
        metadata["LSMinimumSystemVersion"] = "13.0"
        if let image = appearanceImage {
            let resources = contents.appendingPathComponent("Resources")
            let iconName = "ProfileIcon-\(UUID().uuidString.prefix(8))"
            try IconService.icns(image).write(to: resources.appendingPathComponent("\(iconName).icns"), options: .atomic)
            metadata["CFBundleIconFile"] = iconName
            let stem = app.deletingPathExtension().lastPathComponent
            metadata["CFBundleName"] = stem; metadata["CFBundleDisplayName"] = stem
            metadata["CFBundleDevelopmentRegion"] = "en"
            metadata["CFBundleLocalizations"] = ["en", "ru"]
            metadata["LSHasLocalizedDisplayName"] = true
            let names = try PropertyListSerialization.data(fromPropertyList:
                ["CFBundleDisplayName": shortcut.name, "CFBundleName": shortcut.name], format: .binary, options: 0)
            for language in ["en", "ru"] {
                let localization = resources.appendingPathComponent("\(language).lproj")
                try files.createDirectory(at: localization, withIntermediateDirectories: true)
                try names.write(to: localization.appendingPathComponent("InfoPlist.strings"), options: .atomic)
            }
        }
        let plist = try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"), options: .atomic)
        clearSigningDetritus(inPreparedApp: preparedApp)
        try codesign(["--force", "--sign", "-", "--timestamp=none", preparedApp.path])
        try codesign(["--verify", "--strict", preparedApp.path])

        if legacy {
            // Finish a durable backup before touching the working app. UUIDs
            // avoid overwriting an earlier backup, including after interrupted runs.
            let backup = backupDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try files.createDirectory(at: backup, withIntermediateDirectories: true)
            try files.copyItem(at: installedContents, to: backup.appendingPathComponent("Contents"))
            let attributes = try PropertyListSerialization.data(fromPropertyList: rootAttributes, format: .binary, options: 0)
            try attributes.write(to: backup.appendingPathComponent("original-root-attributes.plist"), options: .atomic)
            try Data(app.path.utf8).write(to: backup.appendingPathComponent("original-path.txt"), options: .atomic)
        }
        // Fail closed if an app was replaced while the staged update was prepared.
        guard safeBundle(app), self.metadata(at: app)?["CFBundleIdentifier"] as? String == identifier,
              (legacy ? self.metadata(at: app)?["ProfileDockShortcutID"] == nil : isManaged(app, shortcutID: shortcut.id))
        else { throw ExportError.foreignDestination }
        let previous = stage.appendingPathComponent("previous-Contents", isDirectory: true)
        try files.moveItem(at: installedContents, to: previous)
        do {
            try files.moveItem(at: contents, to: installedContents)
            clearSigningAttributes(at: app)
            try codesign(["--verify", "--strict", app.path])
        }
        catch {
            do {
                if files.fileExists(atPath: installedContents.path) { try files.removeItem(at: installedContents) }
                try files.moveItem(at: previous, to: installedContents)
                restoreSigningAttributes(rootAttributes, at: app)
            }
            catch { preserveStage = true; throw ExportError.restoreFailed(previous.path) }
            throw error
        }
        _ = LSRegisterURL(app as CFURL, true)
        return true
    }

    static func metadata(at app: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func clearSigningDetritus(inPreparedApp app: URL) {
        let descendants = FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)?
            .allObjects.compactMap { $0 as? URL } ?? []
        // Only the disposable prepared copy is touched. Preserve quarantine,
        // provenance and every other attribute; original and backup stay intact.
        for file in [app] + descendants { clearSigningAttributes(at: file) }
    }

    private static func clearSigningAttributes(at file: URL) {
        for name in ["com.apple.FinderInfo", "com.apple.ResourceFork"] {
            _ = file.path.withCString { path in name.withCString { attribute in removexattr(path, attribute, XATTR_NOFOLLOW) } }
        }
    }

    private static func signingAttributes(at file: URL) -> [String: Data] {
        var result: [String: Data] = [:]
        for name in ["com.apple.FinderInfo", "com.apple.ResourceFork"] {
            file.path.withCString { path in name.withCString { attribute in
                let count = getxattr(path, attribute, nil, 0, 0, XATTR_NOFOLLOW)
                guard count >= 0 else { return }
                var data = Data(count: count)
                let read = data.withUnsafeMutableBytes { getxattr(path, attribute, $0.baseAddress, count, 0, XATTR_NOFOLLOW) }
                if read == count { result[name] = data }
            } }
        }
        return result
    }

    private static func restoreSigningAttributes(_ attributes: [String: Data], at file: URL) {
        for (name, data) in attributes {
            _ = file.path.withCString { path in name.withCString { attribute in
                data.withUnsafeBytes { setxattr(path, attribute, $0.baseAddress, data.count, 0, XATTR_NOFOLLOW) }
            } }
        }
    }

    static func isLegacyIdentifier(_ value: String) -> Bool {
        value.hasPrefix("local.") && value.contains(".chrome-window-switcher.")
    }

    static func isManaged(_ app: URL, shortcutID: UUID) -> Bool {
        guard safeBundle(app), let info = metadata(at: app),
              let id = info["ProfileDockShortcutID"] as? String, UUID(uuidString: id) == shortcutID,
              info["CFBundleExecutable"] as? String == "ProfileDockLauncher",
              let bundleID = info["CFBundleIdentifier"] as? String else { return false }
        return bundleID == "io.github.profiledock.launcher.\(shortcutID.uuidString.lowercased())" ||
            (isLegacyIdentifier(bundleID) && info["ProfileDockLegacyBundleIdentifier"] as? String == bundleID)
    }

    /// Bundle-owned paths must be real files/directories, never redirected links.
    static func safeBundle(_ app: URL) -> Bool {
        guard app.isFileURL, app.pathExtension == "app",
              let values = try? app.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
              values.isSymbolicLink != true, values.isDirectory == true else { return false }
        let contents = app.appendingPathComponent("Contents")
        guard let attributes = try? contents.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
              attributes.isSymbolicLink != true, attributes.isDirectory == true,
              let entries = FileManager.default.enumerator(at: contents, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { return false }
        for case let file as URL in entries {
            guard let attributes = try? file.resourceValues(forKeys: [.isSymbolicLinkKey]), attributes.isSymbolicLink != true else { return false }
        }
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
