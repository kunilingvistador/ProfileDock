import AppKit
import ProfileDockCore

struct ChromeError: LocalizedError {
    let code: Int
    let detail: String
    var errorDescription: String? {
        switch code {
        case -1743: return L("Allow ProfileDock to control Google Chrome in System Settings → Privacy & Security → Automation.", "Разрешите ProfileDock управлять Google Chrome: Системные настройки → Конфиденциальность и безопасность → Автоматизация.")
        case -600: return L("Open Chrome and your existing work window, then refresh.", "Откройте Chrome и своё рабочее окно, затем обновите список.")
        case -27001: return L("The linked window is not open. Restore it in Chrome or reconnect this shortcut to an existing window.", "Связанное окно не открыто. Восстановите его в Chrome или привяжите ярлык к существующему окну.")
        case -27002: return L("More than one window has this name. Reconnect the shortcut to one exact window.", "Несколько окон имеют одинаковое имя. Перепривяжите ярлык к одному нужному окну.")
        case -27003: return L("Private windows are not supported by persistent shortcuts.", "Постоянные ярлыки не поддерживают окна инкогнито.")
        default: return detail
        }
    }
}

/// Local diagnostic timings contain no window names, IDs, titles, or URLs.
/// A focus sample ends when macOS accepts activation, not when a frame is displayed.
struct ChromePerformanceSample: Sendable {
    enum Phase: String, Sendable { case appleEvent, focus }
    let operation: String
    let phase: Phase
    let totalMilliseconds: Double
    let succeeded: Bool
    let queueMilliseconds: Double?
    let compilationMilliseconds: Double?
    let appleEventMilliseconds: Double?
}

