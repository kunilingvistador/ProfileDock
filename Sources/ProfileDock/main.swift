import AppKit
import SwiftUI
import ProfileDockCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        model.didChange = { [weak self] in self?.rebuildMenu() }
        installMainMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 660), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ProfileDock"
        window.minSize = NSSize(width: 860, height: 600)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView(model: model))
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

    @objc func showWindow() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func refresh() { Task { await model.refresh() } }
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
