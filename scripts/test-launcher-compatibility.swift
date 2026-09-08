// Compiled by test-launcher-compatibility.py against the production exporter.
// File identity and backup checks are not a substitute for a real Dock click.
import AppKit
import CryptoKit
import Darwin
import Foundation
import ProfileDockCore

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

private struct FileIdentity {
    let device: dev_t
    let inode: ino_t
    let resourceID: NSObject
    let bookmark: Data
    let reference: URL
}

@MainActor
private final class CompatibilitySuite {
    let root: URL
    let helperV1: URL
    let helperV2: URL
    let files = FileManager.default
    var assertions = 0
    var failures = 0
    var cases = 0

    init(root: URL, helperV1: URL, helperV2: URL) {
        self.root = root; self.helperV1 = helperV1; self.helperV2 = helperV2
    }

    func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        assertions += 1
        guard try condition() else { throw CheckFailure(description: message) }
    }

    func run(_ name: String, _ body: () throws -> Void) {
        cases += 1
        do {
            try body()
            print("PASS: \(name)")
        } catch {
            failures += 1
            print("FAIL: \(name): \(error)")
        }
    }

    func folder(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func controller(in directory: URL, name: String, helper: URL?) throws -> URL {
        let app = directory.appendingPathComponent(name + ".app", isDirectory: true)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        try files.createDirectory(at: resources, withIntermediateDirectories: true)
        try writePlist(["CFBundleIdentifier": "io.github.profiledock.app"],
                       to: app.appendingPathComponent("Contents/Info.plist"))
        if let helper {
            let destination = resources.appendingPathComponent("ProfileDockLauncher")
            try files.copyItem(at: helper, to: destination)
            try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        }
        return app
    }

    func image() throws -> NSImage {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0) else {
            throw CheckFailure(description: "Could not prepare the in-memory icon fixture")
        }
        for y in 0..<16 {
            for x in 0..<16 {
                bitmap.setColor(NSColor(calibratedRed: CGFloat(x) / 16,
                                        green: CGFloat(y) / 16, blue: 0.6, alpha: 1), atX: x, y: y)
            }
        }
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.addRepresentation(bitmap)
        return image
    }

    func readPlist(_ url: URL) throws -> [String: Any] {
        guard let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url),
                          format: nil) as? [String: Any] else {
            throw CheckFailure(description: "Invalid fixture plist: \(url.lastPathComponent)")
        }
        return value
    }

    func writePlist(_ value: [String: Any], to url: URL) throws {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
            .write(to: url)
    }

    func readAttribute(_ name: String, at url: URL) throws -> Data? {
        let size = url.path.withCString { path in
            name.withCString { attribute in getxattr(path, attribute, nil, 0, 0, XATTR_NOFOLLOW) }
        }
        if size < 0 {
            if errno == ENOATTR { return nil }
            throw CheckFailure(description: "getxattr failed for \(name): errno \(errno)")
        }
        var data = Data(count: size)
        let count = data.withUnsafeMutableBytes { buffer in
            url.path.withCString { path in
                name.withCString { attribute in
                    getxattr(path, attribute, buffer.baseAddress, buffer.count, 0, XATTR_NOFOLLOW)
                }
            }
        }
        guard count == size else { throw CheckFailure(description: "Could not read the complete \(name) attribute") }
        return data
    }

    func writeAttribute(_ name: String, data: Data, at url: URL) throws {
        let result = data.withUnsafeBytes { buffer in
            url.path.withCString { path in
                name.withCString { attribute in
                    setxattr(path, attribute, buffer.baseAddress, buffer.count, 0, XATTR_NOFOLLOW)
                }
            }
        }
        guard result == 0 else { throw CheckFailure(description: "setxattr failed for \(name): errno \(errno)") }
    }

    func identity(_ app: URL) throws -> FileIdentity {
        var information = stat()
        try require(lstat(app.path, &information) == 0, "lstat failed for the app root")
        guard let resourceID = try app.resourceValues(forKeys: [.fileResourceIdentifierKey])
            .fileResourceIdentifier as? NSObject,
              let reference = (app as NSURL).fileReferenceURL() else {
            throw CheckFailure(description: "Could not record filesystem identity")
        }
        return FileIdentity(device: information.st_dev, inode: information.st_ino,
                            resourceID: resourceID,
                            bookmark: try app.bookmarkData(options: .suitableForBookmarkFile,
                                includingResourceValuesForKeys: [.fileResourceIdentifierKey], relativeTo: nil),
                            reference: reference)
    }

    func requireIdentity(_ original: FileIdentity, at app: URL) throws {
        let updated = try identity(app)
        try require(updated.device == original.device && updated.inode == original.inode,
                    "The existing app root was replaced")
        try require(updated.resourceID.isEqual(original.resourceID), "File resource identifier changed")
        var stale = false
        let resolved = try URL(resolvingBookmarkData: original.bookmark, options: .withoutUI,
                               relativeTo: nil, bookmarkDataIsStale: &stale)
        try require(resolved.resolvingSymlinksInPath().standardizedFileURL == app.resolvingSymlinksInPath().standardizedFileURL,
                    "The original bookmark no longer resolves to the same app path")
        let referencePath = (original.reference as NSURL).filePathURL
        try require(referencePath?.resolvingSymlinksInPath().standardizedFileURL == app.resolvingSymlinksInPath().standardizedFileURL,
                    "The original file-reference URL no longer resolves to the app")
        try require(try resolved.resourceValues(forKeys: [.fileResourceIdentifierKey])
            .fileResourceIdentifier as? NSObject == original.resourceID,
                    "The bookmark resolves to a different filesystem object")
    }

    /// File hashes, directory entries, symlink destinations, modes and the three
    /// explicitly exercised extended attributes. Other xattrs are not audited.
    /// Does not follow a symlink out of the fixture or backup tree.
    func snapshot(_ root: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        func visit(_ url: URL, relative: String) throws {
            let attributes = try files.attributesOfItem(atPath: url.path)
            let kind = attributes[.type] as? FileAttributeType
            let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
            if kind == .typeSymbolicLink {
                result[relative] = "link:\(try files.destinationOfSymbolicLink(atPath: url.path))"
            } else if kind == .typeDirectory {
                result[relative] = "directory:\(mode)"
                for child in try files.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    try visit(child, relative: relative + "/" + child.lastPathComponent)
                }
            } else if kind == .typeRegular {
                let hash = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
                result[relative] = "file:\(mode):\(hash)"
            } else {
                throw CheckFailure(description: "Unsupported fixture file type: \(relative)")
            }
            if kind != .typeSymbolicLink {
                for name in ["com.apple.FinderInfo", "com.apple.ResourceFork", "io.github.profiledock.fixture"] {
                    if let data = try readAttribute(name, at: url) {
                        result[relative + "@" + name] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                    }
                }
            }
        }
        try visit(root, relative: ".")
        return result
    }

    func backupContents(under root: URL) throws -> [URL] {
        guard files.fileExists(atPath: root.path) else { return [] }
        var result: [URL] = []
        func visit(_ url: URL) throws {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { return }
            if url.lastPathComponent == "Contents" { result.append(url); return }
            for child in try files.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                try visit(child)
            }
        }
        try visit(root)
        return result
    }

    func requireBackup(_ original: [String: String], under directory: URL) throws {
        let backups = try backupContents(under: directory)
        try require(backups.count == 1, "Expected exactly one original Contents backup; found \(backups.count)")
        try require(try snapshot(backups[0]) == original, "The backup differs from the original Contents")
    }

    func verifySignature(_ app: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--strict", app.path]
        let diagnostic = Pipe()
        process.standardError = diagnostic
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let output = diagnostic.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try require(process.terminationStatus == 0,
                    "Installed signature failed: \(String(decoding: output, as: UTF8.self))")
    }

    /// Signing the enclosing app changes the Mach-O signature bytes. Compare
    /// executable instructions independently, and verify the installed signature.
    func executableCode(_ executable: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["otool", "-s", "__TEXT", "__text", executable.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try require(process.terminationStatus == 0, "Could not inspect helper executable instructions")
        // The first output line is the input filename; the rest identifies and
        // dumps the same section at the same addresses in our native fixtures.
        let instructions = String(decoding: bytes, as: UTF8.self).split(separator: "\n").dropFirst().joined(separator: "\n")
        try require(instructions.contains("(__TEXT,__text) section"), "Missing helper code section")
        return instructions
    }

    func requireRefusedWithoutChanges(_ directory: URL, _ action: () throws -> Void) throws {
        let before = try snapshot(directory)
        var refused = false
        do { try action() } catch { refused = true }
        try require(refused, "Expected a rejected update")
        try require(try snapshot(directory) == before, "A refused update changed fixture files")
    }

    func modernUpgrade() throws {
        let directory = try folder("modern")
        let v1 = try controller(in: directory, name: "Controller V1", helper: helperV1)
        let v2 = try controller(in: directory, name: "Controller V2", helper: helperV2)
        let id = UUID()
        let item = Shortcut(id: id, name: "Studio — Работа", windowName: "Existing bound window",
                            iconFile: id.uuidString + ".png")
        let store = ShortcutStore(directory: directory.appendingPathComponent("State"))
        try files.createDirectory(at: store.iconsDirectory, withIntermediateDirectories: true)
        let icon = try image()
        try IconService.png(icon, size: 512).write(to: store.iconsDirectory.appendingPathComponent(item.iconFile!))
        try store.save([item])
        let stateBefore = try snapshot(store.directory)
        let app = try LauncherExporter.export(shortcut: item, image: icon,
                          directory: directory.appendingPathComponent("Launchers"), controllerURL: v1)
        let originalIdentity = try identity(app)
        let contents = app.appendingPathComponent("Contents")
        let metadata = try readPlist(contents.appendingPathComponent("Info.plist"))
        let iconName = metadata["CFBundleIconFile"] as! String
        let iconFile = contents.appendingPathComponent("Resources/\(iconName).icns")
        let originalIcon = try Data(contentsOf: iconFile)
        let labels = try Data(contentsOf: contents.appendingPathComponent("Resources/ru.lproj/InfoPlist.strings"))
        let backup = directory.appendingPathComponent("Backups")
        // Updating the installed controller normally keeps its Applications
        // path. A changed path alone must not be what makes this check pass.
        let bundledHelper = v1.appendingPathComponent("Contents/Resources/ProfileDockLauncher")
        try files.removeItem(at: bundledHelper)
        try files.copyItem(at: helperV2, to: bundledHelper)
        try require(try LauncherExporter.upgrade(at: app, shortcut: item,
                    controllerURL: v1, backupDirectory: backup), "Same-path V1 → V2 did not report an upgrade")
        try requireIdentity(originalIdentity, at: app)
        let updated = try readPlist(contents.appendingPathComponent("Info.plist"))
        try require(updated["ProfileDockShortcutID"] as? String == id.uuidString, "Shortcut UUID changed")
        try require(updated["CFBundleIdentifier"] as? String == metadata["CFBundleIdentifier"] as? String,
                    "Modern bundle identifier changed")
        try require(updated["ProfileDockControllerPath"] as? String == v1.path, "Unmoved controller path changed")
        try require(try executableCode(helperV1) != executableCode(helperV2), "V1/V2 executable instructions must differ")
        try require(try executableCode(contents.appendingPathComponent("MacOS/ProfileDockLauncher")) == executableCode(helperV2),
                    "V2 helper executable instructions were not installed")
        try require(updated["CFBundleIconFile"] as? String == iconName, "Existing icon reference changed")
        try require(try Data(contentsOf: iconFile) == originalIcon, "Existing icon bytes changed")
        try require(try Data(contentsOf: contents.appendingPathComponent("Resources/ru.lproj/InfoPlist.strings")) == labels,
                    "Localized display label changed")
        try require(try snapshot(store.directory) == stateBefore, "Upgrade changed the user's saved state or PNG")
        try require(try store.load() == [item], "Stored UUID or binding changed")
        try verifySignature(app)
        let after = try snapshot(directory)
        try require(try !LauncherExporter.upgrade(at: app, shortcut: item,
                    controllerURL: v1, backupDirectory: backup), "Repeated upgrade was not a no-op")
        try require(try snapshot(directory) == after, "Repeated upgrade changed files or added a backup")
        // Moving the controller is the inverse case: same helper, new fallback
        // path. The existing Dock helper still needs an in-place metadata update.
        try require(try LauncherExporter.upgrade(at: app, shortcut: item,
                    controllerURL: v2, backupDirectory: backup), "Controller move was not recorded")
        try requireIdentity(originalIdentity, at: app)
        let moved = try readPlist(contents.appendingPathComponent("Info.plist"))
        try require(moved["ProfileDockControllerPath"] as? String == v2.path, "New controller path missing")
        try require(moved["ProfileDockShortcutID"] as? String == id.uuidString, "Controller move changed the UUID")
        try require(try Data(contentsOf: iconFile) == originalIcon, "Controller move changed the icon")
        try require(try snapshot(store.directory) == stateBefore, "Controller move changed saved state")
        try verifySignature(app)
        let afterMove = try snapshot(directory)
        try require(try !LauncherExporter.upgrade(at: app, shortcut: item,
                    controllerURL: v2, backupDirectory: backup), "Repeated move was not a no-op")
        try require(try snapshot(directory) == afterMove, "Repeated move changed files")
    }

    func legacyUpgrade() throws {
        let directory = try folder("legacy")
        let v2 = try controller(in: directory, name: "Controller V2", helper: helperV2)
        let item = Shortcut(name: "Legacy Studio", windowName: "Existing legacy target")
        let app = directory.appendingPathComponent("Legacy Studio.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        for relative in ["MacOS", "Resources/Scripts", "Resources/ru.lproj", "Resources/en.lproj"] {
            try files.createDirectory(at: contents.appendingPathComponent(relative), withIntermediateDirectories: true)
        }
        let legacyID = "local.profiledock-tests.chrome-window-switcher.\(UUID().uuidString.lowercased())"
        let info: [String: Any] = ["CFBundleIdentifier": legacyID, "CFBundleName": "Legacy Studio",
            "CFBundleDisplayName": "Мой старый ярлык", "CFBundleExecutable": "applet",
            "CFBundleIconFile": "applet", "CFBundlePackageType": "APPL",
            "CFBundleVersion": "17", "NSAppleScriptEnabled": true,
            "FixturePreservedValue": "keep this metadata"]
        try writePlist(info, to: contents.appendingPathComponent("Info.plist"))
        try files.copyItem(at: helperV1, to: contents.appendingPathComponent("MacOS/applet"))
        // Deliberately not executable AppleScript: the exporter must never parse or run it.
        let script = Data("fixture compiled script bytes\0\u{01}\u{02}".utf8)
        try script.write(to: contents.appendingPathComponent("Resources/Scripts/main.scpt"))
        let icon = try IconService.icns(image())
        let legacyIcon = contents.appendingPathComponent("Resources/applet.icns")
        try icon.write(to: legacyIcon)
        // User-customized legacy icons can carry code-signing detritus. It must
        // survive in the original backup, while only the staged copy is cleaned.
        var finderInfo = Data(repeating: 0, count: 32)
        finderInfo.replaceSubrange(0..<4, with: Data("icns".utf8))
        let resourceFork = Data("legacy icon resource fork fixture".utf8)
        let customAttribute = Data("preserve unrelated attributes".utf8)
        try writeAttribute("com.apple.FinderInfo", data: finderInfo, at: legacyIcon)
        try writeAttribute("com.apple.ResourceFork", data: resourceFork, at: legacyIcon)
        try writeAttribute("io.github.profiledock.fixture", data: customAttribute, at: legacyIcon)
        for language in ["ru", "en"] {
            try writePlist(["CFBundleDisplayName": "Legacy \(language) custom label"],
                to: contents.appendingPathComponent("Resources/\(language).lproj/InfoPlist.strings"))
        }
        var rootFinderInfo = Data(repeating: 0, count: 32)
        rootFinderInfo[8] = 0x20 // A legacy bundle flag; not a custom Finder icon.
        let rootCustomAttribute = Data("preserve unrelated root attributes".utf8)
        try writeAttribute("com.apple.FinderInfo", data: rootFinderInfo, at: app)
        // macOS rejects a resource fork on a directory (EPERM). The real file
        // resource fork is exercised on applet.icns above instead.
        try writeAttribute("io.github.profiledock.fixture", data: rootCustomAttribute, at: app)
        let original = try snapshot(contents)
        let originalIdentity = try identity(app)
        let backup = directory.appendingPathComponent("Backups")
        try require(try LauncherExporter.upgrade(at: app, shortcut: item, controllerURL: v2,
                    backupDirectory: backup, legacyTarget: item.windowName), "Legacy applet was not upgraded")
        try requireIdentity(originalIdentity, at: app)
        try require(try readAttribute("com.apple.FinderInfo", at: app) == nil,
                    "Installed app root still has code-signing FinderInfo detritus")
        try require(try readAttribute("com.apple.ResourceFork", at: app) == nil,
                    "Installed app root still has code-signing ResourceFork detritus")
        try require(try readAttribute("io.github.profiledock.fixture", at: app) == rootCustomAttribute,
                    "Migration removed an unrelated app-root attribute")
        let updated = try readPlist(contents.appendingPathComponent("Info.plist"))
        try require(updated["CFBundleIdentifier"] as? String == legacyID, "Legacy bundle identifier changed")
        try require(updated["ProfileDockLegacyBundleIdentifier"] as? String == legacyID, "Legacy ownership marker missing")
        try require(updated["ProfileDockShortcutID"] as? String == item.id.uuidString, "Legacy UUID route missing")
        try require(updated["ProfileDockControllerPath"] as? String == v2.path, "Legacy controller path missing")
        try require(updated["CFBundleExecutable"] as? String == "ProfileDockLauncher", "Legacy executable was not switched")
        for key in ["CFBundleName", "CFBundleDisplayName", "CFBundleIconFile", "FixturePreservedValue"] {
            try require(updated[key] as? String == info[key] as? String, "Legacy metadata changed: \(key)")
        }
        try require(try Data(contentsOf: contents.appendingPathComponent("Resources/applet.icns")) == icon,
                    "Legacy icon content changed")
        try require(try readAttribute("com.apple.FinderInfo", at: legacyIcon) == nil,
                    "Installed icon still has code-signing FinderInfo detritus")
        try require(try readAttribute("com.apple.ResourceFork", at: legacyIcon) == nil,
                    "Installed icon still has code-signing ResourceFork detritus")
        try require(try readAttribute("io.github.profiledock.fixture", at: legacyIcon) == customAttribute,
                    "Migration removed an unrelated extended attribute")
        for language in ["ru", "en"] {
            let relative = "./Resources/\(language).lproj/InfoPlist.strings"
            try require(try snapshot(contents)[relative] == original[relative], "Legacy localized label changed")
        }
        try require(try executableCode(contents.appendingPathComponent("MacOS/ProfileDockLauncher")) == executableCode(helperV2),
                    "Legacy migration did not install the current helper")
        try requireBackup(original, under: backup)
        let savedContents = try backupContents(under: backup)[0]
        let savedIcon = savedContents.appendingPathComponent("Resources/applet.icns")
        try require(try readAttribute("com.apple.FinderInfo", at: savedIcon) == finderInfo,
                    "The backup lost the original FinderInfo")
        try require(try readAttribute("com.apple.ResourceFork", at: savedIcon) == resourceFork,
                    "The backup lost the original resource fork")
        try require(try readAttribute("io.github.profiledock.fixture", at: savedIcon) == customAttribute,
                    "The backup lost the unrelated extended attribute")
        let rootAttributes = try readPlist(savedContents.deletingLastPathComponent()
                                          .appendingPathComponent("original-root-attributes.plist"))
        try require(rootAttributes["com.apple.FinderInfo"] as? Data == rootFinderInfo,
                    "Root FinderInfo was not preserved in the backup manifest")
        try require(rootAttributes["com.apple.ResourceFork"] == nil,
                    "The backup invented a resource fork absent from the original app root")
        try verifySignature(app)
        let after = try snapshot(directory)
        try require(try !LauncherExporter.upgrade(at: app, shortcut: item,
                    controllerURL: v2, backupDirectory: backup), "Migrated legacy bundle was not recognized on repeat")
        try require(try snapshot(directory) == after, "Repeated legacy migration changed files")
    }

    func refusedUpdate(_ kind: String) throws {
        let directory = try folder("refused-" + kind)
        let v1 = try controller(in: directory, name: "Controller V1", helper: helperV1)
        let v2 = try controller(in: directory, name: "Controller V2", helper: kind == "missing-helper" ? nil : helperV2)
        let item = Shortcut(name: "Protected", windowName: "Keep this exact binding")
        var app = try LauncherExporter.export(shortcut: item, image: image(),
            directory: directory.appendingPathComponent("Launchers"), controllerURL: v1)
        var requested = item
        switch kind {
        case "foreign-bundle":
            let infoURL = app.appendingPathComponent("Contents/Info.plist")
            var info = try readPlist(infoURL)
            info["CFBundleIdentifier"] = "com.example.unrelated"
            try writePlist(info, to: infoURL)
        case "wrong-uuid":
            requested.id = UUID()
        case "app-symlink":
            let link = directory.appendingPathComponent("Linked.app")
            try files.createSymbolicLink(at: link, withDestinationURL: app)
            app = link
        case "contents-symlink", "plist-symlink":
            let source = app.appendingPathComponent(kind == "contents-symlink" ? "Contents" : "Contents/Info.plist")
            let target = directory.appendingPathComponent("Outside-protected-bundle-content")
            try files.moveItem(at: source, to: target)
            try files.createSymbolicLink(at: source, withDestinationURL: target)
        case "missing-helper": break
        default: throw CheckFailure(description: "Unknown refusal fixture: \(kind)")
        }
        let originalIdentity = try identity(app)
        try requireRefusedWithoutChanges(directory) {
            _ = try LauncherExporter.upgrade(at: app, shortcut: requested,
                    controllerURL: v2, backupDirectory: directory.appendingPathComponent("Backups"))
        }
        if kind == "app-symlink" {
            let after = try identity(app)
            try require(after.device == originalIdentity.device && after.inode == originalIdentity.inode,
                        "Refused update replaced the symlink itself")
        } else {
            try requireIdentity(originalIdentity, at: app)
        }
    }
}

