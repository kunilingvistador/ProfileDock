import AppKit
import Foundation
import ProfileDockCore

// An isolated model-level regression: no NSApplication, Apple events, real
// preferences, profile metadata, helper maintenance or global hotkeys.
private final class MemoryPreferences: UserDefaults, @unchecked Sendable {
    private var values: [String: Any] = [:]
    override func bool(forKey defaultName: String) -> Bool { values[defaultName] as? Bool ?? false }
    override func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
}

private final class FakeChrome: ChromeWindowControlling, @unchecked Sendable {
    var isRunning = true
    var snapshot: [BrowserWindow] = []
    var failure: Error?
    var reads = 0
    var focusedNames: [String] = []
    var duringRead: (@MainActor () -> Void)?
    func windows() async throws -> [BrowserWindow] {
        reads += 1
        await duringRead?()
        if let failure { throw failure }
        return snapshot
    }
    func rename(windowID: String, to name: String) async throws { fatalError("Unexpected rename") }
    @MainActor func focus(name: String) async throws { focusedNames.append(name) }
    @MainActor func preview(windowID: String) async throws { fatalError("Unexpected preview") }
}

@main
struct WindowRefreshSmoke {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ProfileDock-refresh-smoke-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = FakeChrome()
        let model = AppModel(service: service, dataDirectory: directory.appendingPathComponent("Settings"),
                             preferences: MemoryPreferences(), profileRoot: directory.appendingPathComponent("NoChromeProfiles"))
        let shortcut = Shortcut(name: "Example", windowName: "test-binding")
        model.shortcuts = [shortcut]
        service.snapshot = [BrowserWindow(id: "1", givenName: shortcut.windowName, title: "Example", minimized: false)]

        func check(_ condition: @autoclosure () -> Bool, _ reason: String) {
            precondition(condition(), reason)
        }
        await model.refresh(presentErrorGlobally: false)
        check(model.hasFreshWindowSnapshot && model.permissionGranted, "A successful read must establish a usable connection")
        let original = model.windows

        for code in [-1712, -609, -1] {
            service.failure = ChromeError(code: code, detail: "Test read failure")
            await model.refresh(presentErrorGlobally: false)
            check(model.windows == original && model.hasWindowSnapshot, "A failed read must keep the previous windows")
            check(!model.hasFreshWindowSnapshot && model.windowRefreshError != nil, "A failed read must never remain healthy")
            check(model.errorMessage == nil, "An inline status failure must not queue a duplicate global alert")
            check(model.status(for: shortcut) == .ready, "Stale metadata must not disable an otherwise usable shortcut")
            await model.switchTo(shortcut)
            check(service.focusedNames.last == shortcut.windowName, "Switching must still use the original binding")
            check(!model.hasFreshWindowSnapshot, "A single successful focus must not validate the complete list")

            service.failure = nil
            service.duringRead = {
                check(model.isRefreshingWindows && !model.hasFreshWindowSnapshot, "A pending retry must not claim the check succeeded")
                check(model.windowRefreshError != nil, "Keep the previous failure visible until the retry succeeds")
            }
            await model.refresh(presentErrorGlobally: false)
            service.duringRead = nil
            check(model.hasFreshWindowSnapshot && model.windowRefreshError == nil, "A successful retry must clear the stale/error state")
        }

        service.failure = ChromeError(code: -1743, detail: "Denied")
        await model.refresh(presentErrorGlobally: false)
        check(!model.permissionGranted && model.hasWindowSnapshot && !model.hasFreshWindowSnapshot, "Permission recovery is distinct from missing-window recovery")
        check(model.status(for: shortcut) == .disconnected && model.errorMessage == nil, "Denied access must disconnect, with the failure kept inline")
        service.failure = nil
        await model.refresh(presentErrorGlobally: false)
        check(model.permissionGranted && model.hasFreshWindowSnapshot, "A successful retry must recover after permission is restored")

        service.isRunning = false
        let reads = service.reads
        await model.refresh(presentErrorGlobally: false)
        check(service.reads == reads && !model.chromeRunning && !model.hasWindowSnapshot, "Closed Chrome must clear the unusable snapshot without sending a read")
        check(model.windowRefreshError != nil && model.errorMessage == nil, "Closed Chrome needs an inline recovery explanation")
        await model.refresh()
        check(model.errorMessage == nil && service.reads == reads, "Opening the manager with Chrome closed must not introduce a blocking global alert")
        service.isRunning = true
        service.snapshot = []
        await model.refresh(presentErrorGlobally: false)
        check(model.hasFreshWindowSnapshot && model.status(for: shortcut) == .missing, "A successful empty read must produce real missing-window recovery")

        service.failure = ChromeError(code: -1712, detail: "Timeout")
        await model.refresh()
        check(model.errorMessage != nil && model.windowRefreshError != nil, "Existing non-panel refresh callers must still receive their normal error")
        model.acknowledgeWindowRefreshError()
        check(model.errorMessage == nil && model.windowRefreshError != nil, "Showing the status error must consume a pending duplicate alert, not its inline explanation")
        model.errorMessage = "Unrelated storage error"
        model.acknowledgeWindowRefreshError()
        check(model.errorMessage == "Unrelated storage error", "Status recovery must preserve unrelated pending alerts")
        service.failure = CancellationError()
        let lastFailure = model.windowRefreshError
        await model.refresh(presentErrorGlobally: false)
        check(model.windowRefreshError == lastFailure && !model.isRefreshingWindows, "Cancellation must not erase an existing failure or leave a pending spinner")
        print("PASS: window refresh recovery (timeout, interrupted, generic, permission, closed Chrome, empty list, retry, switching, global/inline errors, cancellation)")
    }
}
