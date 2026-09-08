import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ProfileDockCore

@MainActor final class AppModel: ObservableObject {
    @Published var shortcuts: [Shortcut] = []
    @Published var profiles: [BrowserProfile] = []
    @Published var windows: [BrowserWindow] = []
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var selectedShortcutID: UUID?
    @Published var recoveryShortcutID: UUID?
    @Published var chromeRunning = false
    @Published var permissionGranted = false

    let service = ChromeService()
    let store: ShortcutStore
    let demoMode: Bool
    var didChange: (() -> Void)?
    var didPreviewWindow: (() -> Void)?
    private var writable = true
    private var focusRequest = UUID()

    init() {
        demoMode = CommandLine.arguments.contains("--demo")
        let base = demoMode
            ? FileManager.default.temporaryDirectory.appendingPathComponent("ProfileDock-Preview-\(ProcessInfo.processInfo.processIdentifier)")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ProfileDock")
        store = ShortcutStore(directory: base)
        if demoMode {
            shortcuts = ["Studio", "Personal", "Research"].map { Shortcut(name: $0, windowName: $0) }
            windows = shortcuts.prefix(2).enumerated().map { BrowserWindow(id: String($0.offset), givenName: $0.element.windowName, title: $0.element.name, minimized: false) }
            profiles = [.init(id: "Default", name: "Personal"), .init(id: "Profile 1", name: "Studio")]
            chromeRunning = true; permissionGranted = true
            notice = L("Interface preview — no browser windows will be changed.", "Предпросмотр интерфейса — окна браузера не изменяются.")
        } else {
            do { shortcuts = try store.load() }
            catch { writable = false; errorMessage = error.localizedDescription }
            chromeRunning = service.isRunning
            permissionGranted = UserDefaults.standard.bool(forKey: "ChromePermissionGranted")
            loadProfiles()
        }
        selectedShortcutID = shortcuts.first?.id
    }

    func status(for shortcut: Shortcut) -> ShortcutStatus {
        guard chromeRunning, permissionGranted else { return .disconnected }
        switch WindowMatcher.match(name: shortcut.windowName, in: windows) {
        case .found: return .ready
        case .missing: return .missing
        case .ambiguous: return .ambiguous
        }
    }

    func icon(for shortcut: Shortcut) -> NSImage? {
        if let name = shortcut.iconFile, name == shortcut.id.uuidString + ".png",
           let image = NSImage(contentsOf: store.iconsDirectory.appendingPathComponent(name)) { return image }
        return IconService.defaultIcon(name: shortcut.name, id: shortcut.id)
    }

    func connect() async { await refresh() }

    func linkableWindows(for shortcutID: UUID? = nil) -> [BrowserWindow] {
        windows.filter { window in
            !window.incognito && !shortcuts.contains { $0.id != shortcutID && $0.windowName == window.givenName }
        }
    }

    /// Preview is deliberately separate from binding: looking at a window never
    /// changes the shortcut or the window's persistent name.
    func previewWindow(_ window: BrowserWindow) async {
        guard !isBusy else { return }
        errorMessage = nil; isBusy = true
        defer { isBusy = false }
        guard !demoMode else {
            notice = L("Preview mode: browser windows are unchanged.", "Предпросмотр: окна браузера не изменены.")
            return
        }
        do {
            try await service.preview(windowID: window.id)
            didPreviewWindow?()
        } catch {
            if let failure = error as? ChromeError, failure.code == -27001 {
                windows.removeAll { $0.id == window.id }
            }
            handle(error)
        }
    }

