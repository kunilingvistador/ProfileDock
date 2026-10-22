import AppKit
import Carbon
import SwiftUI
import ProfileDockCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var model: AppModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var previewPanel: NSPanel?
    private var pendingURLs: [URL] = []
    private var menuIsDirty = true
    private var statusRefreshItem: NSMenuItem?
    private var statusUpdateItem: NSMenuItem?
    private var managerRefreshTask: Task<Void, Never>?
    private var managerToolbar: ManagerToolbarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PerformanceTrace.record("controller.didFinishLaunching")
        model = AppModel()
        PerformanceTrace.record("controller.modelReady")
        model.didChange = { [weak self] in self?.menuIsDirty = true }
        model.didPreviewWindow = { [weak self] in self?.showPreviewReturn() }
        installMainMenu()
        model.didInvokeHotKey = { [weak self] id in
            guard let self, let shortcut = self.model.shortcuts.first(where: { $0.id == id }) else { return }
            Task { await self.model.switchTo(shortcut); if self.model.errorMessage != nil { self.showWindow() } }
        }
        model.startHotKeys()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(recoverHotKeys), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(pauseHotKeys), name: NSWorkspace.willSleepNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(layoutChanged),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "ProfileDock")
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        PerformanceTrace.record("controller.setupReady")
        if !CommandLine.arguments.contains("--background"), pendingURLs.isEmpty { showWindow() }
        let queued = pendingURLs; pendingURLs = []
        if !queued.isEmpty { application(NSApp, open: queued) }
    }

    private func ensureManagerWindow() {
        guard window == nil else { return }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = model.demoMode ? "ProfileDock Preview" : "ProfileDock"
        window.minSize = NSSize(width: 860, height: 600)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView(model: model))
        managerToolbar = ManagerToolbarController(model: model)
        managerToolbar?.install(on: window)
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
        PerformanceTrace.record("controller.uiReady")
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        PerformanceTrace.record("controller.received")
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
        guard let model else { return }
        ensureManagerWindow()
        if !model.demoMode {
            try? ControllerLocationRegistry(directory: model.store.directory).record(controllerURL: Bundle.main.bundleURL)
            // A background Dock click should spend its time focusing the window,
            // not signing other helpers. Maintenance runs when setup is opened.
            Task { model.synchronizeLaunchers() }
        }
        previewPanel?.orderOut(nil)
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        scheduleManagerRefresh()
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        previewPanel?.orderOut(nil)
        scheduleManagerRefresh()
    }
    func applicationDidResignActive(_ notification: Notification) {
        managerRefreshTask?.cancel()
        managerRefreshTask = nil
    }

    private func scheduleManagerRefresh() {
        managerRefreshTask?.cancel()
        managerRefreshTask = Task { [weak self] in
            // Showing and activating the manager may both request this refresh.
            // Coalesce them and do not poll a manager that is behind Chrome.
            await Task.yield()
            guard let self, !Task.isCancelled, NSApp.isActive,
                  self.window?.isVisible == true, self.window?.attachedSheet == nil else { return }
            await self.model.refreshForManager()
        }
    }

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
                .buttonStyle(.borderedProminent)
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
    @objc func recoverHotKeys() { model?.hotKeysDidWake() }
    @objc func pauseHotKeys() { model?.hotKeysWillSleep() }
    @objc func layoutChanged() { model?.hotKeyRevision += 1; menuIsDirty = true }
    func applicationWillTerminate(_ notification: Notification) { model?.stopHotKeys() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSupport() { showWindow(); model.projectSectionRequest = model.showsSupportPrototype ? .support : .status }
    @objc func showFeedback() { showWindow(); model.projectSectionRequest = .feedback }
    @objc func showStatus() { showWindow(); model.projectSectionRequest = .status }
    @objc func showData() { showWindow(); model.projectSectionRequest = .data }
    @objc func previewLight() { window?.appearance = NSAppearance(named: .aqua) }
    @objc func previewDark() { window?.appearance = NSAppearance(named: .darkAqua) }
    @objc func previewSystem() { window?.appearance = nil }
    @objc func previewCompact() { window?.setContentSize(NSSize(width: 860, height: 600)) }
    @objc func previewRegular() { window?.setContentSize(NSSize(width: 940, height: 600)) }
    @objc func previewEmpty() {
        guard model.demoMode else { return }
        model.shortcuts = []; model.notice = nil; model.selectedShortcutID = nil
    }
    @objc func previewTimeout() {
        guard model.demoMode else { return }
        model.errorMessage = ChromeError(code: -1712, detail: "Preview timeout").localizedDescription
    }
    @objc func previewDisconnected() {
        guard model.demoMode else { return }
        model.chromeRunning = false; model.hasWindowSnapshot = false; model.notice = nil
    }
    @objc func previewConnected() {
        guard model.demoMode else { return }
        model.chromeRunning = true; model.permissionGranted = true; model.hasWindowSnapshot = true
    }
    @objc func refresh() { Task { await model.refresh() } }
    @objc func addShortcut() { showWindow(); model.managerCommandRequest = .create }
    @objc func findShortcut() { showWindow(); managerToolbar?.focusSearch(in: window) }
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
        for (title, action) in [(L("Status and troubleshooting…", "Состояние и помощь…"), #selector(showStatus)),
                                (L("Feedback and ideas…", "Обратная связь и идеи…"), #selector(showFeedback)),
                                (L("Privacy…", "Приватность…"), #selector(showData))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self; appMenu.addItem(item)
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Hide ProfileDock", "Скрыть ProfileDock"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit ProfileDock", "Завершить ProfileDock"), action: #selector(self.quit), keyEquivalent: "q")
        quit.target = self; appMenu.addItem(quit)
        appItem.submenu = appMenu; bar.addItem(appItem)
        let fileItem = NSMenuItem(); let file = NSMenu(title: L("File", "Файл"))
        let add = NSMenuItem(title: L("New shortcut…", "Новый ярлык…"), action: #selector(addShortcut), keyEquivalent: "n")
        add.target = self; file.addItem(add)
        fileItem.submenu = file; bar.addItem(fileItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: L("Edit", "Правка"))
        for (title, action, key) in [(L("Undo", "Отменить"), "undo:", "z"), (L("Redo", "Повторить"), "redo:", "Z"),
                                      (L("Cut", "Вырезать"), "cut:", "x"), (L("Copy", "Скопировать"), "copy:", "c"),
                                      (L("Paste", "Вставить"), "paste:", "v"), (L("Select All", "Выбрать всё"), "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        edit.addItem(.separator())
        let find = NSMenuItem(title: L("Find shortcut…", "Найти ярлык…"), action: #selector(findShortcut), keyEquivalent: "f")
        find.target = self; edit.addItem(find)
        editItem.submenu = edit; bar.addItem(editItem)
        let viewItem = NSMenuItem(); let view = NSMenu(title: L("View", "Вид"))
        let refresh = NSMenuItem(title: L("Refresh windows", "Обновить окна"), action: #selector(self.refresh), keyEquivalent: "r")
        refresh.target = self; view.addItem(refresh)
        viewItem.submenu = view; bar.addItem(viewItem)
        // Local QA controls affect this preview window, never system appearance.
        if model.demoMode {
            let item = NSMenuItem(); let preview = NSMenu(title: L("Preview", "Предпросмотр"))
            for (title, action) in [(L("Light appearance", "Светлая тема"), #selector(previewLight)),
                                    (L("Dark appearance", "Тёмная тема"), #selector(previewDark)),
                                    (L("System appearance", "Как в системе"), #selector(previewSystem)),
                                    (L("Compact window", "Компактное окно"), #selector(previewCompact)),
                                    (L("Regular window", "Обычное окно"), #selector(previewRegular))] {
                let command = NSMenuItem(title: title, action: action, keyEquivalent: "")
                command.target = self; preview.addItem(command)
            }
            preview.addItem(.separator())
            for (title, action) in [(L("QA: No shortcuts", "Проверка: нет ярлыков"), #selector(previewEmpty)),
                                    (L("QA: Chrome unavailable", "Проверка: Chrome недоступен"), #selector(previewDisconnected)),
                                    (L("QA: Chrome available", "Проверка: Chrome доступен"), #selector(previewConnected)),
                                    (L("QA: Chrome timeout", "Проверка: Chrome не отвечает"), #selector(previewTimeout))] {
                let command = NSMenuItem(title: title, action: action, keyEquivalent: "")
                command.target = self; preview.addItem(command)
            }
            item.submenu = preview; bar.addItem(item)
        }
        NSApp.mainMenu = bar
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menuIsDirty {
            rebuildMenu(menu)
            menuIsDirty = false
        }
        statusRefreshItem?.isEnabled = !model.demoMode && !model.isBusy
        statusUpdateItem?.isEnabled = !model.demoMode && !model.isBusy && !model.isMaintainingLaunchers
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let show = NSMenuItem(title: L("Open ProfileDock…", "Открыть ProfileDock…"), action: #selector(showWindow), keyEquivalent: ",")
        show.target = self; menu.addItem(show); menu.addItem(.separator())
        for shortcut in model.shortcuts {
            let hotKeyLabel = model.hotKeyDocument.hotKey(for: shortcut.id) == nil ? "" : "  \(model.hotKeyDescription(for: shortcut))"
            let item = NSMenuItem(title: shortcut.name + hotKeyLabel, action: #selector(focusMenuItem(_:)), keyEquivalent: "")
            item.representedObject = shortcut.id; item.target = self
            let image = model.icon(for: shortcut)?.copy() as? NSImage; image?.size = NSSize(width: 20, height: 20)
            item.image = image; menu.addItem(item)
        }
        if !model.shortcuts.isEmpty { menu.addItem(.separator()) }
        let refresh = NSMenuItem(title: L("Refresh windows", "Обновить окна"), action: #selector(refresh), keyEquivalent: "r")
        refresh.target = self; menu.addItem(refresh)
        statusRefreshItem = refresh
        let update = NSMenuItem(title: L("Update shortcuts", "Обновить ярлыки"), action: #selector(updateLaunchers), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        statusUpdateItem = update
        menu.addItem(.separator())
        for (title, action) in [(L("Status and troubleshooting…", "Состояние и помощь…"), #selector(showStatus)),
                                (L("Feedback and ideas…", "Обратная связь и идеи…"), #selector(showFeedback)),
                                (L("Support ProfileDock…", "Поддержать ProfileDock…"), #selector(showSupport))] {
            if action == #selector(showSupport) && !model.showsSupportPrototype { continue }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit ProfileDock", "Завершить ProfileDock"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
    }
}

MainActor.assumeIsolated {
    PerformanceTrace.record("controller.start")
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { application.run() }
}