@main
private struct LauncherCompatibilityTests {
    @MainActor static func main() {
        guard CommandLine.arguments.count == 4 else {
            fputs("Run via scripts/test-launcher-compatibility.py\n", stderr)
            exit(2)
        }
        let suite = CompatibilitySuite(root: URL(fileURLWithPath: CommandLine.arguments[1]),
            helperV1: URL(fileURLWithPath: CommandLine.arguments[2]),
            helperV2: URL(fileURLWithPath: CommandLine.arguments[3]))
        suite.run("controller update preserves existing shortcut identity, icon and state") {
            try suite.modernUpgrade()
        }
        suite.run("legacy migration preserves Dock identity, metadata and exact backup; repeat is a no-op") {
            try suite.legacyUpgrade()
        }
        for kind in ["foreign-bundle", "wrong-uuid", "app-symlink", "contents-symlink", "plist-symlink", "missing-helper"] {
            suite.run("refuses \(kind) without changing protected files") { try suite.refusedUpdate(kind) }
        }
        print("Launcher compatibility: \(suite.cases) cases, \(suite.assertions) assertions, \(suite.failures) failures.")
        print("No Chrome/UI/helper execution. Mid-swap rollback injection and live Dock behavior are not covered.")
        if suite.failures != 0 { exit(1) }
    }
}