    func refresh() async {
        guard !isBusy, !demoMode else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false; didChange?() }
        loadProfiles(); chromeRunning = service.isRunning
        guard chromeRunning else { windows = []; return }
        do {
            windows = try await service.windows()
            permissionGranted = true
            UserDefaults.standard.set(true, forKey: "ChromePermissionGranted")
        } catch { handle(error) }
    }

    func addShortcut(name: String, window: BrowserWindow, profile: BrowserProfile?) async -> Bool {
        guard !isBusy else { return false }
        errorMessage = nil; notice = nil; isBusy = true
        defer { isBusy = false }
        do {
            try ensureWritable()
            let clean = try validatedName(name)
            guard !window.incognito else { throw ChromeError(code: -27003, detail: "") }
            let shortcut = Shortcut(name: clean, windowName: "", profileDirectory: profile?.id)
            var new = shortcut
            new.windowName = WindowMatcher.bindingName(displayName: clean, id: new.id)
            if shortcuts.contains(where: { $0.windowName == window.givenName }) {
                throw ModelError.message(L("This window already has a shortcut. Edit the existing shortcut instead.", "Для этого окна уже есть ярлык. Измените существующий ярлык."))
            }
            if !demoMode { try await service.rename(windowID: window.id, to: new.windowName) }
            do { try commit(shortcuts + [new]) }
            catch {
                if !demoMode { try? await service.rename(windowID: window.id, to: window.givenName) }
                throw error
            }
            if let path = profile?.avatarPath, let image = NSImage(contentsOfFile: path) { try? saveIcon(image, for: new) }
            selectedShortcutID = new.id
            if !demoMode {
                permissionGranted = true; chromeRunning = true
                if let fresh = try? await service.windows() { windows = fresh }
            }
            notice = L("Shortcut added. You can now choose its image and create a Dock shortcut.", "Ярлык добавлен. Теперь можно выбрать картинку и создать значок для Dock.")
            didChange?(); return true
        } catch { handle(error); return false }
    }

    func updateShortcut(_ shortcut: Shortcut, name: String) async {
        errorMessage = nil; notice = nil
        do {
            let clean = try validatedName(name)
            var next = shortcuts
            guard let i = next.firstIndex(where: { $0.id == shortcut.id }) else { return }
            next[i].name = clean
            try commit(next)
            try updateExistingExport(next[i])
            notice = L("Name saved. Re-add the shortcut to Dock if macOS still shows its previous label.", "Название сохранено. Если Dock показывает старую подпись, добавьте ярлык в Dock заново.")
        } catch { handle(error) }
    }

    func switchTo(_ shortcut: Shortcut) async {
        errorMessage = nil; notice = nil; recoveryShortcutID = nil
        if demoMode { notice = L("Preview mode: browser windows are unchanged.", "Предпросмотр: окна браузера не изменены."); return }
        let request = UUID(); focusRequest = request
        defer { didChange?() }
        do {
            try await service.focus(name: shortcut.windowName)
            guard focusRequest == request else { return }
            permissionGranted = true; chromeRunning = true
            UserDefaults.standard.set(true, forKey: "ChromePermissionGranted")
            if let fresh = try? await service.windows(), focusRequest == request { windows = fresh }
        } catch {
            if focusRequest == request {
                if let failure = error as? ChromeError, failure.code == -27001 {
                    windows.removeAll { $0.givenName == shortcut.windowName }
                } else if let failure = error as? ChromeError, failure.code == -27002,
                          let fresh = try? await service.windows(), focusRequest == request {
                    windows = fresh
                }
                if focusRequest == request {
                    if let failure = error as? ChromeError, [-27001, -27002].contains(failure.code) {
                        recoveryShortcutID = shortcut.id
                        selectedShortcutID = shortcut.id
                    }
                    handle(error)
                }
            }
        }
    }

    func relink(_ shortcut: Shortcut, to window: BrowserWindow) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false; didChange?() }
        do {
            try ensureWritable()
            guard !window.incognito else { throw ChromeError(code: -27003, detail: "") }
            guard !shortcuts.contains(where: { $0.id != shortcut.id && $0.windowName == window.givenName }) else {
                throw ModelError.message(L("That window belongs to another shortcut.", "Это окно уже связано с другим ярлыком."))
            }
            // A fresh marker repairs duplicate-name cases without renaming any
            // other window. The shortcut identity and Dock route stay unchanged.
            let marker = WindowMatcher.bindingName(displayName: shortcut.name, id: UUID())
            if !demoMode { try await service.rename(windowID: window.id, to: marker) }
            var next = shortcuts
            guard let i = next.firstIndex(where: { $0.id == shortcut.id }) else { return }
            next[i].windowName = marker
            do { try commit(next) }
            catch {
                if !demoMode { try? await service.rename(windowID: window.id, to: window.givenName) }
                throw error
            }
            if !demoMode, let fresh = try? await service.windows() { windows = fresh }
            notice = L("Window reconnected. Your existing Dock shortcut uses the new link.", "Окно перепривязано. Существующий ярлык в Dock использует новую связь.")
        } catch { handle(error) }
    }

    func removeShortcut(_ shortcut: Shortcut) {
        errorMessage = nil
        do {
            try commit(shortcuts.filter { $0.id != shortcut.id })
            if selectedShortcutID == shortcut.id { selectedShortcutID = shortcuts.first?.id }
            notice = L("Removed from ProfileDock. You can drag its old icon out of Dock. The Chrome window is still open.", "Ярлык удалён из ProfileDock. Его старый значок можно убрать из Dock. Окно Chrome осталось открытым.")
        } catch { handle(error) }
    }

    func chooseImage(for shortcut: Shortcut) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.message = L("Choose a photo or logo for this shortcut.", "Выберите фотографию или логотип для ярлыка.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        errorMessage = nil; notice = nil
        do {
            guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 16_000_000,
                  let image = NSImage(contentsOf: url) else { throw IconError.invalidImage }
            try saveIcon(image, for: shortcut)
            notice = L("Image saved. Re-add the icon to Dock if macOS keeps showing the old one.", "Картинка сохранена. Если Dock показывает старую, добавьте значок заново.")
        } catch { handle(error) }
    }

    func fetchFavicon(for shortcut: Shortcut, website: String) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let data = try await FaviconService().fetch(website: website)
            guard let image = NSImage(data: data) else { throw IconError.invalidImage }
            try saveIcon(image, for: shortcut)
            notice = L("Site icon saved.", "Значок сайта сохранён.")
        } catch { handle(error) }
    }

    func exportShortcut(_ shortcut: Shortcut) {
        errorMessage = nil; notice = nil
        guard !demoMode else { notice = L("Create real shortcuts outside preview mode.", "Создание ярлыков доступно вне предпросмотра."); return }
        do {
            let url = try LauncherExporter.export(shortcut: shortcut, image: icon(for: shortcut)!, directory: store.launchersDirectory, controllerURL: Bundle.main.bundleURL)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            notice = L("Drag the selected app from Finder to the left side of Dock.", "Перетащите выделенный ярлык из Finder в левую часть Dock.")
        } catch { handle(error) }
    }

    func exportAll() {
        errorMessage = nil; notice = nil
        guard !shortcuts.isEmpty, !demoMode else { return }
        do {
            let urls = try shortcuts.map { try LauncherExporter.export(shortcut: $0, image: icon(for: $0)!, directory: store.launchersDirectory, controllerURL: Bundle.main.bundleURL) }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
            notice = L("Drag the selected apps to Dock. All of them use the same ProfileDock controller.", "Перетащите выделенные ярлыки в Dock. Все они используют одно приложение ProfileDock.")
        } catch { handle(error) }
    }

    func importExisting() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.message = L("Choose the folder containing your earlier Chrome window shortcuts.", "Выберите папку с созданными ранее ярлыками окон Chrome.")
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        errorMessage = nil; notice = nil
        do {
            try ensureWritable()
            let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            var count = 0
            for url in entries where url.pathExtension == "app" {
                guard let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
                      let identifier = info["CFBundleIdentifier"] as? String,
                      identifier.hasPrefix("local."), identifier.contains(".chrome-window-switcher."),
                      let name = (info["CFBundleDisplayName"] ?? info["CFBundleName"]) as? String else { continue }
                let scriptURL = url.appendingPathComponent("Contents/Resources/Scripts/main.scpt")
                var failure: NSDictionary?
                guard let source = NSAppleScript(contentsOf: scriptURL, error: &failure)?.source,
                      let target = LegacyShortcutImport.targetName(in: source),
                      !shortcuts.contains(where: { $0.windowName == target }) else { continue }
                let item = Shortcut(name: try validatedName(name), windowName: target)
                try commit(shortcuts + [item])
                try saveIcon(NSWorkspace.shared.icon(forFile: url.path), for: item)
                count += 1
            }
            selectedShortcutID = shortcuts.first?.id
            notice = count == 0
                ? L("No new compatible shortcuts found. You can add any existing Chrome window using +.", "Новых совместимых ярлыков не найдено. Любое открытое окно Chrome можно добавить кнопкой +.")
                : L("Imported \(count) shortcuts. The original shortcuts and Chrome windows are unchanged.", "Импортировано ярлыков: \(count). Исходные ярлыки и окна Chrome сохранены.")
            didChange?()
        } catch { handle(error) }
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }
    func revealDataFolder() {
        try? FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(store.directory)
    }

    private func loadProfiles() {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Google/Chrome")
        guard let data = try? Data(contentsOf: root.appendingPathComponent("Local State")) else { profiles = []; return }
        profiles = (try? ChromeProfileDiscovery.decode(localState: data, root: root)) ?? []
    }
    private func validatedName(_ raw: String) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { throw ModelError.message(L("Use a name between 1 and 100 characters.", "Введите название длиной от 1 до 100 символов.")) }
        return name
    }
    private func ensureWritable() throws { if !writable { throw StoreError.invalidData } }
    private func commit(_ items: [Shortcut]) throws {
        try ensureWritable(); try store.save(items); shortcuts = items; didChange?()
    }
    private func saveIcon(_ image: NSImage, for shortcut: Shortcut) throws {
        try ensureWritable()
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        try FileManager.default.createDirectory(at: store.iconsDirectory, withIntermediateDirectories: true)
        let name = shortcut.id.uuidString + ".png", url = store.iconsDirectory.appendingPathComponent(shortcut.id.uuidString + ".png")
        let previous = try? Data(contentsOf: url)
        let imageData = try IconService.png(image, size: 512)
        try imageData.write(to: url, options: .atomic)
        var next = shortcuts; next[index].iconFile = name
        do { try commit(next) }
        catch {
            if let previous { try? previous.write(to: url, options: .atomic) }
            else { try? FileManager.default.removeItem(at: url) }
            throw error
        }
        try updateExistingExport(next[index])
    }
    private func updateExistingExport(_ shortcut: Shortcut) throws {
        let candidates = (try? FileManager.default.contentsOfDirectory(at: store.launchersDirectory, includingPropertiesForKeys: nil)) ?? []
        if candidates.contains(where: { (NSDictionary(contentsOf: $0.appendingPathComponent("Contents/Info.plist"))?["ProfileDockShortcutID"] as? String) == shortcut.id.uuidString }) {
            _ = try LauncherExporter.export(shortcut: shortcut, image: icon(for: shortcut)!, directory: store.launchersDirectory, controllerURL: Bundle.main.bundleURL)
        }
    }
    private func handle(_ error: Error) {
        if let chrome = error as? ChromeError {
            if chrome.code == -1743 { permissionGranted = false; UserDefaults.standard.set(false, forKey: "ChromePermissionGranted") }
            if chrome.code == -600 { chromeRunning = false; windows = [] }
        }
        errorMessage = error.localizedDescription
    }
}

enum ModelError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
