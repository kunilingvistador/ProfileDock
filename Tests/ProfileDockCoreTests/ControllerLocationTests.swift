import Foundation
import XCTest
@testable import ProfileDockCore

final class ControllerLocationTests: XCTestCase {
    func testMostRecentlyRecordedControllerBeatsOldRunningAndRegisteredCopies() throws {
        try withDirectory { directory in
            let old = try makeController(in: directory, named: "Old")
            let current = try makeController(in: directory, named: "Current")
            let registry = ControllerLocationRegistry(directory: directory.appendingPathComponent("Support"))
            try registry.record(controllerURL: old)
            try registry.record(controllerURL: current)

            XCTAssertEqual(registry.controllerURL(), current)
            XCTAssertEqual(ControllerResolver.resolve(preferred: registry.controllerURL(), running: [old],
                registered: old, fallback: old, standardLocations: [old]), current)
        }
    }

    func testFirstOpenAfterMoveReplacesTheStaleLocationWithoutChangingTheHelper() throws {
        try withDirectory { directory in
            let original = try makeController(in: directory, named: "Original")
            let moved = directory.appendingPathComponent("Перенесённый ProfileDock.app", isDirectory: true)
            let registry = ControllerLocationRegistry(directory: directory.appendingPathComponent("Support"))
            try registry.record(controllerURL: original)
            try FileManager.default.moveItem(at: original, to: moved)
            XCTAssertNil(registry.controllerURL())

            try registry.record(controllerURL: moved)
            XCTAssertEqual(ControllerResolver.resolve(preferred: registry.controllerURL(), running: [],
                registered: original, fallback: original, standardLocations: []), moved)
        }
    }

    func testMalformedUnsupportedAndRelativeRegistryRecordsFallBackSafely() throws {
        try withDirectory { directory in
            let current = try makeController(in: directory, named: "Current")
            let registry = ControllerLocationRegistry(directory: directory.appendingPathComponent("Support"))
            try FileManager.default.createDirectory(at: registry.directory, withIntermediateDirectories: true)
            let records = [Data("not JSON".utf8),
                try JSONSerialization.data(withJSONObject: ["version": 2, "appPath": current.path]),
                try JSONSerialization.data(withJSONObject: ["version": 1, "appPath": "Current.app"])]
            for record in records {
                try record.write(to: registry.file)
                XCTAssertNil(registry.controllerURL())
                XCTAssertEqual(ControllerResolver.resolve(preferred: registry.controllerURL(), running: [],
                    registered: current, fallback: nil, standardLocations: []), current)
            }
        }
    }

    func testOneRunningControllerWinsOverAStaleRegistration() throws {
        try withDirectory { directory in
            let old = try makeController(in: directory, named: "Old")
            let running = try makeController(in: directory, named: "Running")
            XCTAssertEqual(ControllerResolver.resolve(preferred: nil, running: [running, running],
                registered: old, fallback: old, standardLocations: []), running.resolvingSymlinksInPath())
        }
    }

    func testSeveralRunningCopiesRequireAnotherExplicitLocation() throws {
        try withDirectory { directory in
            let first = try makeController(in: directory, named: "First")
            let second = try makeController(in: directory, named: "Second")
            for running in [[first, second], [second, first]] {
                XCTAssertEqual(ControllerResolver.resolve(preferred: nil, running: running,
                    registered: second, fallback: first, standardLocations: []), second)
                XCTAssertEqual(ControllerResolver.resolve(preferred: nil, running: running,
                    registered: nil, fallback: first, standardLocations: []), first)
                XCTAssertNil(ControllerResolver.resolve(preferred: nil, running: running,
                    registered: nil, fallback: nil, standardLocations: []))
            }
        }
    }

