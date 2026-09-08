import AppKit
import Foundation
import ProfileDockCore

private func localize(_ english: String, _ russian: String) -> String {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true ? russian : english
}

@MainActor
private final class LauncherDelegate: NSObject, NSApplicationDelegate {
    private var opening = false

    func applicationDidFinishLaunching(_ notification: Notification) { focusWindow() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        focusWindow()
        return false
    }

    private func focusWindow() {
        guard !opening else { return }
        opening = true
        guard let rawID = Bundle.main.object(forInfoDictionaryKey: "ProfileDockShortcutID") as? String,
              rawID.count == 36, let id = UUID(uuidString: rawID),
              id.uuidString.caseInsensitiveCompare(rawID) == .orderedSame,
              let url = URL(string: "profiledock://focus/\(id.uuidString)") else {
            fail(localize("This shortcut is incomplete. Create it again in ProfileDock.", "Этот ярлык повреждён. Создайте его заново в ProfileDock."))
            return
        }

        guard let controller = resolveController() else {
            fail(localize("ProfileDock could not be found. Move ProfileDock to Applications and open it once, then try this shortcut again.", "Не удалось найти ProfileDock. Переместите его в «Программы» и один раз откройте, затем нажмите ярлык снова."))
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.arguments = ["--background"]
        PerformanceTrace.record("helper.request")
        NSWorkspace.shared.open([url], withApplicationAt: controller, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error {
                    self?.fail(localize("Could not open ProfileDock: \(error.localizedDescription)", "Не удалось открыть ProfileDock: \(error.localizedDescription)"))
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func resolveController() -> URL? {
        // controllerURL() already validates the bundle structure and rejects
        // symlinks. The common case needs no Launch Services/process lookup.
        if let preferred = ControllerLocationRegistry().controllerURL() { return preferred }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: ControllerResolver.bundleID)
            .filter { !$0.isTerminated }.compactMap(\.bundleURL)
        if let uniqueRunning = ControllerResolver.resolve(preferred: nil, running: running,
            registered: nil, fallback: nil, standardLocations: []) { return uniqueRunning }

        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ControllerResolver.bundleID)
        let fallback = (Bundle.main.object(forInfoDictionaryKey: "ProfileDockControllerPath") as? String)
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        return ControllerResolver.resolve(preferred: nil, running: [], registered: installed, fallback: fallback)
    }

    private func fail(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "ProfileDock"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: localize("OK", "Понятно"))
        alert.runModal()
        NSApp.terminate(nil)
    }
}

MainActor.assumeIsolated {
    PerformanceTrace.record("helper.start")
    let application = NSApplication.shared
    let launcherDelegate = LauncherDelegate()
    application.delegate = launcherDelegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(launcherDelegate) { application.run() }
}
