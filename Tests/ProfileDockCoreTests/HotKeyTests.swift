import XCTest
@testable import ProfileDockCore

final class HotKeyTests: XCTestCase {
    let a = UUID(), b = UUID()
    let first = HotKey(keyCode: 18, modifiers: HotKey.option | HotKey.command)
    let second = HotKey(keyCode: 19, modifiers: HotKey.control | HotKey.option)

    func testRejectsUnsafeOrUnsupportedCombinationsAndDuplicateAssignments() throws {
        for key in [HotKey(keyCode: 18, modifiers: 0), HotKey(keyCode: 18, modifiers: HotKey.command),
                    HotKey(keyCode: 18, modifiers: HotKey.shift | HotKey.option),
                    HotKey(keyCode: 53, modifiers: 15), HotKey(keyCode: 0, modifiers: 31)] {
            XCTAssertFalse(key.isValid)
            XCTAssertThrowsError(try HotKeyDocument().assigning(key, to: a).validate())
        }
        XCTAssertThrowsError(try HotKeyDocument().assigning(first, to: a).assigning(first, to: b).validate())
        var document = HotKeyDocument().assigning(first, to: a)
        document.assignments.append(.init(shortcutID: a, hotKey: second))
        XCTAssertThrowsError(try document.validate())
        document = HotKeyDocument(); document.version = 2
        XCTAssertThrowsError(try document.validate())
    }
    func testSeparateStorageSurvivesOldShortcutWriterAndUsesPrivatePermissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let hotkeys = HotKeyStore(directory: root), shortcuts = ShortcutStore(directory: root)
        XCTAssertEqual(try hotkeys.load(), HotKeyDocument())
        let document = HotKeyDocument().assigning(first, to: a)
        try hotkeys.save(document)
        var shortcut = Shortcut(id: a, name: "Work", windowName: "Original")
        try shortcuts.save([shortcut])
        shortcut.name = "New name"; shortcut.windowName = "Reconnected"
        try shortcuts.save([shortcut])
        XCTAssertEqual(try hotkeys.load(), document)
        XCTAssertEqual(try shortcuts.load(), [shortcut])
        let file = root.appendingPathComponent("hotkeys.json")
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let bytes = Data("broken".utf8); try bytes.write(to: file)
        XCTAssertThrowsError(try hotkeys.load())
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        XCTAssertEqual(try shortcuts.load(), [shortcut])
    }

    @MainActor final class Backend: HotKeyRegistering {
        var keys: [UInt32: HotKey] = [:]
        var blocked: Set<HotKey> = []
        var registrations = 0
        func register(_ key: HotKey, token: UInt32) throws {
            if blocked.contains(key) || keys.values.contains(key) { throw HotKeyError.registrationFailed(-9878) }
            keys[token] = key; registrations += 1
        }
        func unregister(token: UInt32) { keys.removeValue(forKey: token) }
    }
    func testRegistrationAndDiskFailuresPreservePreviousWorkingKey() async throws {
        try await MainActor.run {
            let backend = Backend(); var saved = HotKeyDocument().assigning(first, to: a); var failWrite = false
            let coordinator = try HotKeyCoordinator(document: saved, knownIDs: [a], backend: backend) { next in
                if failWrite { throw CocoaError(.fileWriteNoPermission) }; saved = next
            }
            coordinator.reconcile()
            let initial = backend.keys
            backend.blocked.insert(second)
            XCTAssertThrowsError(try coordinator.apply(saved.assigning(second, to: a)))
            XCTAssertEqual(backend.keys, initial)
            backend.blocked.remove(second); failWrite = true
            XCTAssertThrowsError(try coordinator.apply(saved.assigning(second, to: a)))
            XCTAssertEqual(backend.keys, initial)
            XCTAssertEqual(coordinator.document.hotKey(for: a), first)
            failWrite = false
            try coordinator.apply(saved.assigning(second, to: a))
            XCTAssertEqual(Array(backend.keys.values), [second])
            XCTAssertEqual(saved.hotKey(for: a), second)
        }
    }
    func testRepeatSuppressionStaleEventsAndRemovedUUID() async throws {
        try await MainActor.run {
            let backend = Backend()
            let coordinator = try HotKeyCoordinator(document: HotKeyDocument().assigning(first, to: a), knownIDs: [a], backend: backend) { _ in }
            coordinator.reconcile(); let token = try XCTUnwrap(backend.keys.keys.first)
            var invocations: [UUID] = []; coordinator.onInvoke = { invocations.append($0) }
            coordinator.receive(token: token, isDown: true); coordinator.receive(token: token, isDown: true)
            XCTAssertEqual(invocations, [a])
            coordinator.receive(token: token, isDown: false); coordinator.receive(token: token, isDown: true)
            XCTAssertEqual(invocations, [a, a])
            coordinator.knownIDs = []; coordinator.reconcile()
            coordinator.receive(token: token, isDown: false); coordinator.receive(token: token, isDown: true)
            XCTAssertEqual(invocations.count, 2); XCTAssertTrue(backend.keys.isEmpty)
        }
    }
    func testRecordingCancelResumeAndSaveKeepRegistrationsConsistent() async throws {
        try await MainActor.run {
            let backend = Backend(); var saved = HotKeyDocument().assigning(first, to: a)
            let coordinator = try HotKeyCoordinator(document: saved, knownIDs: [a], backend: backend) { saved = $0 }
            coordinator.reconcile(); let oldToken = try XCTUnwrap(backend.keys.keys.first)
            var invoked = false; coordinator.onInvoke = { _ in invoked = true }
            coordinator.suspend(); XCTAssertTrue(backend.keys.isEmpty)
            coordinator.receive(token: oldToken, isDown: true); XCTAssertFalse(invoked)
            coordinator.resume(); XCTAssertEqual(Array(backend.keys.values), [first])
            coordinator.suspend()
            try coordinator.apply(saved.assigning(second, to: a))
            XCTAssertTrue(backend.keys.isEmpty)
            coordinator.resume(); XCTAssertEqual(Array(backend.keys.values), [second])
            coordinator.receive(token: oldToken, isDown: true); XCTAssertFalse(invoked)
        }
    }
    func testPartialStartupFailureDoesNotDisableOtherKeysAndReconcileDoesNotChurn() async throws {
        try await MainActor.run {
            let backend = Backend(); backend.blocked.insert(second)
            let document = HotKeyDocument().assigning(first, to: a).assigning(second, to: b)
            let coordinator = try HotKeyCoordinator(document: document, knownIDs: [a,b], backend: backend) { _ in }
            coordinator.reconcile()
            XCTAssertTrue(coordinator.isActive(a)); XCTAssertNotNil(coordinator.failures[b])
            let count = backend.registrations
            coordinator.reconcile(); XCTAssertEqual(backend.registrations, count)
            backend.blocked.remove(second); coordinator.reconcile()
            XCTAssertTrue(coordinator.isActive(b)); XCTAssertTrue(coordinator.failures.isEmpty)
            var off = document; off.enabled = false
            try coordinator.apply(off); XCTAssertTrue(backend.keys.isEmpty)
            XCTAssertEqual(coordinator.document.assignments, document.assignments)
            try coordinator.apply(document); XCTAssertEqual(backend.keys.count, 2)
            coordinator.stop(); XCTAssertTrue(backend.keys.isEmpty)
        }
    }
    func testUnknownUUIDNeverRegistersAndRemovingAssignmentFreesKey() async throws {
        try await MainActor.run {
            let backend = Backend()
            let document = HotKeyDocument().assigning(first, to: a).assigning(second, to: b)
            let coordinator = try HotKeyCoordinator(document: document, knownIDs: [a], backend: backend) { _ in }
            coordinator.reconcile(); XCTAssertEqual(Array(backend.keys.values), [first])
            try coordinator.apply(document.assigning(nil, to: a))
            XCTAssertTrue(backend.keys.isEmpty)
        }
    }
}
