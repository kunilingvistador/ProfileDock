import Darwin
import Foundation
import XCTest
@testable import ProfileDockCore

final class PrivateStorageTests: XCTestCase {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ProfileDock-private-tests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func mode(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as! NSNumber).intValue
    }

    func testPrivateModesAndAtomicReplacementWithUmask022() throws {
        let originalMask = umask(0o022)
        defer { umask(originalMask) }
        try fixture { root in
            let store = PrivateStorage(directory: root.appendingPathComponent("Data"))
            try store.prepare()
            let icons = try store.prepareSubdirectory("Icons")
            try store.write(Data("old".utf8), to: "shortcuts.json")
            let heldOriginal = try FileHandle(forReadingFrom: store.directory.appendingPathComponent("shortcuts.json"))
            defer { try? heldOriginal.close() }
            try store.write(Data("replacement".utf8), to: "shortcuts.json")
            try store.write(Data([1, 2, 3]), to: "avatar.png", subdirectory: "Icons")
            XCTAssertEqual(try mode(store.directory), 0o700)
            XCTAssertEqual(try mode(icons), 0o700)
            XCTAssertEqual(try mode(store.directory.appendingPathComponent("shortcuts.json")), 0o600)
            XCTAssertEqual(try mode(icons.appendingPathComponent("avatar.png")), 0o600)
            XCTAssertEqual(try store.readFile("shortcuts.json"), Data("replacement".utf8))
            XCTAssertEqual(heldOriginal.readDataToEndOfFile(), Data("old".utf8))
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: store.directory.path)
                .contains { $0.hasPrefix(".profiledock-write-") })
        }
    }

    func testDataRootLinkIsRejectedWithoutTouchingTarget() throws {
        try fixture { root in
            let outside = root.appendingPathComponent("Outside")
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outside.path)
            let marker = outside.appendingPathComponent("shortcuts.json")
            try Data("unchanged".utf8).write(to: marker)
            let linked = root.appendingPathComponent("Data", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)
            let storage = PrivateStorage(directory: linked)
            XCTAssertThrowsError(try storage.prepare())
            XCTAssertThrowsError(try storage.prepareSubdirectory("Icons"))
            XCTAssertThrowsError(try storage.readFile("shortcuts.json"))
            XCTAssertThrowsError(try storage.write(Data(), to: "shortcuts.json"))
            XCTAssertEqual(try Data(contentsOf: marker), Data("unchanged".utf8))
            XCTAssertEqual(try mode(outside), 0o755)
            XCTAssertTrue(try linked.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
        }
    }

    func testIconsLinkIsRejectedWithoutTouchingTarget() throws {
        try fixture { root in
            let storage = PrivateStorage(directory: root.appendingPathComponent("Data"))
            try storage.prepare()
            let outside = root.appendingPathComponent("Outside")
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outside.path)
            let marker = outside.appendingPathComponent("avatar.png")
            try Data([7, 8, 9]).write(to: marker)
            try FileManager.default.createSymbolicLink(at: storage.directory.appendingPathComponent("Icons"), withDestinationURL: outside)
            XCTAssertThrowsError(try storage.prepareSubdirectory("Icons"))
            XCTAssertThrowsError(try storage.readFile("avatar.png", subdirectory: "Icons"))
            XCTAssertThrowsError(try storage.write(Data(), to: "avatar.png", subdirectory: "Icons"))
            XCTAssertThrowsError(try storage.removeFile("avatar.png", subdirectory: "Icons"))
            XCTAssertEqual(try Data(contentsOf: marker), Data([7, 8, 9]))
            XCTAssertEqual(try mode(outside), 0o755)
        }
    }

    func testJSONAndPNGLeafLinksAreNeverReadWrittenOrRemoved() throws {
        try fixture { root in
            let storage = PrivateStorage(directory: root.appendingPathComponent("Data"))
            try storage.prepare()
            let icons = try storage.prepareSubdirectory("Icons")
            let outside = root.appendingPathComponent("Outside.txt")
            try Data("keep".utf8).write(to: outside)
            let originalMode = try mode(outside)
            for (name, child, directory) in [("shortcuts.json", nil as String?, storage.directory), ("avatar.png", "Icons", icons)] {
                let link = directory.appendingPathComponent(name)
                try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
                XCTAssertThrowsError(try storage.readFile(name, subdirectory: child))
                XCTAssertThrowsError(try storage.write(Data(), to: name, subdirectory: child))
                XCTAssertThrowsError(try storage.removeFile(name, subdirectory: child))
                XCTAssertTrue(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
            }
            XCTAssertEqual(try Data(contentsOf: outside), Data("keep".utf8))
            XCTAssertEqual(try mode(outside), originalMode)
        }
    }

    func testDirectoryAndFIFOLeavesAreRejectedWithoutBlocking() throws {
        try fixture { root in
            let storage = PrivateStorage(directory: root.appendingPathComponent("Data"))
            try storage.prepare()
            try FileManager.default.createDirectory(at: storage.directory.appendingPathComponent("directory.json"), withIntermediateDirectories: false)
            let fifo = storage.directory.appendingPathComponent("pipe.json")
            XCTAssertEqual(fifo.path.withCString { mkfifo($0, 0o600) }, 0)
            for name in ["directory.json", "pipe.json"] {
                XCTAssertThrowsError(try storage.readFile(name))
                XCTAssertThrowsError(try storage.write(Data(), to: name))
                XCTAssertThrowsError(try storage.removeFile(name))
                XCTAssertTrue(FileManager.default.fileExists(atPath: storage.directory.appendingPathComponent(name).path))
            }
        }
    }

    func testTraversalNamesAreRejectedAndMissingReadsAreEmpty() throws {
        try fixture { root in
            let storage = PrivateStorage(directory: root.appendingPathComponent("Data"))
            XCTAssertNil(try storage.readFile("missing.json"))
            for name in ["", ".", "..", "../outside", "/absolute", "nested/file", "nul\0file"] {
                XCTAssertThrowsError(try storage.write(Data(), to: name))
                XCTAssertThrowsError(try storage.readFile(name))
                XCTAssertThrowsError(try storage.prepareSubdirectory(name))
            }
        }
    }

    func testReadLimitDoesNotDamageAnOversizedFile() throws {
        try fixture { root in
            let storage = PrivateStorage(directory: root.appendingPathComponent("Data"))
            let bytes = Data(repeating: 42, count: 32)
            try storage.write(bytes, to: "large.json")
            XCTAssertThrowsError(try storage.readFile("large.json", maximumBytes: 31))
            XCTAssertEqual(try storage.readFile("large.json", maximumBytes: 32), bytes)
            try storage.removeFile("large.json")
            XCTAssertNil(try storage.readFile("large.json"))
        }
    }

    func testProtectingBackupContainersDoesNotChangeOriginalContents() throws {
        try fixture { root in
            let originals = root.appendingPathComponent("OriginalContents")
            try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
            let executable = originals.appendingPathComponent("applet")
            try Data("original bytes".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o751], ofItemAtPath: executable.path)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: originals.path)
            let storage = PrivateStorage(directory: root.appendingPathComponent("Data"))
            let backups = try storage.prepareSubdirectory("Legacy Backups")
            let backup = try PrivateStorage(directory: backups).prepareSubdirectory(UUID().uuidString)
            let contents = backup.appendingPathComponent("Contents")
            try FileManager.default.copyItem(at: originals, to: contents)
            try PrivateStorage(directory: backup).prepare()
            XCTAssertEqual(try mode(backups), 0o700)
            XCTAssertEqual(try mode(backup), 0o700)
            XCTAssertEqual(try mode(contents), 0o755)
            XCTAssertEqual(try mode(contents.appendingPathComponent("applet")), 0o751)
            XCTAssertEqual(try Data(contentsOf: contents.appendingPathComponent("applet")), Data("original bytes".utf8))
            XCTAssertEqual(try mode(originals), 0o755)
        }
    }

    func testShortcutStoreDoesNotFollowItsJSONLink() throws {
        try fixture { root in
            let store = ShortcutStore(directory: root.appendingPathComponent("Data"))
            try store.privateStorage.prepare()
            let outside = root.appendingPathComponent("Outside.json")
            let bytes = try JSONEncoder().encode(StateDocument(shortcuts: []))
            try bytes.write(to: outside)
            try FileManager.default.createSymbolicLink(at: store.file, withDestinationURL: outside)
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try store.save([]))
            XCTAssertEqual(try Data(contentsOf: outside), bytes)
        }
    }

    func testRegularFilesCannotStandInForDataOrIconsDirectories() throws {
        try fixture { root in
            let directory = root.appendingPathComponent("Data")
            let marker = Data("keep".utf8)
            try marker.write(to: directory)
            let storage = PrivateStorage(directory: directory)
            XCTAssertThrowsError(try storage.prepare())
            XCTAssertEqual(try Data(contentsOf: directory), marker)
            try FileManager.default.removeItem(at: directory)
            try storage.prepare()
            let icons = directory.appendingPathComponent("Icons")
            try marker.write(to: icons)
            XCTAssertThrowsError(try storage.prepareSubdirectory("Icons"))
            XCTAssertThrowsError(try storage.write(Data(), to: "image.png", subdirectory: "Icons"))
            XCTAssertEqual(try Data(contentsOf: icons), marker)
        }
    }

    func testControllerRegistryUsesPrivateModesAndRejectsARedirectedRoot() throws {
        try fixture { root in
            let app = root.appendingPathComponent("Controller.app", isDirectory: true)
            let executable = app.appendingPathComponent("Contents/MacOS/ProfileDock")
            try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("fixture only, never executed".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
            let metadata: [String: Any] = ["CFBundleIdentifier": ControllerResolver.bundleID,
                "CFBundlePackageType": "APPL", "CFBundleExecutable": "ProfileDock",
                "CFBundleURLTypes": [["CFBundleURLSchemes": ["profiledock"]]]]
            try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
                .write(to: app.appendingPathComponent("Contents/Info.plist"))
            let registry = ControllerLocationRegistry(directory: root.appendingPathComponent("Data"))
            try registry.record(controllerURL: app)
            XCTAssertEqual(registry.controllerURL(), app)
            XCTAssertEqual(try mode(registry.directory), 0o700)
            XCTAssertEqual(try mode(registry.file), 0o600)
            let original = try Data(contentsOf: registry.file)
            let outside = root.appendingPathComponent("Outside")
            try FileManager.default.moveItem(at: registry.directory, to: outside)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outside.path)
            try FileManager.default.createSymbolicLink(at: registry.directory, withDestinationURL: outside)
            XCTAssertNil(registry.controllerURL())
            XCTAssertThrowsError(try registry.record(controllerURL: app))
            XCTAssertEqual(try Data(contentsOf: outside.appendingPathComponent("controller-location.json")), original)
            XCTAssertEqual(try mode(outside), 0o755)
        }
    }
}