/// In-process Apple events keep Automation permission attached to this controller.
/// The compiled script and diagnostic buffer are accessed only on the serial queue.
/// The request gate independently synchronizes publications from the main actor.
final class ChromeService: @unchecked Sendable {
    static let bundleID = "com.google.Chrome"
    private let queue = DispatchQueue(label: "ProfileDock.ChromeAppleEvents", qos: .userInitiated)
    private let focusRequests = FocusRequestGate()
    private var compiledScript: NSAppleScript?
    private var samples: [ChromePerformanceSample] = []
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty }

    func windows() async throws -> [BrowserWindow] {
        let result = try await execute("listWindows", arguments: [])
        return (1...max(result.numberOfItems, 1)).compactMap { index in
            guard index <= result.numberOfItems, let row = result.atIndex(index), row.numberOfItems == 5,
                  let id = row.atIndex(1)?.stringValue, let name = row.atIndex(2)?.stringValue,
                  let title = row.atIndex(3)?.stringValue else { return nil }
            return BrowserWindow(id: id, givenName: name, title: title,
                                 minimized: row.atIndex(4)?.booleanValue ?? false,
                                 incognito: row.atIndex(5)?.stringValue == "incognito")
        }
    }

    func rename(windowID: String, to name: String) async throws {
        _ = try await execute("bindWindow", arguments: [windowID, name])
    }

    @MainActor func focus(name: String) async throws {
        try await focus(handler: "focusWindow", arguments: [name])
    }

    /// Show a selected existing window before the user binds a shortcut to it.
    /// Preview never renames a window or creates a window/tab.
    @MainActor func preview(windowID: String) async throws {
        try await focus(handler: "previewWindow", arguments: [windowID])
    }

    func performanceSamples(reset: Bool = false) async -> [ChromePerformanceSample] {
        await withCheckedContinuation { continuation in
            queue.async {
                let result = self.samples
                if reset { self.samples.removeAll(keepingCapacity: true) }
                continuation.resume(returning: result)
            }
        }
    }

    @MainActor private func focus(handler: String, arguments: [String]) async throws {
        let started = DispatchTime.now().uptimeNanoseconds
        let request = focusRequests.request()
        PerformanceTrace.record("focus.requested", at: started)
        do {
            try await executeWithoutResult(handler, arguments: arguments, focusRequest: request)
            // No suspension between this check and activation: a newer main-actor
            // request cannot be overtaken by an older activation.
            guard focusRequests.isCurrent(request) else { throw CancellationError() }
            guard let chrome = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first,
                  chrome.activate(options: []) else {
                throw ChromeError(code: -600, detail: "Chrome is not running.")
            }
            recordFocus(handler, started: started, succeeded: true)
            PerformanceTrace.record("focus.accepted")
        } catch {
            if error is CancellationError || !focusRequests.isCurrent(request) {
                PerformanceTrace.record("focus.superseded")
                throw CancellationError()
            }
            PerformanceTrace.record("focus.failed")
            recordFocus(handler, started: started, succeeded: false)
            throw error
        }
    }

    // Discard the non-Sendable Apple event descriptor before resuming MainActor.
    private func executeWithoutResult(_ handler: String, arguments: [String], focusRequest: UUID) async throws {
        _ = try await execute(handler, arguments: arguments, focusRequest: focusRequest)
    }

    private func execute(_ handler: String, arguments: [String], focusRequest: UUID? = nil) async throws -> NSAppleEventDescriptor {
        let requested = DispatchTime.now().uptimeNanoseconds
        guard isRunning else { throw ChromeError(code: -600, detail: "Chrome is not running.") }
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let began = DispatchTime.now().uptimeNanoseconds
                if let focusRequest, !self.focusRequests.isCurrent(focusRequest) {
                    continuation.resume(throwing: CancellationError()); return
                }
                var error: NSDictionary?
                var compilationMilliseconds = 0.0
                if self.compiledScript == nil {
                    let compilationBegan = DispatchTime.now().uptimeNanoseconds
                    guard let script = NSAppleScript(source: Self.source), script.compileAndReturnError(&error) else {
                        let finished = DispatchTime.now().uptimeNanoseconds
                        self.append(ChromePerformanceSample(operation: handler, phase: .appleEvent,
                            totalMilliseconds: Self.milliseconds(from: requested, to: finished), succeeded: false,
                            queueMilliseconds: Self.milliseconds(from: requested, to: began),
                            compilationMilliseconds: Self.milliseconds(from: compilationBegan, to: finished),
                            appleEventMilliseconds: nil))
                        continuation.resume(throwing: Self.failure(error)); return
                    }
                    self.compiledScript = script
                    compilationMilliseconds = Self.milliseconds(from: compilationBegan)
                }
                // Only this queue reads/writes the cached script, including after Chrome restarts.
                guard let script = self.compiledScript else { preconditionFailure("Compiled script missing") }
                let event = NSAppleEventDescriptor(eventClass: 0x61736372, eventID: 0x70736272,
                                                   targetDescriptor: nil, returnID: -1, transactionID: 0)
                event.setParam(NSAppleEventDescriptor(string: handler.lowercased()), forKeyword: 0x736e616d)
                let parameters = NSAppleEventDescriptor.list()
                for (index, value) in arguments.enumerated() { parameters.insert(NSAppleEventDescriptor(string: value), at: index + 1) }
                event.setParam(parameters, forKeyword: 0x2d2d2d2d)
                // Compilation can take long enough for another click to arrive.
                // Once execution starts, finish it serially; timeout is not cancellation.
                if let focusRequest, !self.focusRequests.isCurrent(focusRequest) {
                    continuation.resume(throwing: CancellationError()); return
                }
                let executionBegan = DispatchTime.now().uptimeNanoseconds
                let result = script.executeAppleEvent(event, error: &error)
                let finished = DispatchTime.now().uptimeNanoseconds
                self.append(ChromePerformanceSample(operation: handler, phase: .appleEvent,
                    totalMilliseconds: Self.milliseconds(from: requested, to: finished), succeeded: error == nil,
                    queueMilliseconds: Self.milliseconds(from: requested, to: began),
                    compilationMilliseconds: compilationMilliseconds,
                    appleEventMilliseconds: Self.milliseconds(from: executionBegan, to: finished)))
                if let error { continuation.resume(throwing: Self.failure(error)) }
                else { continuation.resume(returning: result) }
            }
        }
    }

    private func recordFocus(_ handler: String, started: UInt64, succeeded: Bool) {
        let sample = ChromePerformanceSample(operation: handler, phase: .focus,
            totalMilliseconds: Self.milliseconds(from: started), succeeded: succeeded,
            queueMilliseconds: nil, compilationMilliseconds: nil, appleEventMilliseconds: nil)
        queue.async { self.append(sample) }
    }

    /// Called only on the Apple event queue. The bounded buffer is never written to disk.
    private func append(_ sample: ChromePerformanceSample) {
        if sample.phase == .appleEvent {
            PerformanceTrace.record("appleEvent." + sample.operation, values: [
                "totalMs": sample.totalMilliseconds,
                "queueMs": sample.queueMilliseconds ?? 0,
                "compileMs": sample.compilationMilliseconds ?? 0,
                "executeMs": sample.appleEventMilliseconds ?? 0,
                "succeeded": sample.succeeded ? 1 : 0,
            ])
        }
        samples.append(sample)
        if samples.count > 100 { samples.removeFirst(samples.count - 100) }
    }

    private static func milliseconds(from start: UInt64, to end: UInt64 = DispatchTime.now().uptimeNanoseconds) -> Double {
        Double(end - start) / 1_000_000
    }

    private static func failure(_ error: NSDictionary?) -> ChromeError {
        ChromeError(code: error?["NSAppleScriptErrorNumber"] as? Int ?? -1,
                    detail: error?["NSAppleScriptErrorMessage"] as? String ?? "Chrome automation failed.")
    }

    // User-controlled names are typed handler arguments, never interpolated code.
    private static let source = """
    on listWindows()
        if not (application id "com.google.Chrome" is running) then error "Chrome closed" number -600
        set rows to {}
        with timeout of 12 seconds
            tell application id "com.google.Chrome"
                repeat with w in every window
                    set end of rows to {(id of w) as text, given name of w, name of w, minimized of w, mode of w}
                end repeat
            end tell
        end timeout
        return rows
    end listWindows

    on bindWindow(windowIDValue, newName)
        if not (application id "com.google.Chrome" is running) then error "Chrome closed" number -600
        with timeout of 12 seconds
            tell application id "com.google.Chrome"
                if not (exists window id windowIDValue) then error "Window missing" number -27001
                if mode of window id windowIDValue is "incognito" then error "Private window" number -27003
                set conflicts to every window whose given name is newName
                repeat with w in conflicts
                    if ((id of w) as text) is not windowIDValue then error "Duplicate name" number -27002
                end repeat
                set given name of window id windowIDValue to newName
            end tell
        end timeout
    end bindWindow

    on previewWindow(windowIDValue)
        if not (application id "com.google.Chrome" is running) then error "Chrome closed" number -600
        with timeout of 12 seconds
            tell application id "com.google.Chrome"
                if not (exists window id windowIDValue) then error "Window missing" number -27001
                if mode of window id windowIDValue is "incognito" then error "Private window" number -27003
                set minimized of window id windowIDValue to false
                set index of window id windowIDValue to 1
            end tell
        end timeout
    end previewWindow

    on focusWindow(targetName)
        if not (application id "com.google.Chrome" is running) then error "Chrome closed" number -600
        with timeout of 12 seconds
            tell application id "com.google.Chrome"
                try
                    set matchingIDs to get id of (every window whose given name is targetName and mode is not "incognito")
                on error errorMessage number errorNumber
                    -- Only the first read may fall back. Never retry timeouts,
                    -- permission failures, or commands that might have changed a window.
                    if errorNumber is not -1708 then error errorMessage number errorNumber
                    set matchingIDs to {}
                    repeat with candidateWindow in (every window whose given name is targetName)
                        if mode of candidateWindow is not "incognito" then set end of matchingIDs to id of candidateWindow
                    end repeat
                end try
                if (count of matchingIDs) is 0 then error "Window missing" number -27001
                if (count of matchingIDs) is not 1 then error "Duplicate name" number -27002
                set targetID to item 1 of matchingIDs
                -- Chromium does not permit changing a window's mode after creation.
                set minimized of window id targetID to false
                set index of window id targetID to 1
            end tell
        end timeout
    end focusWindow
    """
}
