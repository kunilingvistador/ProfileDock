import AppKit
import Combine

enum ManagerCommand: Equatable {
    case create, editSelected, help, privacy
}

/// Owns only the manager's native window chrome. It is never constructed for a
/// background shortcut activation and does not install any keyboard monitor.
@MainActor
final class ManagerToolbarController: NSObject, NSToolbarDelegate, NSSearchFieldDelegate, NSMenuDelegate {
    private let model: AppModel
    private weak var window: NSWindow?
    private var observation: AnyCancellable?
    private var searchObservation: AnyCancellable?
    private var updateScheduled = false
    private var searchItem: NSSearchToolbarItem?
    private var statusItem: NSToolbarItem?
    private var addItem: NSToolbarItem?
    private var refreshItem: NSToolbarItem?
    private var moreMenu: NSMenu?

    private static let status = NSToolbarItem.Identifier("profiledock.status")
    private static let search = NSToolbarItem.Identifier("profiledock.search")
    private static let refresh = NSToolbarItem.Identifier("profiledock.refresh")
    private static let add = NSToolbarItem.Identifier("profiledock.add")
    private static let more = NSToolbarItem.Identifier("profiledock.more")

    init(model: AppModel) {
        self.model = model
        super.init()
        observation = model.objectWillChange.sink { [weak self] _ in
            guard let self, !self.updateScheduled else { return }
            self.updateScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.updateScheduled = false
                self?.update()
            }
        }
        // Clear the native field synchronously with a model-driven reset. If
        // another command immediately ends editing, its old query must not win.
        searchObservation = model.$searchText.removeDuplicates().sink { [weak self] query in
            guard let field = self?.searchItem?.searchField, field.stringValue != query else { return }
            field.stringValue = query
        }
    }

    func install(on window: NSWindow) {
        self.window = window
        model.didRequestSearchFocus = { [weak self] in
            guard let self else { return }
            self.focusSearch(in: self.window)
        }
        let toolbar = NSToolbar(identifier: "ProfileDock.Manager")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbarStyle = .unifiedCompact
        window.toolbar = toolbar
        window.tabbingMode = .disallowed
        update()
    }

    func focusSearch(in window: NSWindow?) {
        guard let field = searchItem?.searchField, let window, window.attachedSheet == nil else { return }
        model.searchFieldFocused = true
        window.makeFirstResponder(field)
        field.selectText(nil)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.status, .flexibleSpace, Self.search, Self.refresh, Self.add, Self.more]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if id == Self.search {
            let item = NSSearchToolbarItem(itemIdentifier: id)
            item.searchField.placeholderString = L("Find a shortcut", "Найти ярлык")
            item.searchField.setAccessibilityLabel(L("Find a shortcut by name", "Найти ярлык по имени"))
            item.searchField.delegate = self
            item.searchField.sendsSearchStringImmediately = true
            item.searchField.sendsWholeSearchString = false
            item.searchField.target = self
            item.searchField.action = #selector(searchChanged)
            item.searchField.stringValue = model.searchText
            item.label = L("Search", "Поиск")
            item.toolTip = L("Find a shortcut (⌘F)", "Найти ярлык (⌘F)")
            searchItem = item
            return item
        }
        if id == Self.more {
            let item = NSMenuToolbarItem(itemIdentifier: id)
            item.label = L("More", "Ещё")
            item.toolTip = L("Shortcut actions and help", "Действия с ярлыками и помощь")
            item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: item.label)
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.delegate = self
            var commands: [(String, Selector)] = [
                (L("Edit selected shortcut…", "Настроить выбранный ярлык…"), #selector(editSelected)),
                (L("Import existing shortcuts…", "Импортировать готовые ярлыки…"), #selector(importShortcuts)),
                (L("Update Dock shortcuts", "Обновить ярлыки Dock"), #selector(updateShortcuts)),
                (L("Create all Dock shortcuts", "Создать все ярлыки для Dock"), #selector(exportAll)),
                (L("Keyboard shortcuts enabled", "Сочетания клавиш включены"), #selector(toggleHotKeys)),
                (L("Retry hotkey registration", "Повторить регистрацию сочетаний"), #selector(retryHotKeys)),
                (L("How it works", "Как это работает"), #selector(showHelp)),
                (L("Data and permissions", "Данные и разрешения"), #selector(showPrivacy)),
                (L("Feedback and ideas…", "Отзывы и идеи…"), #selector(showFeedback))
            ]
            if model.showsSupportPrototype {
                commands.append((L("Support ProfileDock…", "Поддержать ProfileDock…"), #selector(showSupport)))
            }
            for (title, action) in commands {
                let command = NSMenuItem(title: title, action: action, keyEquivalent: "")
                command.target = self
                menu.addItem(command)
                if action == #selector(exportAll) || action == #selector(retryHotKeys) { menu.addItem(.separator()) }
            }
            moreMenu = menu
            item.menu = menu
            return item
        }
        let item = NSToolbarItem(itemIdentifier: id)
        item.target = self
        item.autovalidates = false
        switch id {
        case Self.status:
            item.label = L("Status", "Состояние")
            item.action = #selector(showStatus)
            statusItem = item
        case Self.refresh:
            item.label = L("Refresh", "Обновить")
            item.toolTip = L("Refresh windows (⌘R)", "Обновить список окон (⌘R)")
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: item.label)
            item.action = #selector(refresh)
            refreshItem = item
        case Self.add:
            item.label = L("Add shortcut", "Добавить ярлык")
            item.toolTip = L("Add a shortcut (⌘N)", "Добавить ярлык (⌘N)")
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: item.label)
            item.action = #selector(addShortcut)
            addItem = item
        default: return nil
        }
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) { update() }
    private func update() {
        let connected = model.chromeRunning && model.permissionGranted && model.hasWindowSnapshot
        statusItem?.image = NSImage(systemSymbolName: connected ? "checkmark.circle" : "exclamationmark.circle",
                                   accessibilityDescription: L("Check connection status", "Проверить состояние подключения"))
        statusItem?.toolTip = connected
            ? L("Chrome connected · check windows and hotkeys", "Chrome подключён · проверить окна и сочетания")
            : L("Check the Chrome connection", "Проверить подключение Chrome")
        addItem?.isEnabled = !model.isBusy
        refreshItem?.isEnabled = !model.isBusy && !model.demoMode
        if searchItem?.searchField.stringValue != model.searchText {
            searchItem?.searchField.stringValue = model.searchText
        }
        for item in moreMenu?.items ?? [] {
            switch item.action {
            case #selector(editSelected): item.isEnabled = model.selectedShortcutID != nil && !model.isBusy
            case #selector(importShortcuts), #selector(updateShortcuts):
                item.isEnabled = !model.demoMode && !model.isBusy && !model.isMaintainingLaunchers
            case #selector(exportAll): item.isEnabled = !model.shortcuts.isEmpty && !model.isBusy && !model.demoMode
            case #selector(toggleHotKeys):
                item.state = model.hotKeyDocument.enabled ? .on : .off
                item.isEnabled = model.hotKeyStorageError == nil
            default: break
            }
        }
    }
    func controlTextDidChange(_ notification: Notification) { searchChanged() }
    func controlTextDidBeginEditing(_ notification: Notification) { model.searchFieldFocused = true }
    func controlTextDidEndEditing(_ notification: Notification) { model.searchFieldFocused = false }
    @objc private func searchChanged() {
        if let field = searchItem?.searchField, field.stringValue != model.searchText {
            model.searchText = field.stringValue
        }
    }
    @objc private func addShortcut() { model.managerCommandRequest = .create }
    @objc private func editSelected() { model.managerCommandRequest = .editSelected }
    @objc private func showHelp() { model.managerCommandRequest = .help }
    @objc private func showPrivacy() { model.managerCommandRequest = .privacy }
    @objc private func showStatus() { model.projectSectionRequest = .status }
    @objc private func showFeedback() { model.projectSectionRequest = .feedback }
    @objc private func showSupport() { model.projectSectionRequest = model.demoMode ? .support : .status }
    @objc private func refresh() { Task { await model.refresh() } }
    @objc private func importShortcuts() { model.importExisting() }
    @objc private func updateShortcuts() { model.updateLaunchers() }
    @objc private func exportAll() { model.exportAll() }
    @objc private func toggleHotKeys() { model.setHotKeysEnabled(!model.hotKeyDocument.enabled) }
    @objc private func retryHotKeys() { model.refreshHotKeys() }
}