    func testKnownInstallAndEmbeddedPathRemainAvailableWhenOtherLocationsDisappear() throws {
        try withDirectory { directory in
            let missing = directory.appendingPathComponent("Missing.app", isDirectory: true)
            let installed = try makeController(in: directory, named: "Installed")
            let embedded = try makeController(in: directory, named: "Embedded")
            XCTAssertEqual(ControllerResolver.resolve(preferred: missing, running: [missing],
                registered: missing, fallback: embedded, standardLocations: [installed]), installed)
            try FileManager.default.removeItem(at: installed)
            XCTAssertEqual(ControllerResolver.resolve(preferred: missing, running: [missing],
                registered: missing, fallback: embedded, standardLocations: [installed]), embedded)
        }
    }

    func testForeignIncompleteAndUnlaunchableBundlesAreRejected() throws {
        try withDirectory { directory in
            let foreign = try makeController(in: directory, named: "Foreign", bundleID: "other.application")
            let wrongScheme = try makeController(in: directory, named: "WrongScheme", scheme: "something-else")
            let missingExecutable = try makeController(in: directory, named: "MissingExecutable")
            try FileManager.default.removeItem(at: missingExecutable.appendingPathComponent("Contents/MacOS/ProfileDock"))
            let notExecutable = try makeController(in: directory, named: "NotExecutable")
            try FileManager.default.setAttributes([.posixPermissions: 0o644],
                ofItemAtPath: notExecutable.appendingPathComponent("Contents/MacOS/ProfileDock").path)
            let registry = ControllerLocationRegistry(directory: directory.appendingPathComponent("Support"))
            for invalid in [foreign, wrongScheme, missingExecutable, notExecutable, URL(string: "https://example.com/ProfileDock.app")!] {
                XCTAssertFalse(ControllerResolver.isCompatibleController(invalid))
                XCTAssertThrowsError(try registry.record(controllerURL: invalid))
                XCTAssertNil(ControllerResolver.resolve(preferred: invalid, running: [invalid],
                    registered: invalid, fallback: invalid, standardLocations: []))
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: registry.file.path))
        }
    }

    func testAppAndExecutableSymbolicLinksAreRejected() throws {
        try withDirectory { directory in
            let valid = try makeController(in: directory, named: "Valid")
            let linkedApp = directory.appendingPathComponent("Linked.app", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: linkedApp, withDestinationURL: valid)
            XCTAssertFalse(ControllerResolver.isCompatibleController(linkedApp))

            let linkedExecutable = try makeController(in: directory, named: "LinkedExecutable")
            let executable = linkedExecutable.appendingPathComponent("Contents/MacOS/ProfileDock")
            try FileManager.default.removeItem(at: executable)
            try FileManager.default.createSymbolicLink(at: executable,
                withDestinationURL: valid.appendingPathComponent("Contents/MacOS/ProfileDock"))
            XCTAssertFalse(ControllerResolver.isCompatibleController(linkedExecutable))
        }
    }

    func testRegistryDoesNotReadOrOverwriteASymbolicLink() throws {
        try withDirectory { directory in
            let current = try makeController(in: directory, named: "Current")
            let registry = ControllerLocationRegistry(directory: directory.appendingPathComponent("Support"))
            try FileManager.default.createDirectory(at: registry.directory, withIntermediateDirectories: true)
            let otherFile = directory.appendingPathComponent("other.json")
            let original = try JSONSerialization.data(withJSONObject: ["version": 1, "appPath": current.path])
            try original.write(to: otherFile)
            try FileManager.default.createSymbolicLink(at: registry.file, withDestinationURL: otherFile)

            XCTAssertNil(registry.controllerURL())
            XCTAssertThrowsError(try registry.record(controllerURL: current))
            XCTAssertEqual(try Data(contentsOf: otherFile), original)
        }
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProfileDock-controller-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func makeController(in directory: URL, named name: String,
                                bundleID: String = ControllerResolver.bundleID, scheme: String = "profiledock") throws -> URL {
        let app = directory.appendingPathComponent(name + ".app", isDirectory: true)
        let executables = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: executables, withIntermediateDirectories: true)
        let executable = executables.appendingPathComponent("ProfileDock")
        try Data("test fixture, never executed".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let metadata: [String: Any] = ["CFBundleIdentifier": bundleID, "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "ProfileDock", "CFBundleURLTypes": [["CFBundleURLSchemes": [scheme]]]]
        try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        return app
    }
}
