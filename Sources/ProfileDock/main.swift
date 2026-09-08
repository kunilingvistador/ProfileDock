import AppKit
import SwiftUI
import ProfileDockCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var previewPanel: NSPanel?
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        model.didChange = { [weak self] in self?.rebuildMenu() }
        model.didPreviewWindow = { [weak self] in self?.showPreviewReturn() }
        installMainMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ProfileDock"
        window.minSize = NSSize(width: 860, height: 600)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView(model: model))
        // Repeatable screenshot QA affects this sample window only, never system settings.
        if model.demoMode {
            if CommandLine.arguments.contains("--demo-dark") {
                window.appearance = NSAppearance(named: .darkAqua)
            }
            if CommandLine.arguments.contains("--demo-compact") {
                window.setFrame(NSRect(origin: window.frame.origin, size: window.minSize), display: false)
            }
        }
        window.center()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "ProfileDock")
        rebuildMenu()
        if !CommandLine.arguments.contains("--background"), pendingURLs.isEmpty { showWindow() }
        if model.permissionGranted, !model.demoMode { Task { await model.refresh() } }
        let queued = pendingURLs; pendingURLs = []
        if !queued.isEmpty { application(NSApp, open: queued) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard model != nil else { pendingURLs.append(contentsOf: urls); return }
        for url in urls {
            guard let route = ShortcutRoute.parse(url) else { continue }
            switch route {
            case .show: showWindow()
            case .focus(let id):
                guard let shortcut = model.shortcuts.first(where: { $0.id == id }) else {
                    model.errorMessage = L("This shortcut is no longer configured. Recreate it from ProfileDock.", "Этот ярлык больше не настроен. Создайте его заново в ProfileDock.")
                    showWindow(); continue
                }
                Task {
                    await model.switchTo(shortcut)
                    if model.errorMessage != nil { showWindow() }
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc func showWindow() {
        if let model, !model.demoMode {
            try? ControllerLocationRegistry(directory: model.store.directory).record(controllerURL: Bundle.main.bundleURL)
            // A background Dock click should spend its time focusing the window,
            // not signing other helpers. Maintenance runs when setup is opened.
            Task { model.synchronizeLaunchers() }
        }
        previewPanel?.orderOut(nil)
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationDidBecomeActive(_ notification: Notification) { previewPanel?.orderOut(nil) }

    private func showPreviewReturn() {
        guard window?.isVisible == true, window?.attachedSheet != nil else { return }
        let panel = previewPanel ?? NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 132),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: false)
        previewPanel = panel
        panel.title = L("Check this Chrome window", "Проверьте окно Chrome")
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: VStack(alignment: .leading, spacing: 14) {
            Text(L("Is this the window you want? The shortcut has not been changed yet.", "Это нужное окно? Связь ярлыка пока не изменена."))
                .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Button(L("Return to setup", "Вернуться к настройке")) { [weak self] in self?.showWindow() }
                .buttonStyle(.borderedProminent).tint(.indigo)
                .keyboardShortcut(.defaultAction)
        }.padding(18).frame(width: 330, height: 132, alignment: .leading))
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            let pointer = NSEvent.mouseLocation
            panel.setFrameOrigin(NSPoint(
                x: min(max(frame.minX + 20, pointer.x + 20), frame.maxX - 350),
                y: min(max(frame.minY + 20, pointer.y - 180), frame.maxY - 180)))
        }
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func refresh() { Task { await model.refresh() } }
    @objc func updateLaunchers() { model.updateLaunchers() }
    @objc func focusMenuItem(_ item: NSMenuItem) {
        guard let id = item.representedObject as? UUID, let shortcut = model.shortcuts.first(where: { $0.id == id }) else { return }
        Task { await model.switchTo(shortcut); if model.errorMessage != nil { showWindow() } }
    }

    private func installMainMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu(title: "ProfileDock")
        let open = NSMenuItem(title: L("Open ProfileDock…", "Открыть ProfileDock…"), action: #selector(showWindow), keyEquivalent: ",")
        open.target = self; appMenu.addItem(open); appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Hide ProfileDock", "Скрыть ProfileDock"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit ProfileDock", "Завершить ProfileDock"), action: #selector(self.quit), keyEquivalent: "q")
        quit.target = self; appMenu.addItem(quit)
        appItem.submenu = appMenu; bar.addItem(appItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: L("Edit", "Правка"))
        for (title, action, key) in [(L("Undo", "Отменить"), "undo:", "z"), (L("Redo", "Повторить"), "redo:", "Z"),
                                      (L("Cut", "Вырезать"), "cut:", "x"), (L("Copy", "Скопировать"), "copy:", "c"),
                                      (L("Paste", "Вставить"), "paste:", "v"), (L("Select All", "Выбрать всё"), "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = edit; bar.addItem(editItem)
        NSApp.mainMenu = bar
    }

    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        let show = NSMenuItem(title: L("Open ProfileDock…", "Открыть ProfileDock…"), action: #selector(showWindow), keyEquivalent: ",")
        show.target = self; menu.addItem(show); menu.addItem(.separator())
        for shortcut in model.shortcuts {
            let item = NSMenuItem(title: shortcut.name, action: #selector(focusMenuItem(_:)), keyEquivalent: "")
            item.representedObject = shortcut.id; item.target = self
            let image = model.icon(for: shortcut)?.copy() as? NSImage; image?.size = NSSize(width: 20, height: 20)
            item.image = image; menu.addItem(item)
        }
        if !model.shortcuts.isEmpty { menu.addItem(.separator()) }
        let refresh = NSMenuItem(title: L("Refresh windows", "Обновить окна"), action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self; menu.addItem(refresh)
        let update = NSMenuItem(title: L("Update shortcuts", "Обновить ярлыки"), action: #selector(updateLaunchers), keyEquivalent: "")
        update.target = self
        update.isEnabled = !model.demoMode && !model.isBusy && !model.isMaintainingLaunchers
        menu.addItem(update)
        let quit = NSMenuItem(title: L("Quit ProfileDock", "Завершить ProfileDock"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        statusItem.menu = menu
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { application.run() }
}
