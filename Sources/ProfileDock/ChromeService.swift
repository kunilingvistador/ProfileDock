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

/// In-process Apple events keep Automation permission attached to this controller.
/// Every script is created and executed on the same serial background queue.
final class ChromeService {
    static let bundleID = "com.google.Chrome"
    private let queue = DispatchQueue(label: "ProfileDock.ChromeAppleEvents", qos: .userInitiated)
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
        _ = try await execute("focusWindow", arguments: [name])
        guard let chrome = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first,
              chrome.activate(options: []) else {
            throw ChromeError(code: -600, detail: "Chrome is not running.")
        }
    }

    private func execute(_ handler: String, arguments: [String]) async throws -> NSAppleEventDescriptor {
        guard isRunning else { throw ChromeError(code: -600, detail: "Chrome is not running.") }
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: Self.source), script.compileAndReturnError(&error) else {
                    continuation.resume(throwing: Self.failure(error)); return
                }
                let event = NSAppleEventDescriptor(eventClass: 0x61736372, eventID: 0x70736272,
                                                   targetDescriptor: nil, returnID: -1, transactionID: 0)
                event.setParam(NSAppleEventDescriptor(string: handler.lowercased()), forKeyword: 0x736e616d)
                let parameters = NSAppleEventDescriptor.list()
                for (index, value) in arguments.enumerated() { parameters.insert(NSAppleEventDescriptor(string: value), at: index + 1) }
                event.setParam(parameters, forKeyword: 0x2d2d2d2d)
                let result = script.executeAppleEvent(event, error: &error)
                if let error { continuation.resume(throwing: Self.failure(error)) }
                else { continuation.resume(returning: result) }
            }
        }
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

    on focusWindow(targetName)
        if not (application id "com.google.Chrome" is running) then error "Chrome closed" number -600
        with timeout of 12 seconds
            tell application id "com.google.Chrome"
                set matchingWindows to {}
                repeat with candidateWindow in (every window whose given name is targetName)
                    if mode of candidateWindow is not "incognito" then set end of matchingWindows to contents of candidateWindow
                end repeat
                if (count of matchingWindows) is 0 then error "Window missing" number -27001
                if (count of matchingWindows) is not 1 then error "Duplicate name" number -27002
                set targetID to id of item 1 of matchingWindows
                if mode of window id targetID is "incognito" then error "Private window" number -27003
                set minimized of window id targetID to false
                set index of window id targetID to 1
            end tell
        end timeout
    end focusWindow
    """
}
